import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import '../utils/place_photo_service.dart';
import 'publish_reservation_page.dart';
import 'chat_detail_page.dart';
import '../widgets/user_profile_modal.dart';

class ReservasPage extends StatefulWidget {
  final Function(GeoPoint?)? onPublished;
  final bool isVisible;

  const ReservasPage({super.key, this.onPublished, this.isVisible = true});

  @override
  State<ReservasPage> createState() => _ReservasPageState();
}

class _ReservasPageState extends State<ReservasPage> {
  final Set<String> _expandedReservationIds = {};

  String _formatDateTime(dynamic dt) {
    if (dt == null) return '';
    DateTime date;
    if (dt is Timestamp) {
      date = dt.toDate();
    } else if (dt is DateTime) {
      date = dt;
    } else {
      return dt.toString();
    }

    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final day = date.day;
    final month = months[date.month - 1];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';

    return '$day $month • $hour:$minute $ampm';
  }

  String _formatFullDateTime(dynamic dt) {
    if (dt == null) return 'Fecha no especificada';
    DateTime date;
    if (dt is Timestamp) {
      date = dt.toDate();
    } else if (dt is DateTime) {
      date = dt;
    } else {
      return dt.toString();
    }

    final months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
    ];
    final day = date.day;
    final month = months[date.month - 1];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';

