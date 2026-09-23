import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import 'publish_reservation_page.dart';
import 'request_detail_page.dart';
import '../widgets/user_profile_modal.dart';

class ReservasPage extends StatefulWidget {
  final Function(GeoPoint?)? onPublished;

  const ReservasPage({super.key, this.onPublished});

  @override
  State<ReservasPage> createState() => _ReservasPageState();
}

class _ReservasPageState extends State<ReservasPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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

  // DIÁLOGO PARA EDITAR RESERVA
  void _showEditReservationDialog(String docId, Map<String, dynamic> data) {
    final placeCtrl = TextEditingController(text: data['placeName'] ?? '');
    final detailsCtrl = TextEditingController(text: data['details'] ?? '');
    final linkCtrl = TextEditingController(text: data['link'] ?? '');

    String selectedPlan = data['planType'] ?? 'Comida';
    String selectedPayment = data['paymentType'] ?? 'Yo invito';
    DateTime selectedDate = DateTime.now();
    TimeOfDay selectedTime = TimeOfDay.now();

    if (data['dateTime'] != null && data['dateTime'] is Timestamp) {
      final dt = (data['dateTime'] as Timestamp).toDate();
      selectedDate = dt;
      selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalContentCtx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(modalContentCtx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
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
                          color: Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Editar Reserva Publicada',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),
                    const Divider(color: AppColors.divider),
                    const SizedBox(height: 12),

                    // Nombre del Lugar
                    const Text('Lugar o Restaurante', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: placeCtrl,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.inputBorder)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Fecha y Hora
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now(),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setModalState(() => selectedDate = d);
                            },
                            icon: const Icon(Icons.calendar_month, size: 16, color: AppColors.primary),
                            label: Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final t = await showTimePicker(
                                context: context,
                                initialTime: selectedTime,
                              );
                              if (t != null) setModalState(() => selectedTime = t);
                            },
                            icon: const Icon(Icons.access_time, size: 16, color: AppColors.primary),
                            label: Text(
                              selectedTime.format(context),
                              style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Plan y Pago
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedPlan,
                            decoration: InputDecoration(
                              labelText: 'Tipo de plan',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: ['Comida/Cena', 'Tragos', 'Café', 'Brunch'].map((p) {
                              return DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setModalState(() => selectedPlan = v);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: selectedPayment,
                            decoration: InputDecoration(
                              labelText: 'Modalidad',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            items: ['Yo invito', 'Cuentas separadas', 'Abierto a discutir'].map((p) {
                              return DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)));
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) setModalState(() => selectedPayment = v);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Punch Line / Detalles
                    TextField(
                      controller: detailsCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Punch Line / Propuesta',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Link de reserva
                    TextField(
                      controller: linkCtrl,
                      decoration: InputDecoration(
                        labelText: 'Link de reserva externa (opcional)',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final newDateTime = DateTime(
                            selectedDate.year,
                            selectedDate.month,
                            selectedDate.day,
                            selectedTime.hour,
                            selectedTime.minute,
                          );

                          await FirebaseFirestore.instance.collection('reservations').doc(docId).update({
                            'placeName': placeCtrl.text.trim(),
                            'planType': selectedPlan,
                            'paymentType': selectedPayment,
                            'details': detailsCtrl.text.trim(),
                            'link': linkCtrl.text.trim(),
                            'dateTime': Timestamp.fromDate(newDateTime),
                          });

                          if (!mounted) return;
                          if (modalCtx.mounted) {
                            Navigator.pop(modalCtx);
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Reserva actualizada correctamente')),
                          );
                        },
                        child: const Text('Guardar Cambios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
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

  void _confirmDeleteRequest(String requestId, String requesterName, String placeName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('¿Eliminar solicitud?'),
        content: Text('¿Deseas descartar la solicitud de $requesterName para "$placeName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await FirebaseFirestore.instance.collection('reservation_requests').doc(requestId).delete();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Solicitud descartada')),
                );
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Reservas',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            // Pestaña 1: Solicitudes
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('reservation_requests')
                  .where('hostUserId', isEqualTo: currentUser.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Solicitudes'),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.pinkAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$pendingCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            // Pestaña 2: Mis Reservas
            const Tab(text: 'Mis Reservas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRequestsTab(currentUser.uid),
          _buildMyReservationsTab(currentUser.uid),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add_circle, color: Colors.white),
        label: const Text('Publicar Reserva', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PublishReservationPage(
                onPublished: (loc) {
                  Navigator.pop(context);
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
    );
  }

  // =============================================================
  // PESTAÑA 1: SOLICITUDES ACTIVAS RECIBIDAS
  // =============================================================
  Widget _buildRequestsTab(String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservation_requests')
          .where('hostUserId', isEqualTo: currentUserId)
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
                    child: const Icon(Icons.favorite_border, size: 48, color: AppColors.textLight),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'No tienes solicitudes todavía',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Cuando otros usuarios vean tus reservas en el mapa y soliciten unirse, aparecerán aquí para que revises su perfil.',
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
          final aTs = aData['createdAt'] as Timestamp?;
          final bTs = bData['createdAt'] as Timestamp?;
          if (aTs == null && bTs == null) return 0;
          if (aTs == null) return 1;
          if (bTs == null) return -1;
          return bTs.compareTo(aTs);
        });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;

            final requesterName = data['requesterName'] ?? 'Usuario';
            final requesterPhoto = data['requesterPhoto'] ?? '';
            final placeName = data['placeName'] ?? 'Reserva';
            final status = data['status'] ?? 'pending';
            final dateTimeStr = _formatDateTime(data['dateTime']);
            final message = data['message'] ?? '';

            Color statusColor;
            String statusLabel;
            switch (status) {
              case 'accepted':
                statusColor = Colors.green;
                statusLabel = 'Aceptada';
                break;
              case 'rejected':
                statusColor = Colors.red;
                statusLabel = 'Rechazada';
                break;
              default:
                statusColor = AppColors.primary;
                statusLabel = 'Pendiente';
            }

            return InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequestDetailPage(
                      requestId: doc.id,
                      initialData: data,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.divider),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            final reqId = data['requesterUserId']?.toString() ?? data['requesterId']?.toString() ?? '';
                            if (reqId.isNotEmpty) {
                              UserProfileModal.show(context, userId: reqId, name: requesterName, photo: requesterPhoto);
                            }
                          },
                          child: CircleAvatar(
                            radius: 26,
                            backgroundColor: AppColors.inputBackground,
                            backgroundImage: (requesterPhoto.isNotEmpty && (requesterPhoto.startsWith('http://') || requesterPhoto.startsWith('https://')))
                                ? NetworkImage(requesterPhoto)
                                : null,
                            child: requesterPhoto.isEmpty ? const Icon(Icons.person, color: AppColors.textLight) : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                requesterName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Quiere unirse a: $placeName',
                                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDeleteRequest(doc.id, requesterName, placeName),
                        ),
                      ],
                    ),
                    if (message.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '"$message"',
                          style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 13, color: AppColors.textLight),
                        const SizedBox(width: 5),
                        Text(dateTimeStr, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                        const Spacer(),
                        const Text('Ver detalles', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =============================================================
  // PESTAÑA 2: MIS RESERVAS CON FOTO DE FONDO DEL LUGAR Y OVERLAY
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

        // Un solo stream para contar las solicitudes de todas las reservas del anfitrión en vez de N streams
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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
              itemCount: sortedDocs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final doc = sortedDocs[index];
                final data = doc.data() as Map<String, dynamic>;

                final placeName = data['placeName'] ?? 'Restaurante';
                final planType = data['planType'] ?? 'Comida';
                final paymentType = data['paymentType'] ?? '';
                final dateTimeStr = _formatDateTime(data['dateTime']);
                final details = data['details'] ?? '';
                final photoUrl = (data['placePhoto'] ?? data['restaurantPhoto'] ?? '').toString();
                final count = requestCountByResId[doc.id] ?? 0;

                return Container(
                  height: 190,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
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
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.85),
                                  const Color(0xFF1E222B),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Center(
                              child: Icon(Icons.restaurant, size: 70, color: Colors.white.withOpacity(0.15)),
                            ),
                          ),

                        // Filtro oscuro semitransparente para legibilidad de tipografía blanca
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.4),
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
                                      ],
                                    ),
                                  ),
                                  // Acciones: Editar y Eliminar
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.white),
                                    tooltip: 'Editar',
                                    onPressed: () => _showEditReservationDialog(doc.id, data),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.25),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      paymentType.isNotEmpty ? '$planType • $paymentType' : planType,
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: count > 0 ? Colors.pinkAccent : Colors.black.withOpacity(0.4),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.people_alt_outlined, size: 13, color: Colors.white),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$count solicitudes',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                        ),
                                      ],
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
                );
              },
            );
          },
        );
      },
    );
  }
}
