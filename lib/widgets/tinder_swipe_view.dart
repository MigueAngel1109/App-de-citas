import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import '../utils/user_cache_service.dart';
import '../screens/chat_detail_page.dart';
import 'profile_prompts_widget.dart';

import 'discovery_filters_modal.dart';

/// Módulo de Descubrir Personas:
/// Muestra directamente el perfil completo con fotos, datos y estilo de vida (sin swipe de tarjetas),
/// con botones flotantes ("burbujas sobrepuestas") para "No invitar" (Pasar) e "Invitar" (Reserva/Like).
class TinderSwipeView extends StatefulWidget {
  final VoidCallback onSwitchToMap;
  final DiscoveryFilters? filters;
  final bool isPro;
  final VoidCallback? onOpenFilters;

  const TinderSwipeView({
    super.key,
    required this.onSwitchToMap,
    this.filters,
    this.isPro = false,
    this.onOpenFilters,
  });

  @override
  State<TinderSwipeView> createState() => _TinderSwipeViewState();
}

class _TinderSwipeViewState extends State<TinderSwipeView> {
  final List<Map<String, dynamic>> _rawCandidates = [];
  final List<Map<String, dynamic>> _candidates = [];
  final Set<String> _passedIds = {};
  final Set<String> _likedIds = {};
  bool _isLoading = true;
  int _currentIndex = 0;

  final ScrollController _scrollController = ScrollController();

