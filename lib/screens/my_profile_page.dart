import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import 'login_page.dart';
import 'profile_setup_page.dart';

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
        title: const Text('Mi Perfil', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
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
          final gender = data['gender'] ?? '';
          final showGender = data['showGenderOnProfile'] ?? true;
          final sexualOrientation = (data['sexualOrientation'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
          final interestedIn = data['interestedIn'] ?? '';
          final relationshipGoal = data['relationshipGoal'] ?? '';

          // Ocupación y escuela
          final work = data['work'] ?? '';
          final school = data['school'] ?? '';

          // Redes y multimedia
          final spotifyTrack = data['spotifyTrack'] ?? '';
          final instagramHandle = data['instagramHandle'] ?? '';
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
                // Galería / Carrusel de fotos
                if (photoUrls.isNotEmpty)
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: photoUrls.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final currentUrl = photoUrls[i];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Stack(
                            children: [
                              Image.network(
                                currentUrl,
                                width: 240,
                                height: 320,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    width: 240,
                                    height: 320,
                                    color: AppColors.surface,
                                    child: const Center(
                                      child: CircularProgressIndicator(color: AppColors.primary),
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 240,
                                    height: 320,
                                    color: AppColors.surface,
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.broken_image, size: 40, color: AppColors.textLight),
                                        const SizedBox(height: 8),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 16),
                                          child: Text(
                                            'Error al cargar imagen',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        TextButton.icon(
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              MaterialPageRoute(builder: (context) => const ProfileSetupPage(isEditMode: true)),
                                            );
                                          },
                                          icon: const Icon(Icons.refresh, size: 16, color: AppColors.primary),
                                          label: const Text('Actualizar foto', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                              if (i == 0)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.6),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text('Principal', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
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

                const SizedBox(height: 20),

                // Nombre, edad y verificación
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$name, $age',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.verified, color: Colors.blueAccent, size: 24),
                  ],
                ),
                const SizedBox(height: 8),

                // Etiquetas de Género y Orientación
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (showGender && gender.isNotEmpty)
                      _buildTagBadge(gender),
                    ...sexualOrientation.map((o) => _buildTagBadge(o)),
                    if (interestedIn.isNotEmpty)
                      _buildTagBadge('Busca: $interestedIn'),
                  ],
                ),
                const SizedBox(height: 20),

                // Objetivo de relación
                if (relationshipGoal.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: AppColors.primary, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BUSCANDO EN LA APP', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 1)),
                              const SizedBox(height: 2),
                              Text(relationshipGoal, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Sobre mí (Bio)
                if (bio.isNotEmpty) ...[
                  _buildSectionHeader('Sobre mí'),
                  _buildInfoCard(
                    Text(bio, style: const TextStyle(fontSize: 15, color: AppColors.textPrimary, height: 1.4)),
                  ),
                  const SizedBox(height: 20),
                ],

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
                  const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                ],

                // Estilo de Vida y Hábitos (sin dieta)
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
                const SizedBox(height: 20),

                // Información Personal y Antecedentes (con MBTI)
                _buildSectionHeader('Más sobre mí'),
                _buildInfoCard(
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (mbti != null) _buildTagBadge('🧠 MBTI: $mbti'),
                      if (zodiac != null) _buildTagBadge('⭐ $zodiac'),
                      if (education != null) _buildTagBadge('🎓 $education'),
                      if (loveLanguage != null) _buildTagBadge('💖 $loveLanguage'),
                      if (familyPlans != null) _buildTagBadge('👶 $familyPlans'),
                      if (communication != null) _buildTagBadge('💬 $communication'),
                      if (languages.isNotEmpty) _buildTagBadge('🗣️ ${languages.join(', ')}'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Redes: Spotify e Instagram
                if (spotifyTrack.isNotEmpty || instagramHandle.isNotEmpty) ...[
                  _buildSectionHeader('Música y Redes'),
                  _buildInfoCard(
                    Column(
                      children: [
                        if (spotifyTrack.isNotEmpty)
                          _buildListTileInfo(Icons.music_note, 'Himno: $spotifyTrack', iconColor: Colors.green),
                        if (spotifyTrack.isNotEmpty && instagramHandle.isNotEmpty) const Divider(height: 16),
                        if (instagramHandle.isNotEmpty)
                          InkWell(
                            onTap: () async {
                              final uri = Uri.parse('https://instagram.com/$instagramHandle');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: _buildListTileInfo(
                              Icons.camera_alt_outlined,
                              '@$instagramHandle en Instagram',
                              iconColor: const Color(0xFFE1306C),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textLight),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

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

  Widget _buildTagBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildListTileInfo(IconData icon, String text, {Color? iconColor, Widget? trailing}) {
    return Row(
      children: [
        Icon(icon, color: iconColor ?? AppColors.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
        ),
        if (trailing != null) trailing,
      ],
    );
  }
}
