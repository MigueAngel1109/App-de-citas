import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import '../utils/session_manager.dart';
import 'login_page.dart';
import 'profile_setup_page.dart';
import 'subscription_plans_page.dart';
import '../widgets/almona_title.dart';

class MyProfilePage extends StatelessWidget {
  const MyProfilePage({super.key});

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _cerrarSesion(BuildContext context) async {
    await SessionManager.clearSession();
    await FirebaseAuth.instance.signOut();
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('No hay usuario activo')));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const AlmonaTitle(),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFF7A00), size: 28),
            tooltip: 'Planes Almona Pro',
            onPressed: () => SubscriptionPlansPage.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.edit_note, color: AppColors.primary, size: 28),
            tooltip: 'Editar Perfil',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const ProfileSetupPage(isEditMode: true)),
              );
            },
          ),
        ],
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          
          final data = snapshot.data?.data() as Map<String, dynamic>?;
          if (data == null) {
            return const Center(child: Text('No se encontraron datos del perfil'));
          }

          final name = data['name'] ?? 'Usuario';
          final birthDate = data['birthDate'] != null ? (data['birthDate'] as Timestamp).toDate() : null;
          final age = birthDate != null ? _calculateAge(birthDate) : '?';
          final bio = data['bio'] ?? '';

          // Ocupación y escuela
          final work = data['work'] ?? '';
          final school = data['school'] ?? '';

          // Redes
          final instagramHandle = data['instagramHandle'] ?? '';
          final city = data['city']?.toString();
          final interests = (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

          // Estilo de vida
          final lifestyle = data['lifestyle'] as Map<String, dynamic>? ?? {};
          final pets = lifestyle['pets'];
          final drinking = lifestyle['drinking'];
          final smokingTobacco = lifestyle['smokingTobacco'];
          final smokingCannabis = lifestyle['smokingCannabis'];
          final workout = lifestyle['workout'];
          final sleepPattern = lifestyle['sleepPattern'];

          // Información personal
          final personal = data['personal'] as Map<String, dynamic>? ?? {};
          final zodiac = personal['zodiac'];
          final mbti = personal['mbti'] ?? data['mbti'];
          final education = personal['education'];
          final loveLanguage = personal['loveLanguage'];
          final familyPlans = personal['familyPlans'];
          final communication = personal['communication'];
          final languages = (personal['languages'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

          // Fotos
          final List<dynamic> rawPhotos = (data['photoUrls'] as List?) ?? (data['photos'] as List?) ?? [];
          final List<String> photoUrls = rawPhotos
              .map((e) => e.toString().trim())
              .where((u) => u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('blob:')))
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Nombre, edad, verificación y @instagram en la cabecera
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
                    if (data['plan'] == 'pro')
                      _buildPlanBadge('PRO', const [Color(0xFFFF7A00), Color(0xFFFF007A)], Icons.workspace_premium_rounded)
                    else if (data['plan'] == 'pro_plus')
                      _buildPlanBadge('PRO+', const [Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFD946EF)], Icons.diamond_rounded),
                    if (instagramHandle.isNotEmpty)
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse('https://instagram.com/$instagramHandle');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
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

                // Solo Ciudad visible en cabecera
                if (city != null && city.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildTagBadge('📍 $city', isHighlight: true),
                    ],
                  ),
                  const SizedBox(height: 16),
                ] else
                  const SizedBox(height: 12),

                // Carrusel deslizable de fotos de perfil (Swipe / Tinder style)
                if (photoUrls.isNotEmpty)
                  _ProfilePhotoCarousel(photoUrls: photoUrls)
                else
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.inputBorder),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.add_a_photo_outlined, size: 48, color: AppColors.primary),
                        const SizedBox(height: 12),
                        const Text(
                          'Aún no tienes fotos de perfil',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Sube tus mejores fotos para que las personas puedan reconocerte en tus reservas.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (context) => const ProfileSetupPage(isEditMode: true)),
                            );
                          },
                          icon: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                          label: const Text('Subir Fotos Ahora', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          ),
                        ),
                      ],
                    ),
                  ),

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
                          const Icon(Icons.psychology_outlined, color: AppColors.primary, size: 22),
                          const SizedBox(width: 10),
                          const Text('Personalidad MBTI: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              mbti != null && mbti.toString().isNotEmpty ? mbti.toString() : 'No especificado',
                              style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 3. Lenguajes del Amor
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.favorite_outline_rounded, color: Colors.pinkAccent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Lenguajes del Amor:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                                const SizedBox(height: 4),
                                Text(
                                  loveLanguage != null && loveLanguage.toString().isNotEmpty ? loveLanguage.toString() : 'No especificado',
                                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 4. Signo Zodiacal
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.auto_awesome_outlined, color: Colors.amber, size: 22),
                          const SizedBox(width: 10),
                          const Text('Signo Zodiacal: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                          const SizedBox(width: 6),
                          Text(
                            zodiac != null && zodiac.toString().isNotEmpty ? zodiac.toString() : 'No especificado',
                            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

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
                  _buildInfoCard(
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: interests.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.inputBorder),
                          ),
                          child: Text(tag, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Estilo de Vida y Hábitos
                _buildSectionHeader('Estilo de vida'),
                _buildInfoCard(
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (pets != null) _buildTagBadge('🐾 $pets'),
                      if (drinking != null) _buildTagBadge('🍷 $drinking'),
                      if (smokingTobacco != null) _buildTagBadge('🚬 $smokingTobacco'),
                      if (smokingCannabis != null) _buildTagBadge('🌿 Cannabis: $smokingCannabis'),
                      if (workout != null) _buildTagBadge('💪 $workout'),
                      if (sleepPattern != null) _buildTagBadge('⏰ $sleepPattern'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Más detalles (Educación, Familia, Comunicación, Idiomas)
                _buildSectionHeader('Más sobre mí'),
                _buildInfoCard(
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (education != null) _buildTagBadge('🎓 $education'),
                      if (familyPlans != null) _buildTagBadge('👶 $familyPlans'),
                      if (communication != null) _buildTagBadge('💬 $communication'),
                      if (languages.isNotEmpty) _buildTagBadge('🗣️ ${languages.join(', ')}'),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                const SizedBox(height: 10),

                // Planes Almona Pro & Pro+ (Elegante y alineado con las tarjetas del perfil)
                _buildInfoCard(
                  InkWell(
                    onTap: () => SubscriptionPlansPage.show(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF7A00), Color(0xFFFF007A)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.workspace_premium, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['plan'] == 'pro'
                                      ? 'Mi suscripción: Almona Pro'
                                      : (data['plan'] == 'pro_plus' ? 'Mi suscripción: Almona Pro+' : 'Planes Almona Pro & Pro+'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data['plan'] == 'pro' || data['plan'] == 'pro_plus'
                                      ? 'Toca para ver beneficios o cambiar de plan'
                                      : 'Conoce los planes y ventajas exclusivas',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Botón Cerrar Sesión
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: () => _cerrarSesion(context),
                    icon: const Icon(Icons.logout, size: 20),
                    label: const Text('Cerrar Sesión', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                ),
                const SizedBox(height: 90),
              ],
            ),
          );
        },
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isHighlight ? AppColors.primary.withOpacity(0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlight ? AppColors.primary.withOpacity(0.3) : AppColors.inputBorder,
          width: isHighlight ? 1.2 : 1.0,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isHighlight ? AppColors.primary : AppColors.textPrimary,
          fontWeight: isHighlight ? FontWeight.bold : FontWeight.w500,
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

  Widget _buildPlanBadge(String label, List<Color> gradient, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 13),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Carrusel deslizador de fotos de perfil (Tinder / Bumble style)
class _ProfilePhotoCarousel extends StatefulWidget {
  final List<String> photoUrls;
  const _ProfilePhotoCarousel({required this.photoUrls});

  @override
  State<_ProfilePhotoCarousel> createState() => _ProfilePhotoCarouselState();
}

class _ProfilePhotoCarouselState extends State<_ProfilePhotoCarousel> {
  int _currentIndex = 0;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index >= 0 && index < widget.photoUrls.length) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photoUrls.isEmpty) return const SizedBox.shrink();

    final count = widget.photoUrls.length;

    return Container(
      height: 410,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // PageView deslizable horizontalmente
            PageView.builder(
              controller: _pageController,
              itemCount: count,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return Image.network(
                  widget.photoUrls[index],
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: AppColors.surface,
                      child: const Center(
                        child: CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1E1E1E),
                    child: const Center(
                      child: Icon(Icons.broken_image, size: 50, color: Colors.white54),
                    ),
                  ),
                );
              },
            ),

            // Sombra degradada superior para legibilidad de barras indicadoras
            if (count > 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 55,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.45),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            // Barras estilo historias / Tinder en la parte superior
            if (count > 1)
              Positioned(
                top: 12,
                left: 12,
                right: 12,
                child: Row(
                  children: List.generate(count, (i) {
                    final isCurrent = i == _currentIndex;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _goTo(i),
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2.5),
                          decoration: BoxDecoration(
                            color: isCurrent ? Colors.white : Colors.white.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

            // Contador de fotos (ej: 1 / 4) abajo a la derecha
            if (count > 1)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / $count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),

            // Botón flecha izquierda para cambiar foto fácilmente
            if (count > 1 && _currentIndex > 0)
              Positioned(
                left: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _goTo(_currentIndex - 1),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_left, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
              ),

            // Botón flecha derecha para cambiar foto fácilmente
            if (count > 1 && _currentIndex < count - 1)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _goTo(_currentIndex + 1),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.chevron_right, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


