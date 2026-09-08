import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_colors.dart';

/// Modal bottom sheet para visualizar el perfil completo de un usuario (solicitante)
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

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
              // Barra de arrastre superior
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Cabecera con botón de cerrar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Perfil del Solicitante',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textPrimary),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),

              // Contenido con Stream/Future de Firestore
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

    final work = data['work'] ?? '';
    final school = data['school'] ?? '';
    final interests = (data['interests'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];

    final lifestyle = data['lifestyle'] as Map<String, dynamic>? ?? {};
    final personal = data['personal'] as Map<String, dynamic>? ?? {};

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

        // Nombre y edad
        Row(
          children: [
            Expanded(
              child: Text(
                age.isNotEmpty ? '$name, $age' : name,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
            ),
            const Icon(Icons.verified, color: Colors.blueAccent, size: 22),
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

        // Biografía
        if (bio.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionTitle('Sobre mí'),
          _buildCard(Text(bio, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.4))),
        ],

        // Trabajo y Escuela
        if (work.isNotEmpty || school.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionTitle('Ocupación'),
          _buildCard(
            Column(
              children: [
                if (work.isNotEmpty) _buildRow(Icons.work_outline, work),
                if (work.isNotEmpty && school.isNotEmpty) const Divider(height: 14),
                if (school.isNotEmpty) _buildRow(Icons.school_outlined, school),
              ],
            ),
          ),
        ],

        // Intereses
        if (interests.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionTitle('Intereses'),
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
        ],

        // Estilo de vida
        if (lifestyle.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionTitle('Estilo de Vida'),
          _buildCard(
            Column(
              children: [
                if (lifestyle['pets'] != null) _buildRow(Icons.pets, 'Mascotas: ${lifestyle['pets']}'),
                if (lifestyle['drinking'] != null) ...[const Divider(height: 12), _buildRow(Icons.local_bar, 'Bebidas: ${lifestyle['drinking']}')],
                if (lifestyle['workout'] != null) ...[const Divider(height: 12), _buildRow(Icons.fitness_center, 'Ejercicio: ${lifestyle['workout']}')],
                if (lifestyle['diet'] != null) ...[const Divider(height: 12), _buildRow(Icons.restaurant, 'Dieta: ${lifestyle['diet']}')],
              ],
            ),
          ),
        ],

        // Información Personal
        if (personal.isNotEmpty) ...[
          const SizedBox(height: 18),
          _buildSectionTitle('Más sobre mí'),
          _buildCard(
            Column(
              children: [
                if (personal['zodiac'] != null) _buildRow(Icons.nights_stay, 'Signo: ${personal['zodiac']}'),
                if (personal['education'] != null) ...[const Divider(height: 12), _buildRow(Icons.menu_book, 'Educación: ${personal['education']}')],
                if (personal['loveLanguage'] != null) ...[const Divider(height: 12), _buildRow(Icons.favorite, 'Lenguaje del amor: ${personal['loveLanguage']}')],
              ],
            ),
          ),
        ],

        const SizedBox(height: 30),
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
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
        ),
      ],
    );
  }

  Widget _buildMiniBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
