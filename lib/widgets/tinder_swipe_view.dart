import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import 'user_profile_modal.dart';
import '../screens/chat_detail_page.dart';

class TinderSwipeView extends StatefulWidget {
  final VoidCallback onSwitchToMap;

  const TinderSwipeView({super.key, required this.onSwitchToMap});

  @override
  State<TinderSwipeView> createState() => _TinderSwipeViewState();
}

class _TinderSwipeViewState extends State<TinderSwipeView> with SingleTickerProviderStateMixin {
  final List<Map<String, dynamic>> _candidates = [];
  bool _isLoading = true;
  int _currentIndex = 0;
  int _currentPhotoIndex = 0;

  Offset _dragOffset = Offset.zero;
  double _dragAngle = 0;

  String? _myInterestedIn;
  String _myName = 'Usuario';
  String _myPhoto = '';

  @override
  void initState() {
    super.initState();
    _loadCandidates();
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
      final querySnapshot = await FirebaseFirestore.instance.collection('users').limit(50).get();

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

      // Mezclar aleatoriamente para variedad estilo Tinder
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
      debugPrint('Error loading tinder candidates: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _dragAngle = (_dragOffset.dx / 300) * (pi / 12);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    const threshold = 100.0;
    if (_dragOffset.dx > threshold) {
      _swipeRight();
    } else if (_dragOffset.dx < -threshold) {
      _swipeLeft();
    } else {
      setState(() {
        _dragOffset = Offset.zero;
        _dragAngle = 0;
      });
    }
  }

  void _swipeRight() {
    if (_currentIndex >= _candidates.length) return;
    final candidate = _candidates[_currentIndex];
    _promptDateInvitation(candidate);
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
                          color: Colors.grey.withOpacity(0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Encabezado
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.inputBackground,
                          backgroundImage: (candidatePhoto.isNotEmpty && (candidatePhoto.startsWith('http://') || candidatePhoto.startsWith('https://')))
                              ? NetworkImage(candidatePhoto)
                              : null,
                          child: candidatePhoto.isEmpty ? const Icon(Icons.person, color: AppColors.textLight) : null,
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
                      // Si no tiene reservas publicadas, sugerir crear una
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Column(
                          children: [
                            const Icon(Icons.restaurant_menu, size: 40, color: AppColors.primary),
                            const SizedBox(height: 10),
                            const Text(
                              'Aún no tienes reservas activas publicadas',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Para invitar a una persona a una cita, primero publica tu reserva con el restaurante, fecha y hora.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pop(modalCtx);
                                Navigator.pushNamed(context, '/publish');
                              },
                              icon: const Icon(Icons.add, color: Colors.white, size: 18),
                              label: const Text('Publicar una Reserva Ahora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      const SizedBox(height: 8),

                      // Lista de reservas activas del anfitrión
                      ...myReservations.map((resDoc) {
                        final resData = resDoc.data() as Map<String, dynamic>;
                        final isSelected = selectedReservationId == resDoc.id;
                        final placeName = resData['placeName'] ?? 'Restaurante';
                        final planType = resData['planType'] ?? 'Plan';
                        final dt = resData['dateTime'] as Timestamp?;
                        final formattedDate = dt != null ? '${dt.toDate().day}/${dt.toDate().month} • ${dt.toDate().hour.toString().padLeft(2, '0')}:${dt.toDate().minute.toString().padLeft(2, '0')}' : 'Fecha acordada';

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedReservationId = resDoc.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? AppColors.primary : AppColors.divider,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                  color: isSelected ? AppColors.primary : AppColors.textLight,
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
                                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
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

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('¡Invitación a tu reserva enviada a $candidateName! 💌'),
                                        backgroundColor: AppColors.primary,
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

  void _swipeLeft() {
    if (_currentIndex >= _candidates.length) return;
    setState(() {
      _currentIndex++;
      _currentPhotoIndex = 0;
    });
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

  void _showMatchDialog({required String otherName, required String otherPhoto}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
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
              const SizedBox(height: 24),

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
                            BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 8),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 38,
                          backgroundColor: AppColors.surface,
                          backgroundImage: _myPhoto.isNotEmpty ? NetworkImage(_myPhoto) : null,
                          child: _myPhoto.isEmpty ? const Icon(Icons.person, size: 38) : null,
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
                          backgroundImage: otherPhoto.isNotEmpty ? NetworkImage(otherPhoto) : null,
                          child: otherPhoto.isEmpty ? const Icon(Icons.person, size: 38) : null,
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

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogCtx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatDetailPage(
                          lugar: {
                            'nombre': 'Chat con $otherName',
                            'hora': '¡Nuevo Match!',
                            'icono': '✨',
                          },
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_bubble, color: Colors.white, size: 20),
                  label: Text('Enviar Mensaje a $otherName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Seguir Descubriendo', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
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
            Text('Buscando personas afines para ti...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      );
    }

    if (_candidates.isEmpty || _currentIndex >= _candidates.length) {
      return _buildEmptyState();
    }

    final currentCandidate = _candidates[_currentIndex];
    final nextCandidate = (_currentIndex + 1 < _candidates.length) ? _candidates[_currentIndex + 1] : null;

    return Column(
      children: [
        // Stack de Tarjetas
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
            child: Stack(
              children: [
                // Tarjeta de Fondo (siguiente)
                if (nextCandidate != null)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 0.95,
                      child: _buildCardContent(nextCandidate, isTopCard: false),
                    ),
                  ),

                // Tarjeta Superior (Activa con arrastre)
                Positioned.fill(
                  child: GestureDetector(
                    onPanUpdate: _onPanUpdate,
                    onPanEnd: _onPanEnd,
                    child: Transform.translate(
                      offset: _dragOffset,
                      child: Transform.rotate(
                        angle: _dragAngle,
                        child: _buildCardContent(currentCandidate, isTopCard: true),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Botones de Acción (Tinder Bar)
        _buildActionButtons(),
        const SizedBox(height: 90),
      ],
    );
  }

  Widget _buildCardContent(Map<String, dynamic> candidate, {required bool isTopCard}) {
    final name = candidate['name'] ?? 'Usuario';
    final age = _calculateAge(candidate['birthDate']);
    final bio = candidate['bio'] ?? '';
    final relationshipGoal = candidate['relationshipGoal'] ?? '';
    final interests = (candidate['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final rawPhotos = (candidate['photoUrls'] as List?) ?? (candidate['photos'] as List?) ?? [];
    final List<String> photos = rawPhotos
        .map((e) => e.toString())
        .where((u) => u.startsWith('http://') || u.startsWith('https://'))
        .toList();

    final currentPhoto = photos.isNotEmpty ? photos[_currentPhotoIndex.clamp(0, photos.length - 1)] : '';

    return GestureDetector(
      onTap: () {
        UserProfileModal.show(
          context,
          userId: candidate['id'] ?? '',
          name: name,
          photo: currentPhoto,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagen de fondo completa
              if (currentPhoto.isNotEmpty)
                Image.network(
                  currentPhoto,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.surface,
                    child: const Center(child: Icon(Icons.broken_image, size: 60, color: AppColors.textLight)),
                  ),
                )
              else
                Container(
                  color: const Color(0xFF2C2C2C),
                  child: const Center(child: Icon(Icons.person, size: 90, color: Colors.white54)),
                ),

            // Sombra degradada para texto legible
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 260,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.85),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // Navegación de fotos táctil (Izquierda: anterior, Derecha: siguiente)
            if (isTopCard && photos.length > 1)
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_currentPhotoIndex > 0) {
                          setState(() => _currentPhotoIndex--);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: () {
                        if (_currentPhotoIndex < photos.length - 1) {
                          setState(() => _currentPhotoIndex++);
                        }
                      },
                    ),
                  ),
                ],
              ),

            // Indicadores de historias / fotos en la parte superior
            if (photos.length > 1)
              Positioned(
                top: 12,
                left: 14,
                right: 14,
                child: Row(
                  children: List.generate(photos.length, (i) {
                    final isActive = i == _currentPhotoIndex;
                    return Expanded(
                      child: Container(
                        height: 3.5,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: isActive ? Colors.white : Colors.white.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // Sellos LIKE / NOPE en el arrastre
            if (isTopCard && _dragOffset.dx > 40)
              Positioned(
                top: 50,
                left: 30,
                child: Transform.rotate(
                  angle: -0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.greenAccent, width: 3),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black.withOpacity(0.2),
                    ),
                    child: const Text(
                      'INVITAR 💌',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ),

            if (isTopCard && _dragOffset.dx < -40)
              Positioned(
                top: 50,
                right: 30,
                child: Transform.rotate(
                  angle: 0.2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent, width: 3),
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.black.withOpacity(0.2),
                    ),
                    child: const Text(
                      'NO INVITAR ❌',
                      style: TextStyle(color: Colors.redAccent, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ),

            // Información inferior de la persona
            Positioned(
              left: 18,
              right: 18,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          age > 0 ? '$name, $age' : name,
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [Shadow(color: Colors.black45, blurRadius: 4)],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, color: Colors.white, size: 26),
                        tooltip: 'Ver perfil completo',
                        onPressed: () {
                          UserProfileModal.show(
                            context,
                            userId: candidate['id'] ?? '',
                            name: name,
                            photo: currentPhoto,
                          );
                        },
                      ),
                    ],
                  ),

                  // Objetivo en la app badge
                  if (relationshipGoal.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.22),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                          const SizedBox(width: 5),
                          Text(
                            relationshipGoal,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Biografía breve
                  if (bio.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      bio,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // Intereses
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: interests.take(3).map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 11)),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Botón No Invitar
          _buildCircleButton(
            icon: Icons.close,
            color: Colors.redAccent,
            size: 68,
            iconSize: 30,
            label: 'No invitar',
            onTap: _swipeLeft,
          ),

          // Botón Invitar a Reserva
          _buildCircleButton(
            icon: Icons.calendar_month_rounded,
            color: AppColors.primary,
            size: 68,
            iconSize: 30,
            label: 'Invitar',
            onTap: _swipeRight,
          ),
        ],
      ),
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
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(icon, color: color, size: iconSize),
            onPressed: onTap,
          ),
        ),
        if (label != null) ...[  
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

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
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14),
                ],
              ),
              child: const Icon(Icons.people_outline, size: 54, color: AppColors.textLight),
            ),
            const SizedBox(height: 20),
            const Text(
              '¡Has visto a todas las personas por ahora! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 8),
            Text(
              _myInterestedIn != null
                  ? 'Revisaste todos los perfiles de "$_myInterestedIn". Vuelve más tarde para conocer nuevas personas o explora las reservas en el mapa.'
                  : 'Vuelve más tarde para conocer nuevas personas o explora las reservas en el mapa.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: widget.onSwitchToMap,
              icon: const Icon(Icons.map, color: Colors.white),
              label: const Text('Ver Reservas en el Mapa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadCandidates,
              icon: const Icon(Icons.refresh, color: AppColors.primary),
              label: const Text('Volver a mezclar perfiles', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
