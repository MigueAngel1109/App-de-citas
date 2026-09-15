import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import '../widgets/user_profile_modal.dart';
import 'chat_detail_page.dart';

class RequestDetailPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> initialData;

  const RequestDetailPage({
    super.key,
    required this.requestId,
    required this.initialData,
  });

  @override
  State<RequestDetailPage> createState() => _RequestDetailPageState();
}

class _RequestDetailPageState extends State<RequestDetailPage> {
  bool _isProcessing = false;

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

  Future<void> _updateStatus(String newStatus, Map<String, dynamic> currentData) async {
    setState(() => _isProcessing = true);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    try {
      final requesterId = currentData['requesterUserId'] ?? '';
      final requesterName = currentData['requesterName'] ?? 'Usuario';
      final requesterPhoto = currentData['requesterPhoto'] ?? '';
      final placeName = currentData['placeName'] ?? 'la reserva';
      final reservationId = currentData['reservationId'] ?? '';

      // Obtener foto y nombre del anfitrión
      String hostName = 'Anfitrión';
      String hostPhoto = '';
      try {
        final hostDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
        if (hostDoc.exists) {
          final hData = hostDoc.data();
          if (hData != null) {
            hostName = hData['name'] ?? 'Anfitrión';
            final pList = (hData['photoUrls'] as List?) ?? (hData['photos'] as List?);
            if (pList != null && pList.isNotEmpty) {
              hostPhoto = pList[0]?.toString() ?? '';
            }
          }
        }
      } catch (_) {}

      final now = Timestamp.now();
      final interactionEntry = {
        'type': newStatus == 'accepted' ? 'status_accepted' : 'status_rejected',
        'title': newStatus == 'accepted' ? '¡Solicitud Aceptada!' : 'Solicitud Denegada',
        'description': newStatus == 'accepted'
            ? 'Aceptaste la solicitud de $requesterName. ¡Hay Match para $placeName!'
            : 'Rechazaste la solicitud de $requesterName.',
        'timestamp': now,
      };

      // 1. Actualizar solicitud
      await FirebaseFirestore.instance.collection('reservation_requests').doc(widget.requestId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        'interactionHistory': FieldValue.arrayUnion([interactionEntry]),
      });

      // 2. Si se acepta, crear Match en Firestore
      if (newStatus == 'accepted') {
        final matchRef = FirebaseFirestore.instance.collection('matches').doc();
        await matchRef.set({
          'matchId': matchRef.id,
          'requestId': widget.requestId,
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
          'lastMessage': '¡Match confirmado para la reserva en $placeName! 🎉',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showMatchDialog(
            requesterName: requesterName,
            requesterPhoto: requesterPhoto,
            hostPhoto: hostPhoto,
            placeName: placeName,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Has denegado la solicitud de $requesterName.'),
              backgroundColor: Colors.black87,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al procesar solicitud: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showMatchDialog({
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
                // Icono / Título celebración
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 36),
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

                // Fotos de ambos perfiles entrelazadas
                SizedBox(
                  height: 90,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Foto Anfitrión (Izquierda)
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
                            backgroundImage: hostPhoto.isNotEmpty ? NetworkImage(hostPhoto) : null,
                            child: hostPhoto.isEmpty ? const Icon(Icons.person, size: 38, color: AppColors.textLight) : null,
                          ),
                        ),
                      ),
                      // Foto Solicitante (Derecha)
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
                            backgroundImage: requesterPhoto.isNotEmpty ? NetworkImage(requesterPhoto) : null,
                            child: requesterPhoto.isEmpty ? const Icon(Icons.person, size: 38, color: AppColors.textLight) : null,
                          ),
                        ),
                      ),
                      // Corazón central pequeño
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.pinkAccent,
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
                      Navigator.pop(dialogContext); // Cerrar diálogo
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailPage(
                            lugar: {
                              'nombre': placeName,
                              'hora': 'Confirmada',
                              'icono': '🍷',
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

                // Botón Seguir Viendo Reservas
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Volver a Solicitudes', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalle de Solicitud',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('reservation_requests').doc(widget.requestId).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() as Map<String, dynamic>
              : widget.initialData;

          final placeName = data['placeName'] ?? 'Restaurante';
          final planType = data['planType'] ?? 'Reserva';
          final paymentType = data['paymentType'] ?? '';
          final dateTimeStr = _formatDateTime(data['dateTime']);
          final requesterName = data['requesterName'] ?? 'Usuario';
          final requesterPhoto = data['requesterPhoto'] ?? '';
          final requesterId = data['requesterUserId'] ?? '';
          final message = data['message'] ?? '';
          final status = data['status'] ?? 'pending';

          final List<dynamic> rawHistory = data['interactionHistory'] as List<dynamic>? ?? [];

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Estado actual Badge
                    _buildStatusBanner(status),
                    const SizedBox(height: 16),

                    // Tarjeta de la Reserva
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(Icons.restaurant, color: AppColors.primary, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('LUGAR DE LA RESERVA', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textLight, letterSpacing: 0.8)),
                                    Text(
                                      placeName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Divider(height: 1, color: AppColors.divider),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              const Icon(Icons.calendar_month, size: 16, color: AppColors.textSecondary),
                              const SizedBox(width: 6),
                              Text(dateTimeStr, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.inputBackground,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.inputBorder),
                                ),
                                child: Text(
                                  paymentType.isNotEmpty ? '$planType • $paymentType' : planType,
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Tarjeta del Solicitante
                    const Text('Persona que solicitó unirse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 30,
                                backgroundColor: AppColors.inputBackground,
                                backgroundImage: requesterPhoto.isNotEmpty ? NetworkImage(requesterPhoto) : null,
                                child: requesterPhoto.isEmpty ? const Icon(Icons.person, size: 30, color: AppColors.textLight) : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      requesterName,
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text('Quiere acompañarte a esta reserva', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Mensaje si lo dejó
                          if (message.isNotEmpty) ...[
                            const SizedBox(height: 14),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.background,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.format_quote, color: AppColors.textLight, size: 18),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      message,
                                      style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 16),

                          // BOTÓN PARA VER PERFIL DEL SOLICITANTE
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (requesterId.isNotEmpty) {
                                  UserProfileModal.show(
                                    context,
                                    userId: requesterId,
                                    name: requesterName,
                                    photo: requesterPhoto,
                                  );
                                }
                              },
                              icon: const Icon(Icons.account_circle_outlined, color: AppColors.primary, size: 20),
                              label: Text(
                                'Ver Perfil Completo de $requesterName',
                                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.primary, width: 1.5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // HISTÓRICO DE INTERACCIONES (TIMELINE)
                    const Text('Histórico de Interacciones', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    _buildInteractionTimeline(rawHistory, data),
                  ],
                ),
              ),

              // Barra inferior fija con acciones si está 'pending'
              if (status == 'pending')
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: Row(
                        children: [
                          // Botón Denegar
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _isProcessing ? null : () => _updateStatus('rejected', data),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                ),
                                child: const Text('Denegar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          // Botón Aceptar Reserva
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : () => _updateStatus('accepted', data),
                                icon: _isProcessing
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle, color: Colors.white, size: 20),
                                label: const Text('Aceptar Reserva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (status == 'accepted')
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, -4)),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatDetailPage(
                                  lugar: {
                                    'nombre': placeName,
                                    'hora': 'Confirmada',
                                    'icono': '🍷',
                                  },
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.chat_bubble, color: Colors.white),
                          label: Text('Abrir Chat con $requesterName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusBanner(String status) {
    Color bg;
    Color fg;
    IconData icon;
    String text;

    switch (status) {
      case 'accepted':
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        icon = Icons.check_circle;
        text = '¡Reserva Aceptada! Tienes un Match activo 🎉';
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        icon = Icons.cancel;
        text = 'Solicitud denegada';
        break;
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.hourglass_top;
        text = 'Solicitud pendiente de tu respuesta';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionTimeline(List<dynamic> history, Map<String, dynamic> data) {
    // Si la lista de historial está vacía, construir timeline predeterminado con los datos
    final List<Map<String, dynamic>> items = [];

    if (history.isNotEmpty) {
      for (var item in history) {
        if (item is Map) {
          items.add(Map<String, dynamic>.from(item));
        }
      }
    } else {
      // Evento 1: Reserva publicada
      if (data['createdAt'] != null) {
        items.add({
          'type': 'created',
          'title': 'Reserva publicada',
          'description': 'Publicaste esta reserva en el mapa.',
          'timestamp': data['createdAt'],
        });
      }
      // Evento 2: Solicitud recibida
      items.add({
        'type': 'request_sent',
        'title': 'Solicitud enviada',
        'description': '${data['requesterName'] ?? 'El usuario'} envió una solicitud para unirse.',
        'timestamp': data['createdAt'] ?? Timestamp.now(),
      });
      // Evento 3: Estado
      if (data['status'] == 'accepted') {
        items.add({
          'type': 'status_accepted',
          'title': 'Solicitud aceptada',
          'description': 'Aceptaste la reserva. ¡Se generó el match!',
          'timestamp': data['updatedAt'] ?? Timestamp.now(),
        });
      } else if (data['status'] == 'rejected') {
        items.add({
          'type': 'status_rejected',
          'title': 'Solicitud denegada',
          'description': 'Denegaste la solicitud.',
          'timestamp': data['updatedAt'] ?? Timestamp.now(),
        });
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];
          final isLast = index == items.length - 1;
          final timeStr = _formatDateTime(item['timestamp']);

          IconData eventIcon = Icons.timeline;
          Color eventColor = AppColors.primary;
          if (item['type'] == 'created') {
            eventIcon = Icons.add_location_alt;
            eventColor = Colors.blue;
          } else if (item['type'] == 'request_sent') {
            eventIcon = Icons.send_rounded;
            eventColor = Colors.orange;
          } else if (item['type'] == 'status_accepted') {
            eventIcon = Icons.favorite;
            eventColor = Colors.green;
          } else if (item['type'] == 'status_rejected') {
            eventIcon = Icons.cancel;
            eventColor = Colors.red;
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Línea y nodo
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: eventColor.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(eventIcon, size: 16, color: eventColor),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 36,
                      color: AppColors.divider,
                    ),
                ],
              ),
              const SizedBox(width: 14),
              // Contenido
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item['title'] ?? 'Evento',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          if (timeStr.isNotEmpty)
                            Text(
                              timeStr,
                              style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item['description'] ?? '',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
