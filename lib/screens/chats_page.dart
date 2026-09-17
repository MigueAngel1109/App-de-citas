import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import 'chat_detail_page.dart';

class ChatsPage extends StatelessWidget {
  final bool isEmbedded;

  const ChatsPage({super.key, this.isEmbedded = false});

  void _confirmDeleteChat(BuildContext context, String matchId, String otherName) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar chat?'),
        content: Text('¿Estás seguro de que deseas eliminar la conversación con "$otherName"? Se borrará el match y el chat permanentemente.'),
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
                await FirebaseFirestore.instance.collection('matches').doc(matchId).delete();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat eliminado correctamente'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error al eliminar chat: $e'), backgroundColor: Colors.red),
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

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return isEmbedded
          ? const Center(child: Text('Inicia sesión para ver tus chats'))
          : const Scaffold(
              body: Center(child: Text('Inicia sesión para ver tus chats')),
            );
    }

    final content = StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('matches')
            .where('users', arrayContains: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar conversaciones: ${snapshot.error}'));
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
                      child: const Icon(Icons.forum_outlined, size: 50, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'No tienes chats activos aún',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Cuando aceptes una solicitud de reserva o alguien acepte una de tus solicitudes, se creará un match y podrás chatear aquí para coordinar el encuentro 🎉',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final rawUsers = data['users'];
              final List<String> users = (rawUsers is List)
                  ? rawUsers.map((e) => e.toString()).toList()
                  : [];
              final otherUserId = users.firstWhere((id) => id != currentUser.uid, orElse: () => '');

              final Map<String, dynamic> userNames = {};
              if (data['userNames'] is Map) {
                (data['userNames'] as Map).forEach((k, v) {
                  userNames[k.toString()] = v?.toString() ?? '';
                });
              }

              final Map<String, dynamic> userPhotos = {};
              if (data['userPhotos'] is Map) {
                (data['userPhotos'] as Map).forEach((k, v) {
                  userPhotos[k.toString()] = v?.toString() ?? '';
                });
              }

              final otherName = userNames[otherUserId] ?? 'Tu Match';
              final otherPhoto = userPhotos[otherUserId] ?? '';
              final placeName = data['placeName'] ?? 'Reserva';
              final lastMessage = data['lastMessage'] ?? '¡Match confirmado!';

              return InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatDetailPage(
                        matchId: doc.id,
                        otherUserId: otherUserId,
                        otherUserName: otherName,
                        otherUserPhoto: otherPhoto,
                        lugar: {
                          'nombre': placeName,
                          'hora': 'Confirmada',
                          'icono': '🍷',
                          'usuario': otherName,
                          'avatar': otherPhoto,
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: AppColors.inputBackground,
                            backgroundImage: (otherPhoto.isNotEmpty && (otherPhoto.startsWith('http://') || otherPhoto.startsWith('https://')))
                                ? NetworkImage(otherPhoto)
                                : null,
                            child: otherPhoto.isEmpty
                                ? const Icon(Icons.person, color: AppColors.textLight)
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.favorite, size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  otherName,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.pinkAccent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Match', style: TextStyle(color: Colors.pinkAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Reserva: $placeName',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lastMessage,
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 22),
                        tooltip: 'Eliminar chat',
                        onPressed: () => _confirmDeleteChat(context, doc.id, otherName),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );

    if (isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Chats y Matches',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 20),
        ),
      ),
      body: content,
    );
  }
}
