import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import '../widgets/user_profile_modal.dart';

// ============================================================
// CHAT DETALLE - PANTALLA DE CHAT EN TIEMPO REAL CON ANFITRIÓN / MATCH
// ============================================================

class ChatDetailPage extends StatefulWidget {
  final Map<String, String> lugar;
  final String? matchId;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserPhoto;

  const ChatDetailPage({
    super.key,
    required this.lugar,
    this.matchId,
    this.otherUserId,
    this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _mensajeController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _activeMatchId;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _activeMatchId = widget.matchId;
    if (_activeMatchId == null || _activeMatchId!.isEmpty) {
      _resolveOrCreateMatch();
    }
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _resolveOrCreateMatch() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final targetUserId = widget.otherUserId;
    if (targetUserId == null || targetUserId.isEmpty) return;

    try {
      // Buscar si ya existe un match entre estos dos usuarios
      final query = await FirebaseFirestore.instance
          .collection('matches')
          .where('users', arrayContains: currentUserId)
          .get();

      for (var doc in query.docs) {
        final users = (doc.data()['users'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        if (users.contains(targetUserId)) {
          if (mounted) {
            setState(() {
              _activeMatchId = doc.id;
            });
          }
          return;
        }
      }

      // Si no existe, crear el match
      final newMatchRef = FirebaseFirestore.instance.collection('matches').doc();
      final placeName = widget.lugar['nombre'] ?? 'Reserva';
      final otherName = widget.otherUserName ?? widget.lugar['usuario'] ?? 'Usuario';
      final otherPhoto = widget.otherUserPhoto ?? widget.lugar['avatar'] ?? '';

      // Obtener datos del usuario actual
      String myName = 'Usuario';
      String myPhoto = '';
      try {
        final myDoc = await FirebaseFirestore.instance.collection('users').doc(currentUserId).get();
        if (myDoc.exists && myDoc.data() != null) {
          myName = myDoc.data()!['name']?.toString() ?? 'Usuario';
          final pList = (myDoc.data()!['photoUrls'] as List?) ?? (myDoc.data()!['photos'] as List?);
          if (pList != null && pList.isNotEmpty) {
            myPhoto = pList[0]?.toString() ?? '';
          }
        }
      } catch (_) {}

      await newMatchRef.set({
        'matchId': newMatchRef.id,
        'placeName': placeName,
        'users': [currentUserId, targetUserId],
        'userNames': {
          currentUserId: myName,
          targetUserId: otherName,
        },
        'userPhotos': {
          currentUserId: myPhoto,
          targetUserId: otherPhoto,
        },
        'status': 'matched',
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '¡Conexión creada!',
        'lastMessageTime': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _activeMatchId = newMatchRef.id;
        });
      }
    } catch (e) {
      debugPrint('Error resolviendo match para chat: $e');
    }
  }

  Future<void> _enviarMensaje() async {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty || _isSending) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final matchId = _activeMatchId ?? widget.matchId;
    if (matchId == null || matchId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conectando con el chat... intenta de nuevo en un segundo')),
      );
      return;
    }

    _mensajeController.clear();
    setState(() => _isSending = true);

    try {
      final matchRef = FirebaseFirestore.instance.collection('matches').doc(matchId);

      await matchRef.collection('messages').add({
        'senderId': user.uid,
        'senderName': user.displayName ?? 'Usuario',
        'text': texto,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await matchRef.update({
        'lastMessage': texto,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastSenderId': user.uid,
      });
    } catch (e) {
      debugPrint('Error enviando mensaje: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  String _formatMsgTime(dynamic dt) {
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

  void _confirmDeleteChat(BuildContext context) {
    final matchId = _activeMatchId ?? widget.matchId;
    if (matchId == null) return;
    final usuarioNombre = widget.otherUserName ?? widget.lugar['usuario'] ?? 'este usuario';

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar chat?'),
        content: Text('¿Estás seguro de que deseas eliminar la conversación con "$usuarioNombre"? Se borrará el match y el chat permanentemente.'),
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
                  Navigator.pop(context);
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final usuarioNombre = widget.otherUserName ?? widget.lugar['usuario'] ?? 'Match';
    final avatarUrl = widget.otherUserPhoto ?? widget.lugar['avatar'] ?? '';
    final placeName = widget.lugar['nombre'] ?? 'Reserva';
    final matchId = _activeMatchId ?? widget.matchId;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: () {
            if (widget.otherUserId != null && widget.otherUserId!.isNotEmpty) {
              UserProfileModal.show(
                context,
                userId: widget.otherUserId!,
                name: usuarioNombre,
                photo: avatarUrl,
              );
            }
          },
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.inputBackground,
                    backgroundImage: (avatarUrl.isNotEmpty && (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://')))
                        ? NetworkImage(avatarUrl)
                        : null,
                    child: avatarUrl.isEmpty
                        ? const Icon(Icons.person, color: AppColors.textLight, size: 20)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      usuarioNombre,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'En línea • $placeName',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (matchId != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Eliminar chat',
              onPressed: () => _confirmDeleteChat(context),
            ),
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Llamando a $usuarioNombre...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFFFD1D1D)),
            onPressed: () {
              final url = widget.lugar['instagram_url'];
              if (url != null) {
                final Uri uri = Uri.parse(url);
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de info de la reserva arriba del chat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: AppColors.primary.withOpacity(0.06),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reserva confirmada: $placeName (${widget.lugar['hora'] ?? 'Confirmada'})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Mensajes en tiempo real desde Firestore
          Expanded(
            child: matchId == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('matches')
                        .doc(matchId)
                        .collection('messages')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                      }

                      if (snapshot.hasError) {
                        return Center(child: Text('Error al cargar mensajes: ${snapshot.error}'));
                      }

                      final docs = snapshot.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return Center(
                          child: SingleChildScrollView(
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
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: const Icon(Icons.wine_bar_rounded, size: 48, color: AppColors.primary),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  '¡Conexión para $placeName!',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Escríbele un mensaje a $usuarioNombre para coordinar su encuentro y disfrutar de la reserva 🎉',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final data = docs[index].data() as Map<String, dynamic>;
                          final senderId = data['senderId']?.toString() ?? '';
                          final text = data['text']?.toString() ?? '';
                          final isMe = senderId == currentUserId;
                          final timeStr = _formatMsgTime(data['createdAt']);

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.76,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                              decoration: BoxDecoration(
                                color: isMe ? AppColors.primary : AppColors.white,
                                borderRadius: BorderRadius.only(
                                  topLeft: const Radius.circular(18),
                                  topRight: const Radius.circular(18),
                                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                                  bottomRight: Radius.circular(isMe ? 4 : 18),
                                ),
                                border: isMe ? null : Border.all(color: AppColors.divider.withOpacity(0.8)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.04),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    text,
                                    style: TextStyle(
                                      color: isMe ? Colors.white : AppColors.textPrimary,
                                      fontSize: 14.5,
                                      height: 1.35,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    timeStr,
                                    style: TextStyle(
                                      color: isMe ? Colors.white.withOpacity(0.65) : AppColors.textLight,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          // Barra de entrada de texto
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(
                  top: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.icon),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Funcionalidad de fotos disponible próximamente'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _mensajeController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _enviarMensaje(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.white, size: 18),
                      onPressed: _enviarMensaje,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
