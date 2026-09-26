import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import 'instagram_icon.dart';

/// Modal bottom sheet para visualizar el perfil completo de un usuario
/// con el diseño moderno, interactivo y detallado de "Descubrir Personas"
class UserProfileModal extends StatefulWidget {
  final String userId;
  final String? fallbackName;
  final String? fallbackPhoto;

  const UserProfileModal({
    super.key,
    required this.userId,
    this.fallbackName,
    this.fallbackPhoto,
  });

  static Future<void> show(BuildContext context, {required String userId, String? name, String? photo}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserProfileModal(
        userId: userId,
        fallbackName: name,
        fallbackPhoto: photo,
      ),
    );
  }

  @override
  State<UserProfileModal> createState() => _UserProfileModalState();
}

class _UserProfileModalState extends State<UserProfileModal> {
  int _currentPhotoIndex = 0;
  final PageController _photoPageController = PageController();

  @override
  void dispose() {
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
    } else if (birthDate is String) {
      final parsed = DateTime.tryParse(birthDate);
      if (parsed == null) return 0;
      dt = parsed;
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.45,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 24,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Barra de arrastre superior
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),

              // Cabecera limpia con botón de cierre
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.fallbackName != null && widget.fallbackName!.isNotEmpty
                          ? 'Perfil de ${widget.fallbackName}'
                          : 'Perfil',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: Color(0xFF334155)),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),

              // Contenido con Future de Firestore
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(widget.userId).get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
                    }

                    if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.exists) {
                      return _buildFallbackView(scrollController);
                    }

                    final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
                    return _buildFullProfile(context, data, scrollController);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFallbackView(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.surface,
            backgroundImage: (widget.fallbackPhoto != null && widget.fallbackPhoto!.isNotEmpty)
                ? NetworkImage(widget.fallbackPhoto!)
                : null,
            child: (widget.fallbackPhoto == null || widget.fallbackPhoto!.isEmpty)
                ? const Icon(Icons.person, size: 50, color: AppColors.textLight)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            widget.fallbackName ?? 'Usuario',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: const Text(
            'No hay más detalles públicos disponibles en este perfil.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // CONTENIDO DEL PERFIL (Estilo Descubrir Personas)
  // -------------------------------------------------------------
  Widget _buildFullProfile(BuildContext context, Map<String, dynamic> data, ScrollController scrollController) {
    final name = data['name'] ?? widget.fallbackName ?? 'Usuario';
    final age = _calculateAge(data['birthDate']);
    final bio = (data['bio'] ?? '').toString().trim();
    final gender = (data['gender'] ?? '').toString();
    final showGender = data['showGenderOnProfile'] ?? true;
    final sexualOrientation =
        (data['sexualOrientation'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final relationshipGoal = (data['relationshipGoal'] ?? '').toString();
    final instagramHandle = (data['instagramHandle'] ?? '').toString().replaceAll('@', '').trim();

    final work = (data['work'] ?? '').toString().trim();
    final school = (data['school'] ?? data['education'] ?? '').toString().trim();
    final interests =
        (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final lifestyle = data['lifestyle'] as Map<String, dynamic>? ?? {};
    final personal = data['personal'] as Map<String, dynamic>? ?? {};
    final mbti = personal['mbti'] ?? data['mbti'];

    // Lista de fotos válidas
    final rawPhotos = (data['photoUrls'] as List?) ?? (data['photos'] as List?) ?? [];
    final List<String> photos = rawPhotos
        .map((e) => e.toString().trim())
        .where((u) => u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://')))
        .toList();

    if (photos.isEmpty && widget.fallbackPhoto != null && widget.fallbackPhoto!.isNotEmpty) {
      photos.add(widget.fallbackPhoto!);
    }

    return SingleChildScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. FOTO PRINCIPAL CON CARRUSEL INTERACTIVO Y STORY BARS
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
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

                    // Badge "ACTIVO RECIENTE"
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

          // 3. OBJETIVO EN LA APP
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

          // 4. BIOGRAFÍA
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

          // 5. DESEOS / INTERESES (Burbujas elegantes estilo Feeld/Hinge)
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
                          color: const Color(0xFFECEFF5),
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

          // 6. SOBRE MÍ
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

          // 7. ESTILO DE VIDA Y HÁBITOS
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
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // FOTO PRINCIPAL CON CARRUSEL Y STORY BARS
  // -------------------------------------------------------------
  Widget _buildMainPhotoCard(List<String> photos, String name) {
    final photoHeight = MediaQuery.of(context).size.height * 0.50;

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