  String? _myInterestedIn;
  String _myName = 'Usuario';
  String _myPhoto = '';
  StreamSubscription? _userSub;
  StreamSubscription? _candidatesSub;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
    _listenToUserChanges();
  }

  @override
  void didUpdateWidget(covariant TinderSwipeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters != widget.filters || oldWidget.isPro != widget.isPro) {
      _applyFilters();
    }
  }

  void _applyFilters() {
    final filters = widget.filters;
    final isPro = widget.isPro;

    final baseList = _rawCandidates.where((c) {
      final cid = c['id']?.toString() ?? '';
      if (cid.isEmpty) return false;
      if (_passedIds.contains(cid) || _likedIds.contains(cid)) return false;
      return true;
    }).toList();

    List<Map<String, dynamic>> filtered;
    if (filters != null) {
      filtered = baseList.where((c) => filters.matchesCandidate(c, isPro: isPro)).toList();
    } else {
      filtered = List.from(baseList);
    }

    setState(() {
      _candidates.clear();
      _candidates.addAll(filtered);
      if (_currentIndex >= _candidates.length) {
        _currentIndex = 0;
      }
    });
    _precacheUpcomingCandidates();
  }

  void _precacheUpcomingCandidates() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (int offset = 0; offset <= 2; offset++) {
        final idx = _currentIndex + offset;
        if (idx >= 0 && idx < _candidates.length) {
          final c = _candidates[idx];
          final rawPhotos = (c['photoUrls'] as List?) ?? (c['photos'] as List?) ?? [];
          for (final p in rawPhotos) {
            final url = p?.toString().trim() ?? '';
            if (url.isNotEmpty && (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('blob:'))) {
              precacheImage(NetworkImage(url), context).catchError((_) {});
            }
          }
        }
      }
    });
  }

  void _listenToUserChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snap) {
      if (snap.exists && mounted) {
        final data = snap.data();
        if (data != null) {
          final newPref = data['interestedIn']?.toString();
          if (newPref != _myInterestedIn) {
            _myInterestedIn = newPref;
            _listenToCandidates();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _candidatesSub?.cancel();
    _scrollController.dispose();
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

  void _listenToCandidates() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _candidatesSub?.cancel();
    _candidatesSub = FirebaseFirestore.instance.collection('users').limit(60).snapshots().listen((querySnapshot) {
      if (!mounted) return;

      final List<Map<String, dynamic>> updatedList = [];
      for (var doc in querySnapshot.docs) {
        // En producción se excluye al usuario mismo; en debug o pruebas permitimos que aparezca
        // para que pueda probar y ver inmediatamente sus cambios y prompts respondidos:
        if (doc.id == user.uid && !kDebugMode) continue;

        final data = doc.data();
        data['id'] = doc.id;
        UserCacheService.put(doc.id, data);
        updatedList.add(data);
      }

      if (_rawCandidates.isEmpty) {
        updatedList.shuffle();
        _rawCandidates.addAll(updatedList);
      } else {
        for (final updated in updatedList) {
          final idx = _rawCandidates.indexWhere((c) => c['id'] == updated['id']);
          if (idx != -1) {
            _rawCandidates[idx] = updated;
          } else {
            _rawCandidates.add(updated);
          }
        }
      }

      _applyFilters();
      if (mounted) setState(() => _isLoading = false);
    }, onError: (e) {
      debugPrint('Error en stream de candidatos: $e');
      if (mounted) setState(() => _isLoading = false);
    });
  }

  Future<void> _loadCandidates() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('users').doc(user.uid).get(),
        SharedPreferences.getInstance(),
        FirebaseFirestore.instance.collection('likes').where('from', isEqualTo: user.uid).get(),
      ]);

      final myDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final prefs = results[1] as SharedPreferences;
      final likesSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;

      final savedPassed = prefs.getStringList('passed_${user.uid}') ?? [];
      final savedLiked = prefs.getStringList('liked_${user.uid}') ?? [];
      _passedIds
        ..clear()
        ..addAll(savedPassed);
      _likedIds
        ..clear()
        ..addAll(savedLiked);
      for (final likeDoc in likesSnap.docs) {
        final toId = likeDoc.data()['to']?.toString() ?? '';
        if (toId.isNotEmpty) {
          _likedIds.add(toId);
        }
      }

      if (myDoc.exists) {
        final myData = myDoc.data();
        if (myData != null) {
          UserCacheService.put(user.uid, myData);
          _myInterestedIn = myData['interestedIn']?.toString();
          _myName = myData['name']?.toString() ?? 'Usuario';
          final pList = (myData['photoUrls'] as List?) ?? (myData['photos'] as List?);
          if (pList != null && pList.isNotEmpty) {
            _myPhoto = pList[0]?.toString() ?? '';
          }
        }
      }

      _listenToCandidates();
    } catch (e) {
      debugPrint('Error loading candidates: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _persistSeenId(String candidateId, {required bool isLiked}) async {
    if (candidateId.isEmpty) return;
    if (isLiked) {
      _likedIds.add(candidateId);
    } else {
      _passedIds.add(candidateId);
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (isLiked) {
        await prefs.setStringList('liked_${user.uid}', _likedIds.toList());
      } else {
        await prefs.setStringList('passed_${user.uid}', _passedIds.toList());
      }
    } catch (_) {}
  }

  Future<void> _resetSeenCandidates() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('passed_${user.uid}');
      } catch (_) {}
    }
    setState(() {
      _passedIds.clear();
      _currentIndex = 0;
    });
    _applyFilters();
  }

  void _onPass() {
    if (_candidates.isEmpty) return;
    final safeIndex = _currentIndex.clamp(0, _candidates.length - 1);
    final currentCandidateId = _candidates[safeIndex]['id']?.toString() ?? '';
    if (currentCandidateId.isNotEmpty) {
      _passedIds.add(currentCandidateId);
      _persistSeenId(currentCandidateId, isLiked: false);
    }

    setState(() {
      _candidates.removeWhere((c) => c['id'] == currentCandidateId);
      if (_currentIndex >= _candidates.length) {
        _currentIndex = 0;
      }
    });

    _precacheUpcomingCandidates();

    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
  }

  Future<void> _handleLike(Map<String, dynamic> candidate, {bool notifyMatch = true}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final candidateId = candidate['id'] as String;
    final candidateName = candidate['name'] ?? 'Usuario';
    final rawPhotos = (candidate['photoUrls'] as List?) ?? (candidate['photos'] as List?) ?? [];
    final candidatePhoto = rawPhotos.isNotEmpty ? rawPhotos[0].toString() : '';

    await _persistSeenId(candidateId, isLiked: true);

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

  void _promptDateInvitation(
    Map<String, dynamic> candidate, {
    String? initialPromptQuestion,
    String? initialPromptAnswer,
  }) async {
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

    final messageCtrl = TextEditingController();
    String? selectedReservationId = myReservations.isNotEmpty ? myReservations.first.id : null;
    bool isSubmitting = false;
    final bool hasPromptContext = initialPromptQuestion != null &&
        initialPromptQuestion.isNotEmpty &&
        initialPromptAnswer != null &&
        initialPromptAnswer.isNotEmpty;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (modalContentCtx, setModalState) {
            final bottomInset = MediaQuery.of(modalContentCtx).viewInsets.bottom;
            final maxSheetHeight = MediaQuery.of(modalContentCtx).size.height * 0.90;

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => FocusScope.of(modalContentCtx).unfocus(),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Container(
                  constraints: BoxConstraints(maxHeight: maxSheetHeight),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 44,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Encabezado
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
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
                        ),

                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          child: Divider(color: AppColors.divider, height: 16),
                        ),

                        if (myReservations.isEmpty)
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (hasPromptContext) ...[
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.reply_rounded, size: 15, color: AppColors.primary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Reaccionando a: $initialPromptQuestion',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '“$initialPromptAnswer”',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
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
                                              _applyFilters();
                                              if (_scrollController.hasClients) {
                                                _scrollController.jumpTo(0);
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
                          )
                        else ...[
                          // Contenido scrollable de reservas y campo de mensaje
                          Flexible(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
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
                                          color: isSelected ? Colors.pinkAccent.withValues(alpha: 0.08) : const Color(0xFFF9FAFB),
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
                                  if (hasPromptContext) ...[
                                    Container(
                                      width: double.infinity,
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.06),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Icon(Icons.reply_rounded, size: 15, color: AppColors.primary),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Respondiendo a: $initialPromptQuestion',
                                                  style: const TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '“$initialPromptAnswer”',
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontStyle: FontStyle.italic,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  Text(
                                    hasPromptContext
                                        ? 'Tu respuesta al rompehielos + invitación:'
                                        : 'Mensaje opcional para acompañar la invitación:',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: messageCtrl,
                                    maxLines: 2,
                                    autofocus: hasPromptContext,
                                    scrollPadding: const EdgeInsets.only(bottom: 40),
                                    decoration: InputDecoration(
                                      hintText: hasPromptContext
                                          ? 'Escribe qué te pareció su respuesta y acompáñalo con tu reserva...'
                                          : 'Ej: ¡Hola! Me encantó tu vibra, tengo esta reserva y me gustaría que vinieras 🍸',
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
                                  const SizedBox(height: 12),
                                ],
                              ),
                            ),
                          ),

                          // Botón Enviar Invitación fijado abajo (sube junto con el teclado)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: (isSubmitting || selectedReservationId == null)
                                        ? null
                                        : () async {
                                            FocusScope.of(modalContentCtx).unfocus();
                                            setModalState(() => isSubmitting = true);
                                            try {
                                              final chosenRes = myReservations.firstWhere((r) => r.id == selectedReservationId);
                                              final chosenData = chosenRes.data() as Map<String, dynamic>;
                                              final rawMsg = messageCtrl.text.trim();
                                              final finalMsg = hasPromptContext
                                                  ? (rawMsg.isNotEmpty
                                                      ? '💬 Sobre "$initialPromptQuestion": $rawMsg'
                                                      : '💬 Me encantó tu respuesta en "$initialPromptQuestion": "$initialPromptAnswer"')
                                                  : rawMsg;

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
                                                'message': finalMsg,
                                                'status': 'pending',
                                                'createdAt': FieldValue.serverTimestamp(),
                                              });

                                              // Guardar Like emitido
                                              await _handleLike(candidate, notifyMatch: false);

                                              if (!mounted) return;
                                              if (modalCtx.mounted) Navigator.pop(modalCtx);

                                              _applyFilters();
                                              if (_scrollController.hasClients) {
                                                _scrollController.jumpTo(0);
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
                                const SizedBox(height: 4),
                                TextButton(
                                  onPressed: () => Navigator.pop(modalCtx),
                                  child: const Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    messageCtrl.dispose();
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
  // CONTENIDO DEL PERFIL (Idéntico a Mi Perfil - Continuo y detallado)
  // -------------------------------------------------------------
  Widget _buildProfileContent(Map<String, dynamic> candidate) {
    final name = candidate['name'] ?? 'Usuario';
    final ageVal = _calculateAge(candidate['birthDate']);
    final age = ageVal > 0 ? ageVal.toString() : '?';
    final bio = (candidate['bio'] ?? '').toString().trim();

    // Ocupación y escuela
    final work = (candidate['work'] ?? '').toString().trim();
    final school = (candidate['school'] ?? candidate['education'] ?? '').toString().trim();

    // Redes y ubicación
    final instagramHandle = (candidate['instagramHandle'] ?? '').toString().replaceAll('@', '').trim();
    final interests =
        (candidate['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    // Estilo de vida
    final lifestyle = candidate['lifestyle'] as Map<String, dynamic>? ?? {};
    final pets = lifestyle['pets'];
    final drinking = lifestyle['drinking'];
    final smokingTobacco = lifestyle['smokingTobacco'];
    final smokingCannabis = lifestyle['smokingCannabis'];
    final workout = lifestyle['workout'];
    final sleepPattern = lifestyle['sleepPattern'];

    // Información personal
    final personal = candidate['personal'] as Map<String, dynamic>? ?? {};
    final zodiac = personal['zodiac'];
    final mbti = personal['mbti'] ?? candidate['mbti'];
    final education = personal['education'];
    final loveLanguage = personal['loveLanguage'];
    final familyPlans = personal['familyPlans'];
    final communication = personal['communication'];
    final languages = (personal['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    // Lista de fotos válidas
    final rawPhotos = (candidate['photoUrls'] as List?) ?? (candidate['photos'] as List?) ?? [];
    final List<String> photoUrls = rawPhotos
        .map((e) => e.toString().trim())
        .where((u) => u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('blob:')))
        .toList();

    final bool hasPrompts = AnsweredPromptsCards.hasAnyAnswer(candidate['prompts']);
    final bool has6OrMorePhotos = photoUrls.length >= 6;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // FOTO 1 (Principal)
          if (photoUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _buildContinuousPhoto(photoUrls[0]),
            ),

          // Nombre, edad, verificación y @instagram debajo de la foto
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                '$name, $age',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const Icon(Icons.verified, color: Colors.blueAccent, size: 24),
              if (instagramHandle.isNotEmpty)
                InkWell(
                  onTap: () => _openInstagram(instagramHandle),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE1306C).withOpacity(0.09),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE1306C).withOpacity(0.35)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildInstagramGlyph(size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '@$instagramHandle',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFE1306C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          const SizedBox(height: 12),

          // =========================================================
          // SECCIÓN "SOBRE MÍ" (ESTRUCTURA VERTICAL ESTRICTA):
          // 1. Biografía / Descripción personal
          // 2. Personalidad MBTI
          // 3. Lenguajes del Amor
          // 4. Signo Zodiacal
          // =========================================================
          _buildSectionHeader('Sobre mí'),
          _buildInfoCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Biografía / Descripción personal
                if (bio.isNotEmpty) ...[
                  Text(bio, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.4)),
                  const SizedBox(height: 16),
                ] else ...[
                  const Text('Sin descripción aún.', style: TextStyle(fontSize: 14, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                  const SizedBox(height: 16),
                ],
                const Divider(color: AppColors.divider, height: 1),
                const SizedBox(height: 14),

                // 2. Personalidad MBTI
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    const Text('Personalidad MBTI: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          mbti != null && mbti.toString().isNotEmpty ? mbti.toString() : 'No especificado',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 3. Lenguajes del Amor
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_outline_rounded, color: Colors.pinkAccent, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Lenguajes del Amor: ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: () {
                        final loveRaw = loveLanguage ?? personal['loveLanguages'];
                        List<String> list = [];
                        if (loveRaw is List) {
                          list = loveRaw.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
                        } else if (loveRaw != null && loveRaw.toString().trim().isNotEmpty) {
                          list = loveRaw.toString().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                        }

                        if (list.isEmpty) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'No especificado',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          );
                        }

                        if (list.length == 1) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  list.first,
                                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                                ),
                              ),
                            ),
                          );
                        }

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: list.map((lang) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    lang,
                                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      }(),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Signo Zodiacal
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.auto_awesome_outlined, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    const Text('Signo Zodiacal: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          zodiac != null && zodiac.toString().isNotEmpty ? zodiac.toString() : 'No especificado',
                          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // FOTO 2
          if (photoUrls.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[1]),
            ),

          // Ocupación y Educación
          if (work.isNotEmpty || school.isNotEmpty) ...[
            _buildSectionHeader('Ocupación y Educación'),
            _buildInfoCard(
              Column(
                children: [
                  if (work.isNotEmpty) _buildListTileInfo(Icons.work_outline, work),
                  if (school.isNotEmpty) _buildListTileInfo(Icons.school_outlined, school),
                ],
              ),
            ),
            const SizedBox(height: 18),
          ],

          // Intereses y Pasiones
          if (interests.isNotEmpty) ...[
            _buildSectionHeader('Intereses y Pasiones'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interests.map((tag) => _buildTagBadge(tag)).toList(),
            ),
            const SizedBox(height: 18),
          ],

          // FOTO 3
          if (photoUrls.length > 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[2]),
            ),

          // Estilo de Vida y Hábitos
          _buildSectionHeader('Estilo de vida'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (pets != null) _buildTagBadge('🐾 $pets'),
              if (drinking != null) _buildTagBadge('🍷 $drinking'),
              if (smokingTobacco != null) _buildTagBadge('🚬 $smokingTobacco'),
              if (smokingCannabis != null) _buildTagBadge('🌿 Cannabis: $smokingCannabis'),
              if (workout != null) _buildTagBadge('💪 $workout'),
              if (sleepPattern != null) _buildTagBadge('⏰ $sleepPattern'),
            ],
          ),
          const SizedBox(height: 18),

          // FOTO 4
          if (photoUrls.length > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[3]),
            ),

          // Más detalles (Educación, Familia, Comunicación, Idiomas)
          _buildSectionHeader('Más sobre mí'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (education != null) _buildTagBadge('🎓 $education'),
              if (familyPlans != null) _buildTagBadge('👶 $familyPlans'),
              if (communication != null) _buildTagBadge('💬 $communication'),
              if (languages.isNotEmpty) _buildTagBadge('🗣️ ${languages.join(', ')}'),
            ],
          ),
          const SizedBox(height: 18),

          // =========================================================
          // FOTOS RESTANTES Y PROMPT(S) RESPONDIDOS
          // =========================================================
          if (has6OrMorePhotos) ...[
            // 1. Si tiene 6 o más fotos: Foto 5 (penúltima)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[4]),
            ),

            // 2. Prompt(s) en medio de las dos últimas fotos
            if (hasPrompts)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: AnsweredPromptsCards(
                  prompts: Map<String, dynamic>.from(candidate['prompts'] as Map),
                  onReplyPrompt: (q, a) => _promptDateInvitation(
                    candidate,
                    initialPromptQuestion: q,
                    initialPromptAnswer: a,
                  ),
                ),
              ),

            // 3. Foto 6 (última foto estándar)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[5]),
            ),

            // Fotos adicionales si hubiese más de 6
            for (int i = 6; i < photoUrls.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildContinuousPhoto(photoUrls[i]),
              ),
          ] else ...[
            // Si NO cuenta con todas las fotos (menos de 6 fotos):
            // Mostramos la Foto 5 si existe (índice 4)
            if (photoUrls.length > 4)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: _buildContinuousPhoto(photoUrls[4]),
              ),

            // Y agregamos el prompt respondido por el usuario ABAJO DE TODO:
            if (hasPrompts)
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: AnsweredPromptsCards(
                  prompts: Map<String, dynamic>.from(candidate['prompts'] as Map),
                  onReplyPrompt: (q, a) => _promptDateInvitation(
                    candidate,
                    initialPromptQuestion: q,
                    initialPromptAnswer: a,
                  ),
                ),
              ),
          ],

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildInfoCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: child,
    );
  }

  Widget _buildTagBadge(String text, {bool isHighlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.primary.withValues(alpha: 0.08) : const Color(0xFFEBEBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlight ? AppColors.primary.withValues(alpha: 0.3) : const Color(0xFFDADADA),
          width: 1.0,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isHighlight ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildContinuousPhoto(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 380,
        width: double.infinity,
        color: AppColors.surface,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          cacheWidth: 900,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (wasSynchronouslyLoaded) return child;
            return AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: child,
            );
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: AppColors.surface,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surface,
            child: const Center(
              child: Icon(Icons.broken_image, size: 50, color: AppColors.textLight),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInstagramGlyph({double size = 22}) {
    return Container(
      width: size,
      height: size,
      margin: size > 16 ? const EdgeInsets.only(right: 12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.28),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [
            Color(0xFFFCAF45),
            Color(0xFFF77737),
            Color(0xFFE1306C),
            Color(0xFFC13584),
            Color(0xFF833AB4),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: size * 0.63,
          height: size * 0.63,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.18),
            border: Border.all(color: Colors.white, width: size > 16 ? 1.5 : 1.1),
          ),
          child: Center(
            child: Container(
              width: size * 0.23,
              height: size * 0.23,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: size > 16 ? 1.2 : 0.9),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListTileInfo(IconData? icon, String text, {Color? iconColor, Widget? leadingWidget, Widget? trailing}) {
    return Row(
      children: [
        if (leadingWidget != null)
          leadingWidget
        else if (icon != null) ...[
          Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  // -------------------------------------------------------------
  // BURBUJAS DE ACCIÓN FLOTANTES (SOBREPUESTAS ENCIMA)
  // -------------------------------------------------------------
  Widget _buildFloatingActionBubbles(Map<String, dynamic> candidate) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 1. Botón No Invitar / Pasar (Cruz roja sobre fondo blanco)
        _buildCircleButton(
          icon: Icons.close,
          color: Colors.redAccent,
          backgroundColor: Colors.white,
          size: 58,
          iconSize: 28,
          onTap: _onPass,
        ),
        const SizedBox(width: 14),

        // 2. Botón Invitar a Reserva (Calendario oscuro sobre fondo blanco)
        _buildCircleButton(
          icon: Icons.calendar_month_rounded,
          color: AppColors.primary,
          backgroundColor: Colors.white,
          size: 58,
          iconSize: 28,
          onTap: () => _promptDateInvitation(candidate),
        ),
      ],
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required Color color,
    Color backgroundColor = Colors.white,
    required double size,
    required double iconSize,
    required VoidCallback onTap,
  }) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: backgroundColor,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Icon(icon, color: color, size: iconSize),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // ESTADO VACÍO CUANDO NO HAY MÁS CANDIDATOS
  // -------------------------------------------------------------
  Widget _buildEmptyState() {
    final hasFilters = widget.filters != null && widget.filters!.hasActiveFilters(isPro: widget.isPro);
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
              child: Icon(
                hasFilters ? Icons.tune_rounded : Icons.celebration_outlined,
                size: 54,
                color: hasFilters ? const Color(0xFFFF5E3A) : AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              hasFilters ? 'Sin resultados con estos filtros' : '¡Has visto todos los perfiles!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters
                  ? 'No hay personas en este momento que cumplan con todos los filtros seleccionados en Bogotá. Ajusta o amplía tus filtros para ver más perfiles.'
                  : 'Por ahora has explorado a todas las personas según tus preferencias en Bogotá. Vuelve a consultar pronto o ajusta tus zonas.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            if (hasFilters && widget.onOpenFilters != null)
              ElevatedButton.icon(
                onPressed: widget.onOpenFilters,
                icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                label: const Text('Modificar Filtros',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: () {
                  _resetSeenCandidates();
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
}