    return '$day de $month • $hour:$minute $ampm';
  }



  void _confirmDeleteReservation(String docId, String placeName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Eliminar reserva?'),
        content: Text('¿Estás seguro de que deseas eliminar la reserva en "$placeName"? Desaparecerá del mapa.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.black87),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await FirebaseFirestore.instance.collection('reservations').doc(docId).delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reserva eliminada')),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // =============================================================
  // ACCIONES SOBRE SOLICITUDES (ACEPTAR / RECHAZAR / REPROGRAMAR)
  // =============================================================
  Future<void> _acceptRequest({
    required String requestId,
    required Map<String, dynamic> requestData,
    required String reservationId,
    required String placeName,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final requesterId = requestData['requesterUserId']?.toString() ?? requestData['requesterId']?.toString() ?? '';
      final requesterName = requestData['requesterName'] ?? 'Usuario';
      final requesterPhoto = requestData['requesterPhoto'] ?? '';

      // Obtener datos del anfitrión
      String hostName = 'Anfitrión';
      String hostPhoto = '';
      try {
        final hostDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
        if (hostDoc.exists && hostDoc.data() != null) {
          final hData = hostDoc.data()!;
          hostName = hData['name'] ?? 'Anfitrión';
          final pList = (hData['photoUrls'] as List?) ?? (hData['photos'] as List?);
          if (pList != null && pList.isNotEmpty) {
            hostPhoto = pList[0]?.toString() ?? '';
          }
        }
      } catch (_) {}

      // Si era propuesta de reprogramación, actualizar la fecha y hora de la reserva
      final propDate = requestData['proposedDateTime'];
      if (propDate != null && reservationId.isNotEmpty) {
        try {
          await FirebaseFirestore.instance.collection('reservations').doc(reservationId).update({
            'dateTime': propDate,
          });
        } catch (e) {
          debugPrint('Error actualizando fecha en reserva: $e');
        }
      }

      // Actualizar estado de la solicitud a 'accepted'
      await FirebaseFirestore.instance.collection('reservation_requests').doc(requestId).update({
        'status': 'accepted',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Crear o registrar match en Firestore
      final matchRef = FirebaseFirestore.instance.collection('matches').doc();
      await matchRef.set({
        'matchId': matchRef.id,
        'requestId': requestId,
        'reservationId': reservationId,
        'placeName': placeName,
        'users': [currentUserId, requesterId],
        'userNames': {
          currentUserId: hostName,
          requesterId: requesterName,
        },
        'userPhotos': {
          currentUserId: hostPhoto,
          requesterId: requesterPhoto,
        },
        'status': 'matched',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': propDate != null
            ? '¡Reprogramación confirmada para $placeName! 🎉'
            : '¡Match confirmado para la reserva en $placeName! 🎉',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        _showMatchDialog(
          matchId: matchRef.id,
          requesterId: requesterId,
          requesterName: requesterName,
          requesterPhoto: requesterPhoto,
          hostPhoto: hostPhoto,
          placeName: placeName,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al aceptar la solicitud: $e'),
            backgroundColor: Colors.black87,
          ),
        );
      }
    }
  }

  Future<void> _rejectRequest({
    required String requestId,
    required String requesterName,
    bool isReschedule = false,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(isReschedule ? '¿Rechazar reprogramación?' : '¿Rechazar solicitud?'),
        content: Text(
          isReschedule
              ? '¿Deseas rechazar la propuesta de reprogramación de $requesterName?'
              : '¿Deseas rechazar la solicitud de $requesterName?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance.collection('reservation_requests').doc(requestId).update({
        'status': 'rejected',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isReschedule
                  ? 'Has rechazado la propuesta de reprogramación de $requesterName.'
                  : 'Has rechazado la solicitud de $requesterName.',
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al rechazar: $e'), backgroundColor: Colors.black87),
        );
      }
    }
  }

  // DIÁLOGO CON CALENDARIO PARA ENVIAR OTRA CONTRA-PROPUESTA
  Future<void> _showCounterProposalDialog({
    required String requestId,
    required Map<String, dynamic> requestData,
    required String reservationId,
    required String placeName,
  }) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final requesterName = requestData['requesterName'] ?? 'Usuario';

    // 1. Selector de fecha
    final initialDate = DateTime.now().add(const Duration(days: 1));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      helpText: 'NUEVA FECHA DE LA CITA',
      confirmText: 'CONTINUAR',
      cancelText: 'CANCELAR',
    );

    if (pickedDate == null || !mounted) return;

    // 2. Selector de hora
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 20, minute: 0),
      helpText: 'NUEVA HORA DE LA CITA',
      confirmText: 'DEFINIR HORA',
      cancelText: 'CANCELAR',
    );

    if (pickedTime == null || !mounted) return;

    final combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    final messageCtrl = TextEditingController();

    // 3. Confirmar con mensaje
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return Container(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_calendar_rounded, color: AppColors.textPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Enviar Contrapropuesta',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          Text(
                            'Para $requesterName en $placeName',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.access_time_rounded, color: AppColors.textPrimary, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Nueva fecha propuesta: ${_formatFullDateTime(combinedDateTime)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Mensaje o nota opcional:',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: messageCtrl,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Ej: Te queda bien este día a esta hora? Avísame...',
                    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.inputBackground,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                    label: const Text('Enviar Propuesta', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    onPressed: () async {
                      Navigator.pop(modalCtx);
                      try {
                        final newProposalTs = Timestamp.fromDate(combinedDateTime);
                        final note = messageCtrl.text.trim();
                        await FirebaseFirestore.instance.collection('reservation_requests').doc(requestId).update({
                          'proposedDateTime': newProposalTs,
                          'requestType': 'reschedule',
                          'counterProposedBy': currentUserId,
                          'status': 'pending',
                          if (note.isNotEmpty) 'message': note,
                          'updatedAt': FieldValue.serverTimestamp(),
                        });

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('¡Contrapropuesta enviada a $requesterName para el ${_formatFullDateTime(combinedDateTime)}! 🗓️'),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error enviando contrapropuesta: $e'), backgroundColor: Colors.black87),
                          );
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // DIÁLOGO DE CELEBRACIÓN DE MATCH
  void _showMatchDialog({
    required String matchId,
    required String requesterId,
    required String requesterName,
    required String requesterPhoto,
    required String hostPhoto,
    required String placeName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: AppColors.textPrimary, size: 36),
                ),
                const SizedBox(height: 12),
                const Text(
                  '¡ES UN MATCH! 🎉',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tú y $requesterName han conectado para salir a:',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  placeName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 24),

                // Fotos de ambos perfiles
                SizedBox(
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        left: 55,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: AppColors.surface,
                            backgroundImage: (hostPhoto.isNotEmpty && (hostPhoto.startsWith('http://') || hostPhoto.startsWith('https://')))
                                ? NetworkImage(hostPhoto)
                                : null,
                            child: hostPhoto.isEmpty ? const Icon(Icons.person, size: 38, color: AppColors.textLight) : null,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 55,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 38,
                            backgroundColor: AppColors.surface,
                            backgroundImage: (requesterPhoto.isNotEmpty && (requesterPhoto.startsWith('http://') || requesterPhoto.startsWith('https://')))
                                ? NetworkImage(requesterPhoto)
                                : null,
                            child: requesterPhoto.isEmpty ? const Icon(Icons.person, size: 38, color: AppColors.textLight) : null,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.favorite, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Botón Chatear Ahora
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailPage(
                            matchId: matchId,
                            otherUserId: requesterId,
                            otherUserName: requesterName,
                            otherUserPhoto: requesterPhoto,
                            lugar: {
                              'nombre': placeName,
                              'hora': 'Confirmada',
                              'icono': '🍷',
                              'usuario': requesterName,
                              'avatar': requesterPhoto,
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                    label: Text(
                      'Chatear con $requesterName',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      elevation: 0,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =============================================================
  // WIDGET: SECCIÓN DESPLEGABLE DE SOLICITUDES DE UNA RESERVA
  // =============================================================
  Widget _buildExpandedRequestsSection({
    required String reservationId,
    required Map<String, dynamic> reservationData,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservation_requests')
          .where('reservationId', isEqualTo: reservationId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          );
        }

        final reqDocs = snapshot.data?.docs ?? [];
        if (reqDocs.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: const BoxDecoration(
              color: Color(0xFFF9F9F9),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(Icons.inbox_outlined, size: 18, color: AppColors.textLight),
                SizedBox(width: 8),
                Text(
                  'No hay solicitudes aún para esta reserva',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          );
        }

        final sortedReqs = List<QueryDocumentSnapshot>.from(reqDocs);
        sortedReqs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTs = aData['createdAt'] as Timestamp?;
          final bTs = bData['createdAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(22)),
            border: Border(
              top: BorderSide(color: AppColors.divider.withOpacity(0.8)),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.people_alt, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'Personas interesadas (${sortedReqs.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: sortedReqs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, reqIdx) {
                  final reqDoc = sortedReqs[reqIdx];
                  final reqData = reqDoc.data() as Map<String, dynamic>;
                  return _buildRequestItem(
                    requestId: reqDoc.id,
                    requestData: reqData,
                    reservationId: reservationId,
                    reservationData: reservationData,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // =============================================================
  // WIDGET: ITEM DE SOLICITUD (NORMAL O REPROGRAMACIÓN)
  // =============================================================
  Widget _buildRequestItem({
    required String requestId,
    required Map<String, dynamic> requestData,
    required String reservationId,
    required Map<String, dynamic> reservationData,
  }) {
    final requesterId = requestData['requesterUserId']?.toString() ?? requestData['requesterId']?.toString() ?? '';
    final requesterName = requestData['requesterName'] ?? 'Usuario';
    final requesterPhoto = (requestData['requesterPhoto'] ?? '').toString();
    final message = (requestData['message'] ?? '').toString();
    final status = requestData['status'] ?? 'pending';
    final placeName = reservationData['placeName'] ?? requestData['placeName'] ?? 'la cita';

    // Determinar si es una propuesta de reprogramación
    final isReschedule = requestData['requestType'] == 'reschedule' || requestData['proposedDateTime'] != null;

    Color statusBadgeBg;
    Color statusBadgeFg;
    String statusBadgeLabel;
    switch (status) {
      case 'accepted':
        statusBadgeBg = Colors.black.withOpacity(0.08);
        statusBadgeFg = AppColors.textPrimary;
        statusBadgeLabel = isReschedule ? 'Reprogramada' : 'Aceptada';
        break;
      case 'rejected':
        statusBadgeBg = Colors.black.withOpacity(0.05);
        statusBadgeFg = AppColors.textLight;
        statusBadgeLabel = 'Rechazada';
        break;
      default:
        statusBadgeBg = Colors.black.withOpacity(0.08);
        statusBadgeFg = AppColors.textPrimary;
        statusBadgeLabel = isReschedule ? 'Reprogramación' : 'Pendiente';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.divider,
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FILA SUPERIOR: FOTO (CON TAP PARA VER PERFIL) + NOMBRE + ESTADO
          Row(
            children: [
              // FOTO CON TAP PARA VER PERFIL
              GestureDetector(
                onTap: () {
                  if (requesterId.isNotEmpty) {
                    UserProfileModal.show(
                      context,
                      userId: requesterId,
                      name: requesterName,
                      photo: requesterPhoto,
                    );
                  }
                },
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.inputBackground,
                      backgroundImage: (requesterPhoto.isNotEmpty &&
                              (requesterPhoto.startsWith('http://') || requesterPhoto.startsWith('https://')))
                          ? NetworkImage(requesterPhoto)
                          : null,
                      child: requesterPhoto.isEmpty ? const Icon(Icons.person, color: AppColors.textLight, size: 24) : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(Icons.visibility, size: 9, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // NOMBRE Y TEXTO "Ver perfil"
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      requesterName,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    GestureDetector(
                      onTap: () {
                        if (requesterId.isNotEmpty) {
                          UserProfileModal.show(
                            context,
                            userId: requesterId,
                            name: requesterName,
                            photo: requesterPhoto,
                          );
                        }
                      },
                      child: const Text(
                        'Ver perfil completo',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),

              // BADGE DE ESTADO
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBadgeBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusBadgeLabel,
                  style: TextStyle(
                    color: statusBadgeFg,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          // SI ES REPROGRAMACIÓN: MOSTRAR BANNER EN TONOS NEUTROS Y GRISES
          if (isReschedule && requestData['proposedDateTime'] != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.edit_calendar_rounded, size: 18, color: AppColors.textPrimary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PROPUESTA DE REPROGRAMACIÓN',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFullDateTime(requestData['proposedDateTime']),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // MENSAJE DEL USUARIO
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '"$message"',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // BOTONES DE ACCIÓN EN TONOS NEUTROS (NEGROS, GRISES Y BLANCOS)
          if (status == 'pending') ...[
            if (isReschedule)
              // 3 BOTONES DE REPROGRAMACIÓN: CHULO (ACEPTAR), CALENDARIO (OTRA PROPUESTA), X (RECHAZAR)
              Row(
                children: [
                  // 1. CHULO: ACEPTAR PROPUESTA
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text(
                        'Aceptar',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _acceptRequest(
                        requestId: requestId,
                        requestData: requestData,
                        reservationId: reservationId,
                        placeName: placeName,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 2. CALENDARIO: OTRA PROPUESTA DE REPROGRAMACIÓN
                  Expanded(
                    flex: 4,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF333333),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                      label: const Text(
                        'Proponer',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showCounterProposalDialog(
                        requestId: requestId,
                        requestData: requestData,
                        reservationId: reservationId,
                        placeName: placeName,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // 3. X: RECHAZAR SOLICITUD DE REPROGRAMACIÓN
                  Material(
                    color: Colors.black.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _rejectRequest(
                        requestId: requestId,
                        requesterName: requesterName,
                        isReschedule: true,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.close_rounded, size: 18, color: AppColors.textPrimary),
                            SizedBox(width: 4),
                            Text(
                              'Rechazar',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              // BOTONES PARA SOLICITUD NORMAL: ACEPTAR O RECHAZAR
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Aceptar Cita', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _acceptRequest(
                        requestId: requestId,
                        requestData: requestData,
                        reservationId: reservationId,
                        placeName: placeName,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.divider, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      onPressed: () => _rejectRequest(
                        requestId: requestId,
                        requesterName: requesterName,
                        isReschedule: false,
                      ),
                    ),
                  ),
                ],
              ),
          ] else if (status == 'accepted') ...[
            // YA ACEPTADA: BOTÓN PARA ABRIR CHAT DIRECTO
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text(
                  'Chatear con $requesterName',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(
                        otherUserId: requesterId,
                        otherUserName: requesterName,
                        otherUserPhoto: requesterPhoto,
                        lugar: {
                          'nombre': placeName,
                          'hora': 'Confirmada',
                          'icono': '🍷',
                          'usuario': requesterName,
                          'avatar': requesterPhoto,
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =============================================================
  // VISTA PRINCIPAL: MIS RESERVAS CON FOTO Y EXPANDIBLE
  // =============================================================
  Widget _buildMyReservationsTab(String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: const Icon(Icons.restaurant_menu, size: 48, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Aún no has publicado ninguna reserva',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Publica un plan a tu restaurante o bar favorito para que aparezca en el mapa.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          );
        }

        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDt = aData['dateTime'] as Timestamp?;
          final bDt = bData['dateTime'] as Timestamp?;
          if (aDt == null && bDt == null) return 0;
          if (aDt == null) return 1;
          if (bDt == null) return -1;
          return bDt.compareTo(aDt);
        });

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('reservation_requests')
              .where('hostUserId', isEqualTo: currentUserId)
              .snapshots(),
          builder: (context, requestsSnapshot) {
            final Map<String, int> requestCountByResId = {};
            if (requestsSnapshot.hasData) {
              for (var rDoc in requestsSnapshot.data!.docs) {
                final rData = rDoc.data() as Map<String, dynamic>;
                final resId = rData['reservationId']?.toString();
                if (resId != null && resId.isNotEmpty) {
                  requestCountByResId[resId] = (requestCountByResId[resId] ?? 0) + 1;
                }
              }
            }

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              itemCount: sortedDocs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final doc = sortedDocs[index];
                final data = doc.data() as Map<String, dynamic>;

                final placeName = data['placeName'] ?? 'Restaurante';
                final planType = data['planType'] ?? 'Comida';
                final paymentType = data['paymentType'] ?? '';
                final dateTimeStr = _formatDateTime(data['dateTime']);
                final details = data['details'] ?? '';
                final verified = PlacePhotoService.getVerifiedOrCachedPhoto(placeName);
                final photoUrl = (verified != null && verified.isNotEmpty)
                    ? verified
                    : ((data['placePhoto'] ?? data['restaurantPhoto'] ?? '').toString());
                final count = requestCountByResId[doc.id] ?? 0;
                final isExpanded = _expandedReservationIds.contains(doc.id);

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // PARTE SUPERIOR: FOTO Y DETALLES DE LA RESERVA
                      Container(
                        height: 195,
                        decoration: BoxDecoration(
                          borderRadius: isExpanded
                              ? const BorderRadius.vertical(top: Radius.circular(22))
                              : BorderRadius.circular(22),
                        ),
                        child: ClipRRect(
                          borderRadius: isExpanded
                              ? const BorderRadius.vertical(top: Radius.circular(22))
                              : BorderRadius.circular(22),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              // Foto del lugar o fondo estilizado con degradado
                              if (photoUrl.isNotEmpty && (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')))
                                Image.network(
                                  photoUrl,
                                  fit: BoxFit.cover,
                                  cacheWidth: 600,
                                  errorBuilder: (_, __, ___) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [Color(0xFF262C36), Color(0xFF151922)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Color(0xFF262C36),
                                        Color(0xFF151922),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(Icons.restaurant, size: 70, color: Colors.white.withOpacity(0.15)),
                                  ),
                                ),

                              // Filtro oscuro semitransparente
                              Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.black.withOpacity(0.35),
                                      Colors.black.withOpacity(0.85),
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),

                              // Contenido superpuesto
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                placeName,
                                                style: const TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  shadows: [Shadow(color: Colors.black54, blurRadius: 4)],
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  const Icon(Icons.calendar_month, size: 14, color: Colors.white70),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    dateTimeStr,
                                                    style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                              // Alerta temática exactamente 24h antes del horario de la cita
                                              if (data['dateTime'] != null && data['dateTime'] is Timestamp) ...[
                                                Builder(
                                                  builder: (context) {
                                                    final resDateTime = (data['dateTime'] as Timestamp).toDate();
                                                    final diff = resDateTime.difference(DateTime.now());
                                                    final isUpcoming24h = diff.inHours >= 0 && diff.inHours < 24 && !diff.isNegative;
                                                    final isExpired = diff.isNegative;

                                                    if (isUpcoming24h) {
                                                      return Container(
                                                        margin: const EdgeInsets.only(top: 6),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                                        decoration: BoxDecoration(
                                                          color: const Color(0xFFE1306C).withOpacity(0.92),
                                                          borderRadius: BorderRadius.circular(8),
                                                          boxShadow: const [
                                                            BoxShadow(color: Colors.black26, blurRadius: 4),
                                                          ],
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.alarm_on_rounded, size: 13, color: Colors.white),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              'Cita en ${diff.inHours}h ${diff.inMinutes % 60}m (Menos de 24h)',
                                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    } else if (isExpired) {
                                                      return Container(
                                                        margin: const EdgeInsets.only(top: 6),
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withOpacity(0.6),
                                                          borderRadius: BorderRadius.circular(8),
                                                        ),
                                                        child: const Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.history_toggle_off_rounded, size: 13, color: Colors.white70),
                                                            SizedBox(width: 4),
                                                            Text(
                                                              'Reserva finalizada',
                                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                    }
                                                    return const SizedBox.shrink();
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Acción: Únicamente Eliminar
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 20, color: Colors.white70),
                                          tooltip: 'Eliminar',
                                          onPressed: () => _confirmDeleteReservation(doc.id, placeName),
                                        ),
                                      ],
                                    ),
                                    const Spacer(),
                                    if (details.isNotEmpty) ...[
                                      Text(
                                        details,
                                        style: const TextStyle(fontSize: 13, color: Colors.white, fontStyle: FontStyle.italic),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                    ],
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: Colors.white.withOpacity(0.15)),
                                          ),
                                          child: Text(
                                            paymentType.isNotEmpty ? '$planType • $paymentType' : planType,
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        // BOTÓN DE SOLICITUDES TRANSLÚCIDO Y ELEGANTE
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                if (isExpanded) {
                                                  _expandedReservationIds.remove(doc.id);
                                                } else {
                                                  _expandedReservationIds.add(doc.id);
                                                }
                                              });
                                            },
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(0.55),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.white.withOpacity(0.25),
                                                  width: 1.2,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.people_alt_rounded,
                                                    size: 16,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    '$count ${count == 1 ? 'solicitud' : 'solicitudes'}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 6),
                                                  AnimatedRotation(
                                                    turns: isExpanded ? 0.5 : 0.0,
                                                    duration: const Duration(milliseconds: 200),
                                                    child: const Icon(
                                                      Icons.keyboard_arrow_down_rounded,
                                                      size: 20,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // SECCIÓN DESPLEGABLE DE SOLICITUDES CON TRANSICIÓN SUAVE
                      AnimatedCrossFade(
                        duration: const Duration(milliseconds: 250),
                        crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                        firstChild: const SizedBox(width: double.infinity, height: 0),
                        secondChild: _buildExpandedRequestsSection(
                          reservationId: doc.id,
                          reservationData: data,
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para gestionar tus reservas')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mis Reservas',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
          ),
        ),
      ),
      body: _buildMyReservationsTab(currentUser.uid),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: !widget.isVisible
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 78.0),
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                elevation: 6,
                icon: const Icon(Icons.add_circle, color: Colors.white),
                label: const Text('Publicar Reserva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PublishReservationPage(
                        onPublished: (loc) {
                          widget.onPublished?.call(loc);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('¡Reserva publicada con éxito! Ya puedes verla en Mis Reservas y en el mapa 🎉'),
                              backgroundColor: AppColors.primary,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}
