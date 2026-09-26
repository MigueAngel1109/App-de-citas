import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
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
  Map<String, dynamic>? _parentReservationData;

  @override
  void initState() {
    super.initState();
    _fetchParentReservation();
  }

  Future<void> _fetchParentReservation() async {
    final resId = widget.initialData['reservationId']?.toString();
    if (resId != null && resId.isNotEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('reservations').doc(resId).get();
        if (doc.exists && doc.data() != null && mounted) {
          setState(() {
            _parentReservationData = doc.data();
          });
          return;
        }
      } catch (e) {
        debugPrint('Error obteniendo reserva madre: $e');
      }
    }
  }

  String _formatFullDate(dynamic dt) {
    if (dt == null) return 'Fecha no especificada';
    DateTime date;
    if (dt is Timestamp) {
      date = dt.toDate();
    } else if (dt is DateTime) {
      date = dt;
    } else {
      return dt.toString();
    }

    final days = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    final dayName = days[date.weekday - 1];
    final dayNum = date.day;
    final monthName = months[date.month - 1];
    final year = date.year;

    return '$dayName, $dayNum de $monthName de $year';
  }

  String _formatTime(dynamic dt) {
    if (dt == null) return '';
    DateTime date;
    if (dt is Timestamp) {
      date = dt.toDate();
    } else if (dt is DateTime) {
      date = dt;
    } else {
      return dt.toString();
    }

    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final ampm = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $ampm';
  }

  Future<void> _openInMaps(String placeName, dynamic location) async {
    Uri url;
    if (location is GeoPoint) {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}');
    } else {
      url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(placeName)}');
    }
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el mapa')),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _openExternalLink(String linkUrl) async {
    if (linkUrl.isEmpty) return;
    String formattedUrl = linkUrl;
    if (!formattedUrl.startsWith('http://') && !formattedUrl.startsWith('https://')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final uri = Uri.tryParse(formattedUrl);
    if (uri != null) {
      try {
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo abrir el enlace')),
            );
          }
        }
      } catch (_) {}
    }
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

      // Actualizar estado de la solicitud
      await FirebaseFirestore.instance.collection('reservation_requests').doc(widget.requestId).update({
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Si se acepta la solicitud, crear Match en Firestore
      if (newStatus == 'accepted') {
        // Si era propuesta de reprogramación, actualizar la fecha y hora de la reserva original
        final propDate = currentData['proposedDateTime'];
        if (propDate != null && reservationId.isNotEmpty) {
          try {
            await FirebaseFirestore.instance.collection('reservations').doc(reservationId).update({
              'dateTime': propDate,
            });
          } catch (_) {}
        }

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
            matchId: matchRef.id,
            requesterId: requesterId,
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
                  child: const Text('Volver a Solicitudes', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteRequest(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar solicitud?'),
        content: const Text('¿Estás seguro de que deseas eliminar esta solicitud? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              try {
                await FirebaseFirestore.instance.collection('reservation_requests').doc(widget.requestId).delete();
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Solicitud eliminada correctamente'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  IconData _getPlanIcon(String plan) {
    switch (plan.toLowerCase()) {
      case 'comida':
      case 'cena':
      case 'almuerzo':
        return Icons.restaurant;
      case 'café':
      case 'cafe':
        return Icons.coffee_rounded;
      case 'tragos':
      case 'bar':
      case 'copas':
        return Icons.wine_bar_rounded;
      case 'cine':
      case 'película':
        return Icons.movie_rounded;
      case 'paseo':
      case 'caminar':
        return Icons.park_rounded;
      default:
        return Icons.local_activity_rounded;
    }
  }

  IconData _getPaymentIcon(String payment) {
    if (payment.contains('Yo invito')) return Icons.card_giftcard_rounded;
    if (payment.contains('50')) return Icons.pie_chart_outline_rounded;
    return Icons.credit_card_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detalles de la Reserva',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            tooltip: 'Eliminar solicitud',
            onPressed: () => _confirmDeleteRequest(context),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('reservation_requests').doc(widget.requestId).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.hasData && snapshot.data!.exists
              ? snapshot.data!.data() as Map<String, dynamic>
              : widget.initialData;

          final parent = _parentReservationData ?? {};

          final placeName = (parent['placeName']?.toString().isNotEmpty == true)
              ? parent['placeName']
              : (data['placeName'] ?? 'Restaurante');
          final planType = (parent['planType']?.toString().isNotEmpty == true)
              ? parent['planType']
              : (data['planType'] ?? 'Comida');
          final paymentType = (parent['paymentType']?.toString().isNotEmpty == true)
              ? parent['paymentType']
              : (data['paymentType'] ?? 'Yo invito');
          final dateTimeVal = parent['dateTime'] ?? data['dateTime'];
          final detailsText = parent['details']?.toString() ?? data['details']?.toString() ?? '';
          final linkUrl = parent['link']?.toString() ?? data['link']?.toString() ?? '';
          final locationVal = parent['location'] ?? data['location'];

          final requesterName = data['requesterName'] ?? 'Usuario';
          final requesterPhoto = data['requesterPhoto'] ?? '';
          final requesterId = data['requesterUserId'] ?? '';
          final message = data['message'] ?? '';
          final status = data['status'] ?? 'pending';

          final fullDateStr = _formatFullDate(dateTimeVal);
          final timeStr = _formatTime(dateTimeVal);

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner de estado actual
                    _buildStatusBanner(status),
                    const SizedBox(height: 16),

                    // 1. TARJETA PRINCIPAL DEL LUGAR / RESTAURANTE
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppColors.primary, Color(0xFFFF758C)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'LUGAR O RESTAURANTE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.textLight,
                                        letterSpacing: 0.8,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      placeName,
                                      style: const TextStyle(
                                        fontSize: 21,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          const Divider(height: 1, color: AppColors.divider),
                          const SizedBox(height: 16),

                          // Botones de acción rápida: Ver en Mapa y Ver Menú
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () => _openInMaps(placeName, locationVal),
                                  icon: const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
                                  label: const Text(
                                    'Ver en Maps',
                                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                  ),
                                ),
                              ),
                              if (linkUrl.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _openExternalLink(linkUrl),
                                    icon: const Icon(Icons.link, size: 18, color: Colors.white),
                                    label: const Text(
                                      'Menú / Web',
                                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.primary,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 2. SECCIÓN: FECHA Y HORA DE LA CITA
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.calendar_month_rounded, color: AppColors.primary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Fecha y Hora Programada',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        fullDateStr,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      if (timeStr.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            const Icon(Icons.access_time_rounded, size: 14, color: AppColors.primary),
                                            const SizedBox(width: 5),
                                            Text(
                                              timeStr,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (data['proposedDateTime'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFF97316).withOpacity(0.35)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF97316).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.edit_calendar_rounded, size: 18, color: Color(0xFFEA580C)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'PROPUESTA DE REPROGRAMACIÓN',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFEA580C),
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          '${_formatFullDate(data['proposedDateTime'])} • ${_formatTime(data['proposedDateTime'])}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFF9A3412),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // 3. SECCIÓN: TIPO DE PLAN & ¿QUIÉN PAGA?
                    Row(
                      children: [
                        // Card Tipo de Plan
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_getPlanIcon(planType), size: 18, color: AppColors.primary),
                                    const SizedBox(width: 6),
                                    const Text('Plan', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  planType,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Card Pago
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(_getPaymentIcon(paymentType), size: 18, color: Colors.teal),
                                    const SizedBox(width: 6),
                                    const Text('Pago', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  paymentType.isNotEmpty ? paymentType : 'No especificado',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // 4. SECCIÓN: DETALLES Y NOTAS DEL PLAN / RESERVA
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
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.notes_rounded, color: Colors.blueAccent, size: 20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Detalles y Notas de la Reserva',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            detailsText.isNotEmpty
                                ? detailsText
                                : 'No se especificaron detalles adicionales para esta reserva.',
                            style: TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: detailsText.isNotEmpty ? AppColors.textPrimary : AppColors.textSecondary,
                              fontStyle: detailsText.isNotEmpty ? FontStyle.normal : FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // 5. SECCIÓN: NOTA O MENSAJE DEL SOLICITANTE (SI EXISTE)
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF9FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.format_quote_rounded, color: AppColors.primary, size: 22),
                                const SizedBox(width: 8),
                                Text(
                                  'Mensaje enviado con la solicitud:',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary.withOpacity(0.85)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Text(
                                '"$message"',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontStyle: FontStyle.italic,
                                  color: AppColors.textPrimary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Barra inferior fija con botones según estado
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
                          Expanded(
                            flex: 1,
                            child: SizedBox(
                              height: 50,
                              child: OutlinedButton(
                                onPressed: _isProcessing ? null : () => _updateStatus('rejected', data),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.redAccent, width: 1.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                                ),
                                child: const Text('Denegar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 15)),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                onPressed: _isProcessing ? null : () => _updateStatus('accepted', data),
                                icon: _isProcessing
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
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
                          icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
                          label: Text(
                            'Abrir Chat con $requesterName',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
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
        icon = Icons.check_circle_rounded;
        text = '¡Reserva Aceptada! Tienes un Match activo 🎉';
        break;
      case 'rejected':
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        icon = Icons.cancel_rounded;
        text = 'Solicitud denegada';
        break;
      default:
        bg = const Color(0xFFFFF3E0);
        fg = const Color(0xFFE65100);
        icon = Icons.hourglass_top_rounded;
        text = 'Solicitud pendiente de tu respuesta';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 13.5)),
          ),
        ],
      ),
    );
  }
}
