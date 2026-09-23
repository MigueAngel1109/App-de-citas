import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

/// Modal bottom sheet para visualizar el perfil completo de un usuario
class UserProfileModal extends StatelessWidget {
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

  int _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _openInstagram(String handle) async {
    final clean = handle.replaceAll('@', '').trim();
    if (clean.isEmpty) return;
    final uri = Uri.parse('https://instagram.com/$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.35,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              // Barra de arrastre superior para drag-to-dismiss
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

              // Cabecera limpia (sin etiqueta 'Perfil del solicitante')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      fallbackName != null && fallbackName!.isNotEmpty
                          ? 'Perfil de $fallbackName'
                          : 'Perfil',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 22),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),

              // Contenido con Future de Firestore
              Expanded(
                child: FutureBuilder<DocumentSnapshot>(
                  future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
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
            backgroundImage: (fallbackPhoto != null && fallbackPhoto!.isNotEmpty)
                ? NetworkImage(fallbackPhoto!)
                : null,
            child: (fallbackPhoto == null || fallbackPhoto!.isEmpty)
                ? const Icon(Icons.person, size: 50, color: AppColors.textLight)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            fallbackName ?? 'Usuario',
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

  Widget _buildFullProfile(BuildContext context, Map<String, dynamic> data, ScrollController scrollController) {
    final name = data['name'] ?? fallbackName ?? 'Usuario';
    final birthDate = data['birthDate'] != null ? (data['birthDate'] as Timestamp).toDate() : null;
    final age = birthDate != null ? _calculateAge(birthDate).toString() : '';
    final bio = data['bio'] ?? '';
    final gender = data['gender'] ?? '';
    final showGender = data['showGenderOnProfile'] ?? true;
    final sexualOrientation = (data['sexualOrientation'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final interestedIn = data['interestedIn'] ?? '';
    final relationshipGoal = data['relationshipGoal'] ?? '';
    final instagramHandle = (data['instagramHandle'] ?? '').toString().replaceAll('@', '').trim();

    final work = data['work'] ?? '';
    final school = data['school'] ?? '';
    final interests = (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final lifestyle = data['lifestyle'] as Map<String, dynamic>? ?? {};
    final personal = data['personal'] as Map<String, dynamic>? ?? {};
    final mbti = personal['mbti'] ?? data['mbti'];

    // Fotos
    final List<dynamic> rawPhotos = (data['photoUrls'] as List?) ?? (data['photos'] as List?) ?? [];
    final List<String> photoUrls = rawPhotos
        .map((e) => e.toString().trim())
        .where((u) => u.isNotEmpty && (u.startsWith('http://') || u.startsWith('https://')))
        .toList();

    if (photoUrls.isEmpty && fallbackPhoto != null && fallbackPhoto!.isNotEmpty) {
      photoUrls.add(fallbackPhoto!);
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Galería de fotos
        if (photoUrls.isNotEmpty)
          SizedBox(
            height: 300,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: photoUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                return ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    photoUrls[i],
                    width: 220,
                    height: 300,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 220,
                      height: 300,
                      color: AppColors.surface,
                      child: const Icon(Icons.person, size: 60, color: AppColors.textLight),
                    ),
                  ),
                );
              },
            ),
          )
        else
          Center(
            child: CircleAvatar(
              radius: 54,
              backgroundColor: AppColors.surface,
              child: const Icon(Icons.person, size: 54, color: AppColors.textLight),
            ),
          ),

        const SizedBox(height: 18),

        // 1. Cabecera: Nombre, Edad y @instagram en la MISMA línea
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      age.isNotEmpty ? '$name, $age' : name,
                      style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: Colors.blueAccent, size: 20),
                ],
              ),
            ),
            if (instagramHandle.isNotEmpty) ...[
              const SizedBox(width: 8),
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
                      const Icon(Icons.camera_alt_outlined, size: 14, color: Color(0xFFE1306C)),
                      const SizedBox(width: 4),
                      Text(
                        '@$instagramHandle',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE1306C)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),

        // Badges de género / orientación
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            if (showGender && gender.isNotEmpty)
              _buildMiniBadge(Icons.person_outline, gender),
            ...sexualOrientation.map((ori) => _buildMiniBadge(Icons.favorite_border, ori)),
            if (interestedIn.isNotEmpty)
              _buildMiniBadge(Icons.visibility_outlined, 'Busca: $interestedIn'),
          ],
        ),

        // Intención de relación
        if (relationshipGoal.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
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
                      const Text('OBJETIVO EN LA APP', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.8)),
                      Text(relationshipGoal, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],

        // 2. Descripción / Bio
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionTitle('Biografía'),
          _buildCard(Text(bio, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4))),
        ],

        // 3. Sección "Sobre mí" en formato listado vertical (Ocupación, MBTI, etc.)
        const SizedBox(height: 18),
        _buildSectionTitle('Sobre mí'),
        _buildCard(
          Column(
            children: [
              if (work.isNotEmpty)
                _buildRow(Icons.work_outline, 'Ocupación: $work'),
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

        // 4. Burbujas/Chips: Primero Intereses / Pasiones
        if (interests.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionTitle('Intereses y Pasiones'),
          _buildCard(
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: interests.map((tag) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.inputBorder),
                ),
                child: Text(tag, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 12)),
              )).toList(),
            ),
          ),
        ],

        // 5. Al final: Estilo de Vida y Hábitos
        if (lifestyle.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionTitle('Estilo de Vida y Hábitos'),
          _buildCard(
            Column(
              children: [
                if (lifestyle['pets'] != null) _buildRow(Icons.pets, 'Mascotas: ${lifestyle['pets']}'),
                if (lifestyle['drinking'] != null) ...[const Divider(height: 12), _buildRow(Icons.local_bar, 'Bebidas: ${lifestyle['drinking']}')],
                if (lifestyle['workout'] != null) ...[const Divider(height: 12), _buildRow(Icons.fitness_center, 'Ejercicio: ${lifestyle['workout']}')],
                if (lifestyle['smokingTobacco'] != null) ...[const Divider(height: 12), _buildRow(Icons.smoking_rooms, 'Tabaco: ${lifestyle['smokingTobacco']}')],
                if (lifestyle['smokingCannabis'] != null) ...[const Divider(height: 12), _buildRow(Icons.eco_outlined, 'Cannabis: ${lifestyle['smokingCannabis']}')],
                if (lifestyle['sleepPattern'] != null) ...[const Divider(height: 12), _buildRow(Icons.bedtime_outlined, 'Sueño: ${lifestyle['sleepPattern']}')],
              ],
            ),
          ),
        ],

        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
      ),
    );
  }

  Widget _buildCard(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
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
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
