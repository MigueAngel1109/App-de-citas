import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import '../screens/chat_detail_page.dart';
import 'instagram_icon.dart';

/// Módulo de Descubrir Personas:
/// Muestra directamente el perfil completo con fotos, datos y estilo de vida (sin swipe de tarjetas),
/// con botones flotantes ("burbujas sobrepuestas") para "No invitar" (Pasar) e "Invitar" (Reserva/Like).
class TinderSwipeView extends StatefulWidget {
  final VoidCallback onSwitchToMap;

  const TinderSwipeView({super.key, required this.onSwitchToMap});

  @override
  State<TinderSwipeView> createState() => _TinderSwipeViewState();
}

class _TinderSwipeViewState extends State<TinderSwipeView> {
  final List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _currentPhotoIndex = 0;

  final ScrollController _scrollController = ScrollController();
  final PageController _photoPageController = PageController();

  String? _myInterestedIn;
  String _myName = 'Usuario';
  String _myPhoto = '';

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _photoPageController.dispose();
    super.dispose();
  }

  int _calculateAge(dynamic birthDate) {
    if (birthDate == null) return 0;
    DateTime dt;
    if (birthDate is Timestamp) {
      dt = birthDate.toDate();
    } else if (birthDate is DateTime) {
      dt = birthDate;
    } else {
      return 0;
    }
    final now = DateTime.now();
    int age = now.year - dt.year;
    if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) {
      age--;
    }
    return age;
  }

  void _openInstagram(String handle) async {
    final clean = handle.replaceAll('@', '').trim();
    if (clean.isEmpty) return;
    final uri = Uri.parse('https://instagram.com/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication, webOnlyWindowName: '_blank');
    }
  }

  Future<void> _loadCandidates() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Obtener preferencias del usuario actual
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (myDoc.exists) {
        final myData = myDoc.data();
        if (myData != null) {
          _myInterestedIn = myData['interestedIn']?.toString();
          _myName = myData['name']?.toString() ?? 'Usuario';
          final pList = (myData['photoUrls'] as List?) ?? (myData['photos'] as List?);
          if (pList != null && pList.isNotEmpty) {
            _myPhoto = pList[0]?.toString() ?? '';
          }
        }
      }

      // 2. Consultar usuarios en Firestore
      final querySnapshot = await FirebaseFirestore.instance.collection('users').limit(60).get();

      final List<Map<String, dynamic>> list = [];
      for (var doc in querySnapshot.docs) {
        if (doc.id == user.uid) continue; // Excluirse a sí mismo

        final data = doc.data();
        data['id'] = doc.id;

        // Filtrar por a quién busca (interestedIn)
        final gender = (data['gender'] ?? '').toString().toLowerCase();
        if (_myInterestedIn != null && _myInterestedIn!.isNotEmpty) {
          final pref = _myInterestedIn!.toLowerCase();
          if (pref.contains('mujer') && !gender.contains('mujer')) {
            continue;
          }
          if (pref.contains('hombre') && !gender.contains('hombre')) {
            continue;
          }
        }

        list.add(data);
      }

      // Mezclar aleatoriamente para variedad
      list.shuffle();

      if (mounted) {
        setState(() {
          _candidates.clear();
          _candidates.addAll(list);
          _currentIndex = 0;
          _currentPhotoIndex = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading candidates: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onPass() {
    if (_currentIndex >= _candidates.length) return;
    setState(() {
      _currentIndex++;
      _currentPhotoIndex = 0;
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    if (_photoPageController.hasClients) {
      _photoPageController.jumpToPage(0);
    }
  }

  Future<void> _handleLike(Map<String, dynamic> candidate, {bool notifyMatch = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final candidateId = candidate['id'] as String;
    final candidateName = candidate['name'] ?? 'Usuario';
    final rawPhotos = (candidate['photoUrls'] as List?) ?? (candidate['photos'] as List?) ?? [];
    final candidatePhoto = rawPhotos.isNotEmpty ? rawPhotos[0].toString() : '';

    try {
      // 1. Guardar Like emitido
      final likeId = '${user.uid}_$candidateId';
      await FirebaseFirestore.instance.collection('likes').doc(likeId).set({
        'from': user.uid,
        'to': candidateId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Comprobar si el otro usuario ya me dio Like
      final reciprocalLikeId = '${candidateId}_${user.uid}';
      final reciprocalDoc = await FirebaseFirestore.instance.collection('likes').doc(reciprocalLikeId).get();

      if (reciprocalDoc.exists && notifyMatch) {
        // ¡ES UN MATCH MUTUO!
        final matchRef = FirebaseFirestore.instance.collection('matches').doc();
        await matchRef.set({
          'matchId': matchRef.id,
          'users': [user.uid, candidateId],
          'userNames': {
            user.uid: _myName,
            candidateId: candidateName,
          },
          'userPhotos': {
            user.uid: _myPhoto,
            candidateId: candidatePhoto,
          },
          'placeName': 'Descubrir Personas',
          'status': 'matched',
          'createdAt': FieldValue.serverTimestamp(),
          'lastMessage': '¡Se gustaron mutuamente! Empiecen una conversación 🎉',
          'lastMessageTime': FieldValue.serverTimestamp(),
        });

        if (mounted) {
          _showMatchDialog(
            otherName: candidateName,
            otherPhoto: candidatePhoto,
          );
        }
      }
    } catch (e) {
      debugPrint('Error handling like: $e');
    }
  }

  void _promptDateInvitation(Map<String, dynamic> candidate) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final candidateName = candidate['name'] ?? 'Usuario';
    final rawPhotos = (candidate['photoUrls'] as List?) ?? (candidate['photos'] as List?) ?? [];
    final candidatePhoto = rawPhotos.isNotEmpty ? rawPhotos[0].toString() : '';

    // Consultar las reservas activas publicadas por el usuario actual
    QuerySnapshot? myReservationsSnap;
    try {
      myReservationsSnap = await FirebaseFirestore.instance
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();
    } catch (e) {
      debugPrint('Error fetching my active reservations: $e');
    }

    final myReservations = myReservationsSnap?.docs ?? [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        String? selectedReservationId;
        if (myReservations.isNotEmpty) {
          selectedReservationId = myReservations.first.id;
        }
        final messageCtrl = TextEditingController();
        bool isSubmitting = false;

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
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Encabezado
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.inputBackground,
                          backgroundImage: (candidatePhoto.isNotEmpty &&
                                  (candidatePhoto.startsWith('http://') || candidatePhoto.startsWith('https://')))
                              ? NetworkImage(candidatePhoto)
                              : null,
                          child: candidatePhoto.isEmpty
                              ? const Icon(Icons.person, color: AppColors.textLight)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Invitar a $candidateName',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Selecciona una de tus reservas publicadas 💕',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(modalCtx),
                        ),
                      ],
                    ),

                    const Divider(color: AppColors.divider, height: 24),

                    if (myReservations.isEmpty) ...[
                      // Si no tiene reservas activas, sugerir publicar o dar Like directo
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.restaurant_menu_rounded, size: 40, color: AppColors.primary),
                            const SizedBox(height: 10),
                            const Text(
                              'Aún no tienes reservas activas publicadas',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Publica una reserva para invitar a $candidateName a salir, o dale un Like directo para conectar.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  Navigator.pushNamed(context, '/publish');
                                },
                                icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                label: const Text('Publicar una Reserva Ahora',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () async {
                                  Navigator.pop(modalCtx);
                                  await _handleLike(candidate, notifyMatch: true);
                                  setState(() {
                                    _currentIndex++;
                                    _currentPhotoIndex = 0;
                                  });
                                  if (_scrollController.hasClients) {
                                    _scrollController.jumpTo(0);
                                  }
                                  if (_photoPageController.hasClients) {
                                    _photoPageController.jumpToPage(0);
                                  }
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('¡Le diste Me Gusta a $candidateName! ❤️'),
                                        backgroundColor: Colors.pinkAccent,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 18),
                                label: const Text('Dar Me Gusta directo ❤️',
                                    style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.pinkAccent),
                                  padding: const EdgeInsets.symmetric(vertical: 13),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      const Text(
                        'Tus reservas disponibles:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 10),

                      // Lista de reservas activas del anfitrión
                      ...myReservations.map((resDoc) {
                        final resData = resDoc.data() as Map<String, dynamic>;
                        final isSelected = selectedReservationId == resDoc.id;
                        final placeName = resData['placeName'] ?? 'Restaurante';
                        final planType = resData['planType'] ?? 'Plan';
                        final dt = resData['dateTime'] as Timestamp?;
                        final formattedDate = dt != null
                            ? '${dt.toDate().day}/${dt.toDate().month} • ${dt.toDate().hour.toString().padLeft(2, '0')}:${dt.toDate().minute.toString().padLeft(2, '0')}'
                            : 'Fecha acordada';

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedReservationId = resDoc.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.pinkAccent.withOpacity(0.08) : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? Colors.pinkAccent : AppColors.divider,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? Colors.pinkAccent : AppColors.textLight,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        placeName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSelected ? Colors.pinkAccent : AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$planType • $formattedDate',
                                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 12),
                      const Text(
                        'Mensaje opcional para acompañar la invitación:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: messageCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Ej: ¡Hola! Me encantó tu vibra, tengo esta reserva y me gustaría que vinieras 🍸',
                          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFFF9FAFB),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Botón Enviar Invitación
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: (isSubmitting || selectedReservationId == null)
                              ? null
                              : () async {
                                  setModalState(() => isSubmitting = true);
                                  try {
                                    final chosenRes = myReservations.firstWhere((r) => r.id == selectedReservationId);
                                    final chosenData = chosenRes.data() as Map<String, dynamic>;

                                    final invRef = FirebaseFirestore.instance.collection('invitations').doc();
                                    await invRef.set({
                                      'id': invRef.id,
                                      'reservationId': chosenRes.id,
                                      'senderId': user.uid,
                                      'senderName': _myName,
                                      'senderPhoto': _myPhoto,
                                      'receiverId': candidate['id'],
                                      'receiverName': candidateName,
                                      'receiverPhoto': candidatePhoto,
                                      'placeName': chosenData['placeName'] ?? 'Restaurante',
                                      'planType': chosenData['planType'] ?? 'Cita',
                                      'paymentType': chosenData['paymentType'] ?? 'Yo invito',
                                      'dateTime': chosenData['dateTime'] ?? FieldValue.serverTimestamp(),
                                      'message': messageCtrl.text.trim(),
                                      'status': 'pending',
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });

                                    // Guardar Like emitido
                                    await _handleLike(candidate, notifyMatch: false);

                                    if (!mounted) return;
                                    if (modalCtx.mounted) Navigator.pop(modalCtx);

                                    setState(() {
                                      _currentIndex++;
                                      _currentPhotoIndex = 0;
                                    });
                                    if (_scrollController.hasClients) {
                                      _scrollController.jumpTo(0);
                                    }
                                    if (_photoPageController.hasClients) {
                                      _photoPageController.jumpToPage(0);
                                    }

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('¡Invitación a tu reserva enviada a $candidateName! 💌'),
                                        backgroundColor: Colors.pinkAccent,
                                        behavior: SnackBarBehavior.floating,
                                      ),
                                    );
                                  } catch (e) {
                                    setModalState(() => isSubmitting = false);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error al enviar invitación: $e'), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.favorite, color: Colors.white, size: 18),
                          label: Text(
                            isSubmitting ? 'Enviando invitación...' : 'Enviar Invitación a Mi Reserva 💌',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pinkAccent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.pop(modalCtx),
                        child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
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

  void _showMatchDialog({required String otherName, required String otherPhoto}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
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
                child: const Icon(Icons.favorite, color: Colors.pinkAccent, size: 38),
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
                'Tú y $otherName se han gustado mutuamente.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 20),

              // Fotos entrelazadas
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
                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: AppColors.surface,
                          backgroundImage: (_myPhoto.isNotEmpty && (_myPhoto.startsWith('http://') || _myPhoto.startsWith('https://')))
                              ? NetworkImage(_myPhoto)
                              : null,
                          child: _myPhoto.isEmpty ? const Icon(Icons.person, color: AppColors.textLight, size: 30) : null,
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
                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: AppColors.surface,
                          backgroundImage: (otherPhoto.isNotEmpty && (otherPhoto.startsWith('http://') || otherPhoto.startsWith('https://')))
                              ? NetworkImage(otherPhoto)
                              : null,
                          child: otherPhoto.isEmpty ? const Icon(Icons.person, color: AppColors.textLight, size: 30) : null,
                        ),
                      ),
                    ),
                  ],
                ),
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
                        builder: (_) => ChatDetailPage(
                          lugar: const {
                            'nombre': 'Descubrir Personas',
                            'tipo': 'Match',
                          },
                          otherUserId: _candidates[_currentIndex]['id'] ?? '',
                          otherUserName: otherName,
                          otherUserPhoto: otherPhoto,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                  label: const Text('Enviar un Mensaje Ahora',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Seguir Descubriendo',
                    style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            SizedBox(height: 16),
            Text('Buscando personas afines para ti...',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    if (_candidates.isEmpty || _currentIndex >= _candidates.length) {
      return _buildEmptyState();
    }

    final candidate = _candidates[_currentIndex];

    return Stack(
      children: [
        // Capa 1: Vista completa y scrolleable del perfil
        Positioned.fill(
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 110), // Espacio para que las burbujas no tapen el final
            child: _buildProfileContent(candidate),
          ),
        ),

        // Capa 2: Degradado suave en la parte inferior para fundir el scroll
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 100,
          child: IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background.withOpacity(0.0),
                    AppColors.background.withOpacity(0.8),
                    AppColors.background,
                  ],
                ),
              ),
            ),
          ),
        ),

        // Capa 3: Botones de Acción Flotantes (Burbujas sobrepuestas)
        Positioned(
          left: 24,
          right: 24,
          bottom: 16,
          child: _buildFloatingActionBubbles(candidate),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // CONTENIDO DEL PERFIL (Visual estilo Feeld/Hinge + Ficha detallada)
  // -------------------------------------------------------------
  Widget _buildProfileContent(Map<String, dynamic> candidate) {
    final name = candidate['name'] ?? 'Usuario';
    final age = _calculateAge(candidate['birthDate']);
    final bio = (candidate['bio'] ?? '').toString().trim();
    final gender = (candidate['gender'] ?? '').toString();
    final showGender = candidate['showGenderOnProfile'] ?? true;
    final sexualOrientation =
        (candidate['sexualOrientation'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final relationshipGoal = (candidate['relationshipGoal'] ?? '').toString();
    final instagramHandle = (candidate['instagramHandle'] ?? '').toString().replaceAll('@', '').trim();

    final work = (candidate['work'] ?? '').toString().trim();
    final school = (candidate['school'] ?? candidate['education'] ?? '').toString().trim();
    final interests =
        (candidate['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final lifestyle = candidate['lifestyle'] as Map<String, dynamic>? ?? {};
    final personal = candidate['personal'] as Map<String, dynamic>? ?? {};
    final mbti = personal['mbti'] ?? candidate['mbti'];

    // Lista de fotos válidas
    final rawPhotos = (candidate['photoUrls'] as List?) ?? (candidate['photos'] as List?) ?? [];
    final List<String> photos = rawPhotos
        .map((e) => e.toString().trim())
        .where((u) => u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://')))
        .toList();


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. FOTO PRINCIPAL CON BORDES REDONDEADOS Y PAGINACIÓN LATERAL (Estilo Imagen 1)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          child: _buildMainPhotoCard(photos, name),
        ),

        // 2. ENCABEZADO: Nombre, Verificación, Estado y Subtítulo
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            age > 0 ? '$name, $age' : name,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.verified, color: Colors.blueAccent, size: 22),
                      ],
                    ),
                  ),

                  // Badge "ACTIVO RECIENTE" / "LAST SEEN" (como en la Imagen 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'ACTIVO RECIENTE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF555A68),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // Subtítulo: Género y Orientación (ej: "33 · Mujer · Heterosexual")
              Text(
                _buildSubtitleText(age, gender, showGender, sexualOrientation),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 3),

              // Ubicación
              const Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 14, color: AppColors.textLight),
                  SizedBox(width: 4),
                  Text(
                    'Bogotá',
                    style: TextStyle(fontSize: 13, color: AppColors.textLight),
                  ),
                ],
              ),

              // Chip de Instagram si existe
              if (instagramHandle.isNotEmpty) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () => _openInstagram(instagramHandle),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1306C).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1306C).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const InstagramIcon(size: 15, color: Color(0xFFE1306C)),
                        const SizedBox(width: 5),
                        Text(
                          '@$instagramHandle',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFE1306C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 3. OBJETIVO EN LA APP (como estaba antes - imagen de referencia)
        if (relationshipGoal.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'OBJETIVO EN LA APP',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        Text(
                          relationshipGoal,
                          style: const TextStyle(
                            fontSize: 14,
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
          ),

        // 4. BIOGRAFÍA (Imagen 2)
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Biografía'),
                _buildCard(
                  Text(
                    bio,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // 5. DESEOS / INTERESES (Burbujas suaves estilo Imagen 1: "Desires")
        if (interests.isNotEmpty) ...[
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Deseos e Intereses'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: interests.map((tag) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECEFF5), // Burbuja gris suave como Imagen 1
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E6EF)),
                      ),
                      child: Text(
                        tag,
                        style: const TextStyle(
                          color: Color(0xFF282E3B),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],

        // 6. SOBRE MÍ (Formato lista con iconos - Imagen 2)
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Sobre mí'),
              _buildCard(
                Column(
                  children: [
                    if (work.isNotEmpty) _buildRow(Icons.work_outline, 'Ocupación: $work'),
                    if (school.isNotEmpty) ...[
                      if (work.isNotEmpty) const Divider(height: 16),
                      _buildRow(Icons.school_outlined, 'Educación: $school'),
                    ],
                    if (mbti != null) ...[
                      const Divider(height: 16),
                      _buildRow(Icons.psychology_outlined, 'Personalidad MBTI: $mbti'),
                    ],
                    if (personal['zodiac'] != null) ...[
                      const Divider(height: 16),
                      _buildRow(Icons.nights_stay_outlined, 'Signo: ${personal['zodiac']}'),
                    ],
                    if (personal['loveLanguage'] != null) ...[
                      const Divider(height: 16),
                      _buildRow(Icons.favorite_outline, 'Lenguaje del amor: ${personal['loveLanguage']}'),
                    ],
                    if (personal['familyPlans'] != null) ...[
                      const Divider(height: 16),
                      _buildRow(Icons.child_care_outlined, 'Planes familiares: ${personal['familyPlans']}'),
                    ],
                    if (personal['communication'] != null) ...[
                      const Divider(height: 16),
                      _buildRow(Icons.chat_bubble_outline, 'Comunicación: ${personal['communication']}'),
                    ],
                    if (personal['languages'] != null && (personal['languages'] as List).isNotEmpty) ...[
                      const Divider(height: 16),
                      _buildRow(Icons.translate, 'Idiomas: ${(personal['languages'] as List).join(", ")}'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // 8. ESTILO DE VIDA Y HÁBITOS
        if (lifestyle.isNotEmpty) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Estilo de Vida'),
                _buildCard(
                  Column(
                    children: [
                      if (lifestyle['pets'] != null) _buildRow(Icons.pets, 'Mascotas: ${lifestyle['pets']}'),
                      if (lifestyle['workout'] != null) ...[
                        const Divider(height: 14),
                        _buildRow(Icons.fitness_center, 'Ejercicio: ${lifestyle['workout']}'),
                      ],
                      if (lifestyle['drinking'] != null) ...[
                        const Divider(height: 14),
                        _buildRow(Icons.local_bar, 'Bebidas: ${lifestyle['drinking']}'),
                      ],
                      if (lifestyle['smokingTobacco'] != null) ...[
                        const Divider(height: 14),
                        _buildRow(Icons.smoking_rooms, 'Tabaco: ${lifestyle['smokingTobacco']}'),
                      ],
                      if (lifestyle['smokingCannabis'] != null) ...[
                        const Divider(height: 14),
                        _buildRow(Icons.eco_outlined, 'Cannabis: ${lifestyle['smokingCannabis']}'),
                      ],
                      if (lifestyle['sleepPattern'] != null) ...[
                        const Divider(height: 14),
                        _buildRow(Icons.bedtime_outlined, 'Horario de sueño: ${lifestyle['sleepPattern']}'),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 24),
      ],
    );
  }

  // -------------------------------------------------------------
  // FOTOS SUPERIORES CON CARRUSEL DESLIZABLE A LA IZQUIERDA
  // -------------------------------------------------------------
  Widget _buildMainPhotoCard(List<String> photos, String name) {
    final photoHeight = MediaQuery.of(context).size.height * 0.52;

    if (photos.isEmpty) {
      return Container(
        height: photoHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C2C),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(child: Icon(Icons.person, size: 90, color: Colors.white54)),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: photoHeight,
        width: double.infinity,
        color: const Color(0xFF1E1E1E),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Carrusel horizontal de fotos con soporte para deslizamiento táctil y de ratón
            ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: PageView.builder(
                controller: _photoPageController,
                itemCount: photos.length,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (index) {
                  setState(() {
                    _currentPhotoIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return Image.network(
                    photos[index],
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.surface,
                      child: const Center(child: Icon(Icons.broken_image, size: 60, color: AppColors.textLight)),
                    ),
                  );
                },
              ),
            ),

            // Sombra suave inferior para legibilidad
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 100,
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),

            // Zonas de toque táctil para pasar fotos al presionar (Izquierda: anterior, Derecha: siguiente)
            if (photos.length > 1)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_currentPhotoIndex > 0) {
                          _photoPageController.previousPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_currentPhotoIndex < photos.length - 1) {
                          _photoPageController.nextPage(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),

            // Barras de historias superiores (indicadores de foto)
            if (photos.length > 1)
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: IgnorePointer(
                  child: Row(
                    children: List.generate(photos.length, (i) {
                      final isActive = i == _currentPhotoIndex;
                      return Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 3.5,
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          decoration: BoxDecoration(
                            color: isActive ? Colors.white : Colors.white.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 2),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // BURBUJAS DE ACCIÓN FLOTANTES (SOBREPUESTAS ENCIMA)
  // -------------------------------------------------------------
  Widget _buildFloatingActionBubbles(Map<String, dynamic> candidate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Botón No Invitar (como estaba antes: cruz roja)
        _buildCircleButton(
          icon: Icons.close,
          color: Colors.redAccent,
          size: 66,
          iconSize: 30,
          label: 'No invitar',
          onTap: _onPass,
        ),

        // 2. Botón Invitar a Reserva (como estaba antes: calendario)
        _buildCircleButton(
          icon: Icons.calendar_month_rounded,
          color: AppColors.primary,
          size: 66,
          iconSize: 30,
          label: 'Invitar',
          onTap: () => _promptDateInvitation(candidate),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
    String? label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.18),
                blurRadius: 16,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Center(
                child: Icon(icon, color: color, size: iconSize),
              ),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  // -------------------------------------------------------------
  // ESTADO VACÍO CUANDO NO HAY MÁS CANDIDATOS
  // -------------------------------------------------------------
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.celebration_outlined, size: 54, color: AppColors.primary),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Has visto todos los perfiles!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Por ahora has explorado a todas las personas según tus preferencias en Bogotá. Vuelve a consultar pronto o ajusta tus zonas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _currentIndex = 0;
                });
                _loadCandidates();
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Volver a explorar perfiles',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: widget.onSwitchToMap,
              icon: const Icon(Icons.map_outlined, color: AppColors.textSecondary, size: 18),
              label: const Text('Ver Reservas en el Mapa',
                  style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // HELPERS DE DISEÑO Y COMPONENTES
  // -------------------------------------------------------------
  String _buildSubtitleText(int age, String gender, bool showGender, List<String> sexualOrientation) {
    final parts = <String>[];
    if (showGender && gender.isNotEmpty) parts.add(gender);
    if (sexualOrientation.isNotEmpty) parts.add(sexualOrientation.first);
    return parts.join(' · ');
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
          letterSpacing: -0.2,
        ),
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
