import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import '../widgets/user_profile_modal.dart';
import 'chat_detail_page.dart';

class CitasPage extends StatefulWidget {
  const CitasPage({super.key});

  @override
  State<CitasPage> createState() => _CitasPageState();
}

class _CitasPageState extends State<CitasPage> {
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

  void _showInvitationBottomSheet(BuildContext context, String invId, Map<String, dynamic> data) {
    final senderName = data['senderName']?.toString() ?? 'Usuario';
    final senderPhoto = data['senderPhoto']?.toString() ?? '';
    final senderId = data['senderId']?.toString() ?? '';
    final placeName = data['placeName']?.toString() ?? 'Reserva';
    final planType = data['planType']?.toString() ?? 'Plan';
    final paymentType = data['paymentType']?.toString() ?? 'Yo invito';
    final message = data['message']?.toString() ?? '';
    final formattedDate = _formatDateTime(data['dateTime']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Cabecera con avatar y perfil
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    UserProfileModal.show(context, userId: senderId, name: senderName, photo: senderPhoto);
                  },
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.inputBackground,
                    backgroundImage: (senderPhoto.isNotEmpty && (senderPhoto.startsWith('http://') || senderPhoto.startsWith('https://')))
                        ? NetworkImage(senderPhoto)
                        : null,
                    child: senderPhoto.isEmpty ? const Icon(Icons.person, color: AppColors.textLight) : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        senderName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        '¡Te ha invitado a una reserva! 💌',
                        style: TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, color: AppColors.primary),
                  tooltip: 'Ver perfil',
                  onPressed: () {
                    UserProfileModal.show(context, userId: senderId, name: senderName, photo: senderPhoto);
                  },
                ),
              ],
            ),
            const Divider(color: AppColors.divider, height: 24),
            // Detalles de la reserva
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant_menu, color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          placeName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_month, color: AppColors.textLight, size: 16),
                      const SizedBox(width: 6),
                      Text(formattedDate, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      Chip(
                        label: Text(planType, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                      Chip(
                        label: Text(paymentType, style: const TextStyle(fontSize: 11, color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                        backgroundColor: Colors.pinkAccent.withOpacity(0.08),
                        visualDensity: VisualDensity.compact,
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  if (message.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '"$message"',
                        style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textPrimary),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Botones aceptar y rechazar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      Navigator.pop(modalCtx);
                      await FirebaseFirestore.instance.collection('invitations').doc(invId).update({
                        'status': 'rejected',
                      });
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invitación rechazada')),
                        );
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                    child: const Text('Rechazar', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(modalCtx);
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) return;

                      await FirebaseFirestore.instance.collection('invitations').doc(invId).update({
                        'status': 'accepted',
                      });

                      // Crear match
                      final matchRef = FirebaseFirestore.instance.collection('matches').doc();
                      await matchRef.set({
                        'matchId': matchRef.id,
                        'users': [currentUser.uid, senderId],
                        'userNames': {
                          currentUser.uid: 'Tú',
                          senderId: senderName,
                        },
                        'userPhotos': {
                          currentUser.uid: '',
                          senderId: senderPhoto,
                        },
                        'placeName': placeName,
                        'status': 'matched',
                        'createdAt': FieldValue.serverTimestamp(),
                        'lastMessage': '¡Invitación aceptada! Empiecen a planear su salida 🍸',
                        'lastMessageTime': FieldValue.serverTimestamp(),
                      });

                      if (context.mounted) {
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
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Aceptar Cita 💖', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: Text('Inicia sesión para ver tus citas y chats')),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Citas y Conexiones',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w900, fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // SECCIÓN SUPERIOR: CARRUSEL HORIZONTAL TIPO STORIES CON INVITACIONES PENDIENTES
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('invitations')
                  .where('receiverId', isEqualTo: currentUser.uid)
                  .where('status', isEqualTo: 'pending')
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) return const SizedBox.shrink();

                return Container(
                  color: Colors.white,
                  padding: const EdgeInsets.only(top: 12, bottom: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            const Text(
                              'Invitaciones a Reservas',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.pinkAccent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${docs.length}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 94,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemCount: docs.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data() as Map<String, dynamic>;
                            final senderName = data['senderName']?.toString() ?? 'Alguien';
                            final senderPhoto = data['senderPhoto']?.toString() ?? '';

                            return GestureDetector(
                              onTap: () => _showInvitationBottomSheet(context, doc.id, data),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(2.5),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Colors.pinkAccent, AppColors.primary, Color(0xFFFFB300)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.pinkAccent.withOpacity(0.25),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                      child: CircleAvatar(
                                        radius: 28,
                                        backgroundColor: AppColors.surface,
                                        backgroundImage: (senderPhoto.isNotEmpty &&
                                                (senderPhoto.startsWith('http://') || senderPhoto.startsWith('https://')))
                                            ? NetworkImage(senderPhoto)
                                            : null,
                                        child: senderPhoto.isEmpty
                                            ? const Icon(Icons.person, color: AppColors.textLight, size: 26)
                                            : null,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  SizedBox(
                                    width: 66,
                                    child: Text(
                                      senderName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Divider(height: 1, color: AppColors.divider),
                    ],
                  ),
                );
              },
            ),

            // SECCIÓN INFERIOR: CHATS ACTIVOS ESTILO BUMBLE
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: const Text(
                'Conversaciones Activas',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('matches')
                  .where('users', arrayContains: currentUser.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: AppColors.primary),
                    ),
                  );
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
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.divider),
                            ),
                            child: const Icon(Icons.forum_outlined, size: 48, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No tienes chats activos aún',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Cuando aceptes una invitación o hagas match en reservas, tus conversaciones aparecerán aquí.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    final users = List<String>.from(data['users'] ?? []);
                    final otherUserId = users.firstWhere((id) => id != currentUser.uid, orElse: () => '');

                    final names = Map<String, dynamic>.from(data['userNames'] ?? {});
                    final otherName = names[otherUserId] ?? 'Tu Cita';

                    final photos = Map<String, dynamic>.from(data['userPhotos'] ?? {});
                    final otherPhoto = photos[otherUserId] ?? '';

                    final placeName = data['placeName'] ?? 'Reserva';
                    final lastMsg = data['lastMessage'] ?? '¡Nuevo match!';

                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        leading: GestureDetector(
                          onTap: () {
                            if (otherUserId.isNotEmpty) {
                              UserProfileModal.show(context, userId: otherUserId, name: otherName, photo: otherPhoto);
                            }
                          },
                          child: Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              CircleAvatar(
                                radius: 26,
                                backgroundColor: AppColors.inputBackground,
                                backgroundImage: (otherPhoto.isNotEmpty &&
                                        (otherPhoto.startsWith('http://') || otherPhoto.startsWith('https://')))
                                    ? NetworkImage(otherPhoto)
                                    : null,
                                child: otherPhoto.isEmpty ? const Icon(Icons.person, color: AppColors.textLight) : null,
                              ),
                              Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent.shade700,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                otherName,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.place_outlined, size: 12, color: AppColors.primary),
                                  const SizedBox(width: 3),
                                  Text(
                                    placeName,
                                    style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            lastMsg,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatDetailPage(
                                lugar: {
                                  'nombre': otherName,
                                  'hora': placeName,
                                  'icono': '💬',
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
