import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

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
  // CONTENIDO DEL PERFIL (Idéntico a Mi Perfil)
  // -------------------------------------------------------------
  Widget _buildFullProfile(BuildContext context, Map<String, dynamic> data, ScrollController scrollController) {
    final name = data['name'] ?? widget.fallbackName ?? 'Usuario';
    final ageVal = _calculateAge(data['birthDate']);
    final age = ageVal > 0 ? ageVal.toString() : '?';
    final bio = (data['bio'] ?? '').toString().trim();

    // Ocupación y escuela
    final work = (data['work'] ?? '').toString().trim();
    final school = (data['school'] ?? data['education'] ?? '').toString().trim();

    // Redes y ubicación
    final instagramHandle = (data['instagramHandle'] ?? '').toString().replaceAll('@', '').trim();
    final city = data['city']?.toString();
    final interests =
        (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

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

    // Lista de fotos válidas
    final rawPhotos = (data['photoUrls'] as List?) ?? (data['photos'] as List?) ?? [];
    final List<String> photoUrls = rawPhotos
        .map((e) => e.toString().trim())
        .where((u) => u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://') || u.startsWith('blob:')))
        .toList();

    if (photoUrls.isEmpty && widget.fallbackPhoto != null && widget.fallbackPhoto!.isNotEmpty) {
      photoUrls.add(widget.fallbackPhoto!);
    }

    return SingleChildScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
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

          // FOTO 1 (Principal)
          if (photoUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[0]),
            ),

          // =========================================================
          // SECCIÓN "SOBRE MÍ":
          // =========================================================
          _buildSectionHeader('Sobre mí'),
          _buildInfoCard(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

          // FOTO 3
          if (photoUrls.length > 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[2]),
            ),

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

          // FOTO 4
          if (photoUrls.length > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[3]),
            ),

          // Más detalles
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

          // FOTOS RESTANTES
          for (int i = 4; i < photoUrls.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: _buildContinuousPhoto(photoUrls[i]),
            ),

          const SizedBox(height: 30),
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

  Widget _buildContinuousPhoto(String url) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        height: 380,
        width: double.infinity,
        color: const Color(0xFF1E1E1E),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: AppColors.surface,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
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
}
