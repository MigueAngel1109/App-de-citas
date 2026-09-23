import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';
import 'discover_page.dart';
import 'citas_page.dart';
import 'reservas_page.dart';
import 'my_profile_page.dart';

class HomePage extends StatefulWidget {
  final String email;

  const HomePage({super.key, required this.email});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  final GlobalKey<DiscoverPageState> _discoverKey = GlobalKey<DiscoverPageState>();
  late final List<Widget> _pages;

  String? _userPhotoUrl;
  int _pendingRequestsCount = 0;
  int _pendingInvitationsCount = 0;
  StreamSubscription? _userSub;
  StreamSubscription? _requestsSub;
  StreamSubscription? _invitationsSub;

  @override
  void initState() {
    super.initState();
    _pages = [
      DiscoverPage(key: _discoverKey),
      const CitasPage(),
      ReservasPage(
        onPublished: (loc) {
          // Cambiar a la pestaña del mapa tras publicar exitosamente
          setState(() {
            _selectedIndex = 0;
          });
          if (loc != null) {
            _discoverKey.currentState?.moveToLocation(LatLng(loc.latitude, loc.longitude));
          }
        },
      ),
      const MyProfilePage(),
    ];
    _listenToUserData();
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _requestsSub?.cancel();
    _invitationsSub?.cancel();
    super.dispose();
  }

  void _listenToUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Escuchar foto del usuario para mostrarla en el avatar del menú
    _userSub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((snap) {
      if (snap.exists && mounted) {
        final data = snap.data();
        if (data != null) {
          final pList = (data['photoUrls'] as List?) ?? (data['photos'] as List?);
          if (pList != null && pList.isNotEmpty) {
            setState(() {
              _userPhotoUrl = pList[0]?.toString();
            });
          }
        }
      }
    });

    // Escuchar solicitudes pendientes para la insignia en vivo de Reservas
    _requestsSub = FirebaseFirestore.instance
        .collection('reservation_requests')
        .where('hostUserId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _pendingRequestsCount = snap.docs.length;
        });
      }
    });

    // Escuchar invitaciones pendientes para la insignia en vivo de Invitaciones
    _invitationsSub = FirebaseFirestore.instance
        .collection('invitations')
        .where('receiverId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (mounted) {
        setState(() {
          _pendingInvitationsCount = snap.docs.length;
        });
      }
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: false,
      extendBody: true, // Permite que el mapa fluya por detrás de la barra flotante elevada
      extendBodyBehindAppBar: true,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: SafeArea(
        bottom: true,
        child: Padding(
          padding: const EdgeInsets.only(left: 18, right: 18, bottom: 12),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.97),
              borderRadius: BorderRadius.circular(38),
              border: Border.all(
                color: Colors.white,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 28,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(38),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildNavItem(
                    index: 0,
                    label: 'Descubrir',
                    inactiveIcon: Icons.explore_outlined,
                    activeIcon: Icons.explore_rounded,
                  ),
                  _buildNavItem(
                    index: 1,
                    label: 'Citas',
                    inactiveIcon: Icons.favorite_outline,
                    activeIcon: Icons.favorite,
                    badgeCount: _pendingInvitationsCount,
                  ),
                  _buildNavItem(
                    index: 2,
                    label: 'Reservas',
                    inactiveIcon: Icons.calendar_month_outlined,
                    activeIcon: Icons.calendar_month_rounded,
                    badgeCount: _pendingRequestsCount,
                  ),
                  _buildProfileNavItem(3, 'Perfil'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData inactiveIcon,
    required IconData activeIcon,
    int? badgeCount,
  }) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 8 : 4,
            vertical: isSelected ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF1F4F9) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    width: isSelected ? 32 : 25,
                    height: isSelected ? 32 : 25,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [AppColors.primary, Color(0xFFFF5252)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.38),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isSelected ? activeIcon : inactiveIcon,
                      size: isSelected ? 18 : 22,
                      color: isSelected ? Colors.white : const Color(0xFF262C36),
                    ),
                  ),
                  if (badgeCount != null && badgeCount > 0)
                    Positioned(
                      top: isSelected ? -3 : -5,
                      right: isSelected ? -7 : -9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF3B30),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF3B30).withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : const Color(0xFF262C36),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileNavItem(int index, String label) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onItemTapped(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isSelected ? 8 : 4,
            vertical: isSelected ? 4 : 6,
          ),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF1F4F9) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: EdgeInsets.all(isSelected ? 1.5 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: AppColors.primary, width: 2)
                          : Border.all(color: Colors.transparent, width: 0),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.32),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: CircleAvatar(
                      radius: isSelected ? 13.5 : 12,
                      backgroundColor: const Color(0xFFE2E6EE),
                      backgroundImage: (_userPhotoUrl != null && _userPhotoUrl!.isNotEmpty)
                          ? NetworkImage(_userPhotoUrl!)
                          : null,
                      child: (_userPhotoUrl == null || _userPhotoUrl!.isEmpty)
                          ? const Icon(Icons.person, size: 16, color: Color(0xFF555E6D))
                          : null,
                    ),
                  ),
                  // Punto indicador de perfil/estado
                  Positioned(
                    top: isSelected ? -2 : -1,
                    right: isSelected ? -2 : -1,
                    child: Container(
                      width: 8.5,
                      height: 8.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFB300),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppColors.primary : const Color(0xFF262C36),
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
