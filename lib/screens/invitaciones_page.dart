import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import '../widgets/user_profile_modal.dart';
import 'chat_detail_page.dart';

class InvitacionesPage extends StatefulWidget {
  const InvitacionesPage({super.key});

  @override
  State<InvitacionesPage> createState() => _InvitacionesPageState();
}

class _InvitacionesPageState extends State<InvitacionesPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _myName = 'Usuario';
  String _myPhoto = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data();
        if (data != null) {
          setState(() {
            _myName = data['name']?.toString() ?? 'Usuario';
            final pList = (data['photoUrls'] as List?) ?? (data['photos'] as List?);
            if (pList != null && pList.isNotEmpty) {
              _myPhoto = pList[0]?.toString() ?? '';
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading current user data in InvitacionesPage: $e');
    }
  }

  String _formatDateTime(dynamic dt) {
    if (dt == null) return 'Fecha por acordar';
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

  Future<void> _acceptInvitation(BuildContext context, String invId, Map<String, dynamic> data) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final senderId = data['senderId']?.toString() ?? '';
    final senderName = data['senderName']?.toString() ?? 'Tu Cita';
    final senderPhoto = data['senderPhoto']?.toString() ?? '';
    final placeName = data['placeName']?.toString() ?? 'Cita Romántica';
    final formattedTime = _formatDateTime(data['dateTime']);

    try {
      // 1. Actualizar estado de la invitación
      await FirebaseFirestore.instance.collection('invitations').doc(invId).update({
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      // 2. Crear match en la colección matches para habilitar chat
      final matchRef = FirebaseFirestore.instance.collection('matches').doc();
      await matchRef.set({
        'matchId': matchRef.id,
        'invitationId': invId,
        'placeName': placeName,
        'users': [currentUser.uid, senderId],
        'userNames': {
          currentUser.uid: _myName,
          senderId: senderName,
        },
        'userPhotos': {
          currentUser.uid: _myPhoto,
          senderId: senderPhoto,
        },
        'status': 'matched',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '¡Cita aceptada en $placeName! 🎉 Empiecen a coordinar',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      // 3. Mostrar modal de celebración de Cita Confirmada
      showDialog(
        context: context,
        builder: (dialogCtx) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.pinkAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 44),
                ),
                const SizedBox(height: 16),
                const Text(
                  '¡CITA ACEPTADA! 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Has aceptado la invitación de $senderName para ir a "$placeName". ¡Ahora son un Match y pueden chatear!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dialogCtx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatDetailPage(
                            lugar: {
                              'nombre': placeName,
                              'hora': formattedTime,
                              'icono': '🍷',
                            },
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Ir al Chat de la Cita',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Cerrar', style: TextStyle(color: AppColors.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al aceptar invitación: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _rejectInvitation(BuildContext context, String invId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Rechazar invitación?'),
        content: const Text('Esta acción le informará a la persona que no podrás asistir a la cita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('invitations').doc(invId).update({
          'status': 'rejected',
          'rejectedAt': FieldValue.serverTimestamp(),
        });
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invitación rechazada'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver tus invitaciones')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Módulo de Invitaciones',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            // Pestaña 1: Recibidas (con contador en vivo de pendientes)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invitations')
                  .where('receiverId', isEqualTo: currentUser.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                final pendingCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                return Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Recibidas'),
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
            const Tab(text: 'Enviadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReceivedTab(currentUser.uid),
          _buildSentTab(currentUser.uid),
        ],
      ),
    );
  }

  // =============================================================
  // PESTAÑA 1: INVITACIONES RECIBIDAS
  // =============================================================
  Widget _buildReceivedTab(String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invitations')
          .where('receiverId', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar invitaciones: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptyReceived();
        }

        // Ordenar en memoria por fecha más reciente
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'];
          final bTime = bData['createdAt'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildReceivedInvitationCard(doc.id, data);
          },
        );
      },
    );
  }

  Widget _buildReceivedInvitationCard(String docId, Map<String, dynamic> data) {
    final senderId = data['senderId']?.toString() ?? '';
    final senderName = data['senderName']?.toString() ?? 'Alguien';
    final senderPhoto = data['senderPhoto']?.toString() ?? '';
    final placeName = data['placeName']?.toString() ?? 'Lugar por definir';
    final planType = data['planType']?.toString() ?? 'Cita';
    final paymentType = data['paymentType']?.toString() ?? 'Yo invito';
    final message = data['message']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';
    final formattedDate = _formatDateTime(data['dateTime']);

    Color statusBgColor;
    Color statusTextColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusBgColor = Colors.green.withOpacity(0.12);
        statusTextColor = Colors.green.shade800;
        statusLabel = '¡Cita Aceptada!';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusBgColor = Colors.redAccent.withOpacity(0.12);
        statusTextColor = Colors.redAccent;
        statusLabel = 'Rechazada';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusBgColor = Colors.amber.withOpacity(0.14);
        statusTextColor = Colors.orange.shade900;
        statusLabel = 'Pendiente';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: status == 'pending' ? Colors.pinkAccent.withOpacity(0.3) : AppColors.divider,
          width: status == 'pending' ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabecera con info del remitente y estado
          Row(
            children: [
              GestureDetector(
                onTap: () => UserProfileModal.show(context, userId: senderId, name: senderName, photo: senderPhoto),
                child: CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.inputBackground,
                  backgroundImage: (senderPhoto.isNotEmpty && (senderPhoto.startsWith('http://') || senderPhoto.startsWith('https://')))
                      ? NetworkImage(senderPhoto)
                      : null,
                  child: senderPhoto.isEmpty
                      ? const Icon(Icons.person, color: AppColors.textLight)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      senderName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Te invitó a una cita desde Descubrir',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusTextColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(color: statusTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Tarjeta con detalles de la Cita propuesta
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.restaurant_rounded, color: AppColors.primary, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        placeName,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, size: 15, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Text(
                      formattedDate,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _buildChip(Icons.local_activity_outlined, planType, AppColors.primary),
                    _buildChip(Icons.credit_card, paymentType, Colors.indigo),
                  ],
                ),
                if (message.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Divider(height: 14, color: AppColors.divider),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.format_quote_rounded, size: 16, color: Colors.pinkAccent),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '"$message"',
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textPrimary,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Botones de acción según el estado
          if (status == 'pending') ...[
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: OutlinedButton.icon(
                    onPressed: () => UserProfileModal.show(context, userId: senderId, name: senderName, photo: senderPhoto),
                    icon: const Icon(Icons.person_outline, size: 16),
                    label: const Text('Ver Perfil', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(color: AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: OutlinedButton(
                    onPressed: () => _rejectInvitation(context, docId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Rechazar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptInvitation(context, docId, data),
                    icon: const Icon(Icons.favorite, color: Colors.white, size: 16),
                    label: const Text('Aceptar Cita', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.pinkAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (status == 'accepted') ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(
                        lugar: {
                          'nombre': placeName,
                          'hora': formattedDate,
                          'icono': '🍷',
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 17),
                label: const Text('Ir al Chat de la Cita', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =============================================================
  // PESTAÑA 2: INVITACIONES ENVIADAS
  // =============================================================
  Widget _buildSentTab(String currentUserId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('invitations')
          .where('senderId', isEqualTo: currentUserId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar invitaciones: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return _buildEmptySent();
        }

        // Ordenar en memoria por fecha
        final sortedDocs = List<QueryDocumentSnapshot>.from(docs);
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['createdAt'];
          final bTime = bData['createdAt'];
          if (aTime is Timestamp && bTime is Timestamp) {
            return bTime.compareTo(aTime);
          }
          return 0;
        });

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          itemCount: sortedDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            final doc = sortedDocs[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildSentInvitationCard(data);
          },
        );
      },
    );
  }

  Widget _buildSentInvitationCard(Map<String, dynamic> data) {
    final receiverId = data['receiverId']?.toString() ?? '';
    final receiverName = data['receiverName']?.toString() ?? 'Usuario';
    final receiverPhoto = data['receiverPhoto']?.toString() ?? '';
    final placeName = data['placeName']?.toString() ?? 'Lugar';
    final planType = data['planType']?.toString() ?? 'Cita';
    final paymentType = data['paymentType']?.toString() ?? 'Yo invito';
    final message = data['message']?.toString() ?? '';
    final status = data['status']?.toString() ?? 'pending';
    final formattedDate = _formatDateTime(data['dateTime']);

    Color statusBgColor;
    Color statusTextColor;
    String statusLabel;
    IconData statusIcon;

    switch (status) {
      case 'accepted':
        statusBgColor = Colors.green.withOpacity(0.12);
        statusTextColor = Colors.green.shade800;
        statusLabel = '¡Aceptada! 🎉';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'rejected':
        statusBgColor = Colors.redAccent.withOpacity(0.12);
        statusTextColor = Colors.redAccent;
        statusLabel = 'Rechazada';
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusBgColor = Colors.amber.withOpacity(0.14);
        statusTextColor = Colors.orange.shade900;
        statusLabel = 'Esperando respuesta...';
        statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => UserProfileModal.show(context, userId: receiverId, name: receiverName, photo: receiverPhoto),
                child: CircleAvatar(
                  radius: 24,
                  backgroundColor: AppColors.inputBackground,
                  backgroundImage: (receiverPhoto.isNotEmpty && (receiverPhoto.startsWith('http://') || receiverPhoto.startsWith('https://')))
                      ? NetworkImage(receiverPhoto)
                      : null,
                  child: receiverPhoto.isEmpty
                      ? const Icon(Icons.person, color: AppColors.textLight)
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invitaste a $receiverName',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Para ir a $placeName',
                      style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: statusTextColor),
                    const SizedBox(width: 4),
                    Text(
                      statusLabel,
                      style: TextStyle(color: statusTextColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                ),
                const Spacer(),
                Text(
                  '$planType • $paymentType',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Tu mensaje: "$message"',
              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),
          ],
          if (status == 'accepted') ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(
                        lugar: {
                          'nombre': placeName,
                          'hora': formattedDate,
                          'icono': '🍷',
                        },
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 16),
                label: const Text('Ir al Chat con tu Cita', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyReceived() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.pinkAccent.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mark_email_unread_outlined, size: 52, color: Colors.pinkAccent),
            ),
            const SizedBox(height: 20),
            const Text(
              'No tienes invitaciones pendientes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cada vez que una persona le dé al corazón de "Me gusta" a tu perfil en Descubrir Personas para invitarte a una cita, su invitación llegará aquí para que decidas si la aceptas 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySent() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.divider),
              ),
              child: const Icon(Icons.send_outlined, size: 50, color: AppColors.textLight),
            ),
            const SizedBox(height: 18),
            const Text(
              'Aún no has enviado invitaciones',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Ve al módulo de Descubrir Personas, dale al corazón de Me Gusta a quien llame tu atención y configúrale una invitación a una cita personalizada 💕',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
