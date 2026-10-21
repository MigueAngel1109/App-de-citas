import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/app_colors.dart';
import '../utils/zone_data.dart';
import '../screens/subscription_plans_page.dart';

/// Modelo de datos para gestionar los Filtros Básicos y Avanzados
class DiscoveryFilters {
  // ---------------------------------------------------------------------------
  // FILTROS BÁSICOS (Disponibles para usuarios con cuenta Gratuita y Pro)
  // ---------------------------------------------------------------------------
  String interestedIn; // 'Todos', 'Mujeres', 'Hombres'
  RangeValues ageRange; // Rango de edad (ej. 18 a 50)
  Set<String> selectedZones; // Zonas de la ciudad

  // ---------------------------------------------------------------------------
  // FILTROS AVANZADOS (Exclusivos para Almona Pro y Almona Pro+)
  // ---------------------------------------------------------------------------
  Set<String> zodiacSigns; // 'Aries ♈', etc.
  Set<String> mbti; // 'INTJ', 'ENFP', etc.
  Set<String> loveLanguages; // 'Palabras de afirmación 💬', etc.
  String? pets; // 'Con mascotas', 'Sin mascotas' o null
  String? drinking; // 'No bebe', 'Social' o null
  String? smoking; // 'No fuma' o null
  String? workout; // 'Regular / Diario' o null
  bool onlyWithPrompts; // Solo personas con preguntas respondidas
  bool onlyVerified; // Solo perfiles verificados / VIP
  Set<String> planTypes; // 'Cena', 'Tragos', 'Café', 'Fiesta'
  Set<String> paymentTypes; // '50/50', 'Invito yo', 'Invita la otra persona'

  DiscoveryFilters({
    this.interestedIn = 'Todos',
    this.ageRange = const RangeValues(18, 55),
    Set<String>? selectedZones,
    Set<String>? zodiacSigns,
    Set<String>? mbti,
    Set<String>? loveLanguages,
    this.pets,
    this.drinking,
    this.smoking,
    this.workout,
    this.onlyWithPrompts = false,
    this.onlyVerified = false,
    Set<String>? planTypes,
    Set<String>? paymentTypes,
  })  : selectedZones = selectedZones ?? {},
        zodiacSigns = zodiacSigns ?? {},
        mbti = mbti ?? {},
        loveLanguages = loveLanguages ?? {},
        planTypes = planTypes ?? {},
        paymentTypes = paymentTypes ?? {};

  /// Clona los filtros actuales para editar de forma temporal antes de aplicar
  DiscoveryFilters clone() {
    return DiscoveryFilters(
      interestedIn: interestedIn,
      ageRange: ageRange,
      selectedZones: Set.from(selectedZones),
      zodiacSigns: Set.from(zodiacSigns),
      mbti: Set.from(mbti),
      loveLanguages: Set.from(loveLanguages),
      pets: pets,
      drinking: drinking,
      smoking: smoking,
      workout: workout,
      onlyWithPrompts: onlyWithPrompts,
      onlyVerified: onlyVerified,
      planTypes: Set.from(planTypes),
      paymentTypes: Set.from(paymentTypes),
    );
  }

  /// Restablece todos los filtros a sus valores predeterminados
  void reset({String defaultInterestedIn = 'Todos', Set<String>? defaultZones}) {
    interestedIn = defaultInterestedIn;
    ageRange = const RangeValues(18, 55);
    selectedZones = defaultZones != null ? Set.from(defaultZones) : {};
    zodiacSigns.clear();
    mbti.clear();
    loveLanguages.clear();
    pets = null;
    drinking = null;
    smoking = null;
    workout = null;
    onlyWithPrompts = false;
    onlyVerified = false;
    planTypes.clear();
    paymentTypes.clear();
  }

  /// Cuenta cuántos filtros están activos
  int activeFilterCount({required bool isPro}) {
    int count = 0;
    if (interestedIn != 'Todos') count++;
    if (ageRange.start.round() > 18 || ageRange.end.round() < 55) count++;
    if (selectedZones.isNotEmpty) count++;

    if (isPro) {
      if (zodiacSigns.isNotEmpty) count++;
      if (mbti.isNotEmpty) count++;
      if (loveLanguages.isNotEmpty) count++;
      if (pets != null) count++;
      if (drinking != null) count++;
      if (smoking != null) count++;
      if (workout != null) count++;
      if (onlyWithPrompts) count++;
      if (onlyVerified) count++;
      if (planTypes.isNotEmpty) count++;
      if (paymentTypes.isNotEmpty) count++;
    }
    return count;
  }

  bool hasActiveFilters({required bool isPro}) => activeFilterCount(isPro: isPro) > 0;

  // ---------------------------------------------------------------------------
  // EVALUACIÓN DE CANDIDATOS (Descubrir Personas)
  // ---------------------------------------------------------------------------
  bool matchesCandidate(Map<String, dynamic> c, {required bool isPro}) {
    // 1. Género (Básico)
    final gender = (c['gender'] ?? '').toString().toLowerCase();
    final pref = interestedIn.toLowerCase();
    if (pref.contains('mujer') && !gender.contains('mujer')) return false;
    if (pref.contains('hombre') && !gender.contains('hombre')) return false;

    // 2. Rango de Edad (Básico)
    final birthDate = c['birthDate'];
    if (birthDate != null) {
      final age = _calculateAge(birthDate);
      if (age > 0) {
        if (age < ageRange.start.round() || age > ageRange.end.round()) {
          return false;
        }
      }
    }

    // 3. Zonas Preferidas (Básico)
    if (selectedZones.isNotEmpty) {
      final candZonesRaw = c['preferredZones'];
      if (candZonesRaw is List && candZonesRaw.isNotEmpty) {
        final candZones = candZonesRaw.map((e) => e.toString()).toSet();
        if (candZones.intersection(selectedZones).isEmpty) {
          // Verificar si hay coincidencia normalizada
          bool zoneMatch = false;
          for (final sz in selectedZones) {
            final normSz = ZoneData.normalizeZoneName(sz);
            for (final cz in candZones) {
              if (ZoneData.normalizeZoneName(cz).contains(normSz) ||
                  normSz.contains(ZoneData.normalizeZoneName(cz))) {
                zoneMatch = true;
                break;
              }
            }
            if (zoneMatch) break;
          }
          if (!zoneMatch) return false;
        }
      }
    }

    // SI EL USUARIO NO TIENE PLAN PRO, LOS FILTROS AVANZADOS NO SE APLICAN
    if (!isPro) return true;

    // 4. Signo Zodiacal (Avanzado PRO)
    if (zodiacSigns.isNotEmpty) {
      final personal = c['personal'] as Map<String, dynamic>? ?? {};
      final z = (personal['zodiac'] ?? '').toString();
      if (z.isEmpty) return false;

      bool zMatch = false;
      for (final sign in zodiacSigns) {
        final baseName = sign.split(' ').first.toLowerCase();
        if (z.toLowerCase().contains(baseName)) {
          zMatch = true;
          break;
        }
      }
      if (!zMatch) return false;
    }

    // 5. Personalidad MBTI (Avanzado PRO)
    if (mbti.isNotEmpty) {
      final personal = c['personal'] as Map<String, dynamic>? ?? {};
      final rawMbti = personal['mbti'];
      Set<String> candMbti = {};
      if (rawMbti is List) {
        candMbti = rawMbti.map((e) => e.toString().toUpperCase()).toSet();
      } else if (rawMbti is String && rawMbti.isNotEmpty) {
        candMbti = {rawMbti.toUpperCase()};
      }
      if (candMbti.isEmpty) return false;

      final targetMbti = mbti.map((e) => e.toUpperCase()).toSet();
      if (candMbti.intersection(targetMbti).isEmpty) return false;
    }

    // 6. Lenguajes del Amor (Avanzado PRO)
    if (loveLanguages.isNotEmpty) {
      final personal = c['personal'] as Map<String, dynamic>? ?? {};
      final rawLove = personal['loveLanguage'] ?? personal['loveLanguages'];
      Set<String> candLove = {};
      if (rawLove is List) {
        candLove = rawLove.map((e) => e.toString()).toSet();
      } else if (rawLove is String && rawLove.isNotEmpty) {
        candLove = {rawLove};
      }
      if (candLove.isEmpty) return false;

      bool loveMatch = false;
      for (final target in loveLanguages) {
        final keyWord = target.split(' ').first.toLowerCase();
        for (final cl in candLove) {
          if (cl.toLowerCase().contains(keyWord)) {
            loveMatch = true;
            break;
          }
        }
        if (loveMatch) break;
      }
      if (!loveMatch) return false;
    }

    // 7. Estilo de Vida y Hábitos (Avanzado PRO)
    final lifestyle = c['lifestyle'] as Map<String, dynamic>? ?? {};

    if (pets != null) {
      final candPets = lifestyle['pets'];
      if (pets == 'Con mascotas') {
        if (candPets == null || (candPets is List && candPets.isEmpty) || candPets.toString().contains('Sin mascotas')) {
          return false;
        }
      } else if (pets == 'Sin mascotas') {
        if (candPets != null && !candPets.toString().contains('Sin mascotas')) {
          return false;
        }
      }
    }

    if (smoking != null) {
      final s = (lifestyle['smokingTobacco'] ?? '').toString().toLowerCase();
      if (smoking == 'No fuma' && s.isNotEmpty && !s.contains('no fumo')) {
        return false;
      }
    }

    if (drinking != null) {
      final d = (lifestyle['drinking'] ?? '').toString().toLowerCase();
      if (drinking == 'No bebe' && d.isNotEmpty && !d.contains('nunca') && !d.contains('sobrio')) {
        return false;
      }
    }

    if (workout != null) {
      final w = (lifestyle['workout'] ?? '').toString().toLowerCase();
      if (workout == 'Regular / Diario' && !w.contains('todos') && !w.contains('regular')) {
        return false;
      }
    }

    // 8. Solo perfiles con Prompts respondidos (Avanzado PRO)
    if (onlyWithPrompts) {
      final prompts = c['prompts'] as Map<String, dynamic>? ?? {};
      if (prompts.isEmpty) return false;
    }

    // 9. Solo perfiles Verificados / VIP (Avanzado PRO)
    if (onlyVerified) {
      final isVerified = c['isVerified'] == true;
      final plan = c['plan']?.toString().toLowerCase();
      final isVip = plan == 'pro' || plan == 'pro_plus' || c['subscription']?['isVIP'] == true;
      if (!isVerified && !isVip) return false;
    }

    return true;
  }

  // ---------------------------------------------------------------------------
  // EVALUACIÓN DE RESERVAS (Reservas en Mapa)
  // ---------------------------------------------------------------------------
  bool matchesReservation(
    Map<String, dynamic> data, {
    required LatLng latLng,
    required String hostGender,
    required int? hostAge,
    required String planType,
    required String paymentType,
    required bool isPro,
  }) {
    // 1. Género del anfitrión (Básico)
    final pref = interestedIn.toLowerCase();
    final hg = hostGender.toLowerCase();
    if (pref.contains('mujer') && !hg.contains('mujer')) return false;
    if (pref.contains('hombre') && !hg.contains('hombre')) return false;

    // 2. Edad del anfitrión (Básico)
    if (hostAge != null && hostAge > 0) {
      if (hostAge < ageRange.start.round() || hostAge > ageRange.end.round()) {
        return false;
      }
    }

    // 3. Zonas (Básico)
    if (selectedZones.isNotEmpty) {
      if (!ZoneData.isPointInAnyZone(latLng, selectedZones)) {
        final docZone = (data['zone'] ?? data['zoneName'])?.toString().trim();
        bool match = false;
        if (docZone != null && docZone.isNotEmpty) {
          final normDoc = ZoneData.normalizeZoneName(docZone);
          for (final sz in selectedZones) {
            if (ZoneData.normalizeZoneName(sz) == normDoc) {
              match = true;
              break;
            }
          }
        }
        if (!match) return false;
      }
    }

    // SI NO ES PRO, LOS FILTROS AVANZADOS NO SE APLICAN A RESERVAS
    if (!isPro) return true;

    // 4. Tipo de Plan (Avanzado PRO)
    if (planTypes.isNotEmpty) {
      final pt = planType.toLowerCase();
      bool pMatch = false;
      for (final target in planTypes) {
        if (pt.contains(target.toLowerCase())) {
          pMatch = true;
          break;
        }
      }
      if (!pMatch) return false;
    }

    // 5. Tipo de Pago (Avanzado PRO)
    if (paymentTypes.isNotEmpty) {
      final py = paymentType.toLowerCase();
      bool pyMatch = false;
      for (final target in paymentTypes) {
        if (py.contains(target.toLowerCase())) {
          pyMatch = true;
          break;
        }
      }
      if (!pyMatch) return false;
    }

    // 6. Solo Verificados / VIP (Avanzado PRO)
    if (onlyVerified) {
      final isVerified = data['isVerified'] == true;
      final plan = data['plan']?.toString().toLowerCase();
      final isVip = plan == 'pro' || plan == 'pro_plus' || data['isVIP'] == true;
      if (!isVerified && !isVip) return false;
    }

    return true;
  }

  static int _calculateAge(dynamic birthDate) {
    if (birthDate == null) return 0;
    DateTime dt;
    if (birthDate is DateTime) {
      dt = birthDate;
    } else {
      try {
        dt = birthDate.toDate();
      } catch (_) {
        return 0;
      }
    }
    final now = DateTime.now();
    int age = now.year - dt.year;
    if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) {
      age--;
    }
    return age;
  }
}

/// Modal Bottom Sheet moderno y estilizado para configurar Filtros Básicos y Avanzados
class DiscoveryFiltersModal extends StatefulWidget {
  final DiscoveryFilters initialFilters;
  final bool isPro;
  final ValueChanged<DiscoveryFilters> onApply;

  const DiscoveryFiltersModal({
    super.key,
    required this.initialFilters,
    required this.isPro,
    required this.onApply,
  });

  static Future<void> show({
    required BuildContext context,
    required DiscoveryFilters initialFilters,
    required bool isPro,
    required ValueChanged<DiscoveryFilters> onApply,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DiscoveryFiltersModal(
        initialFilters: initialFilters,
        isPro: isPro,
        onApply: onApply,
      ),
    );
  }

  @override
  State<DiscoveryFiltersModal> createState() => _DiscoveryFiltersModalState();
}

class _DiscoveryFiltersModalState extends State<DiscoveryFiltersModal> {
  late DiscoveryFilters _filters;

  // Catálogo de opciones para Bogotá
  final List<String> _availableZones = [
    'Chapinero Central',
    'Zona T / Retiro',
    'Parque de la 93',
    'Usaquén',
    'Galerías - Teusaquillo',
    'Centro Histórico',
    'Santa Bárbara',
    'Rosales / Bella Suiza',
  ];

  final List<String> _availableZodiacs = [
    'Aries ♈', 'Tauro ♉', 'Géminis ♊', 'Cáncer ♋',
    'Leo ♌', 'Virgo ♍', 'Libra ♎', 'Escorpio ♏',
    'Sagitario ♐', 'Capricornio ♑', 'Acuario ♒', 'Piscis ♓'
  ];

  final List<String> _availableMbti = [
    'INTJ', 'INTP', 'ENTJ', 'ENTP',
    'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
    'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];

  final List<String> _availableLoveLanguages = [
    'Palabras de afirmación 💬',
    'Tiempo de calidad ⏳',
    'Detalles y regalos 🎁',
    'Actos de servicio 🤝',
    'Contacto físico 🫂',
  ];

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters.clone();
  }

  void _promptProUpgrade(String featureName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF7A00), Color(0xFFFF007A)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Filtro Avanzado PRO',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El filtro "$featureName" es exclusivo de Almona Pro y Almona Pro+.',
              style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.4),
            ),
            const SizedBox(height: 10),
            Text(
              'Desbloquea compatibilidad astrológica, personalidad MBTI, estilo de vida y conexión directa con tus planes favoritos.',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.35),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Quizás luego', style: TextStyle(color: Colors.white.withOpacity(0.5))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              SubscriptionPlansPage.show(context, initialTier: SubscriptionTier.pro);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5E3A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('Ver Planes Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _filters.activeFilterCount(isPro: widget.isPro);
    final maxHeight = MediaQuery.of(context).size.height * 0.90;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Barra de arrastre superior
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 8),

          // Encabezado del modal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.tune_rounded, color: AppColors.primary, size: 24),
                const SizedBox(width: 10),
                const Text(
                  'Filtros de Búsqueda',
                  style: TextStyle(
                    fontSize: 18.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (activeCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$activeCount activo${activeCount > 1 ? 's' : ''}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _filters.reset();
                    });
                  },
                  child: const Text(
                    'Restablecer',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),

          // Contenido desplazable con las dos secciones: Básicos y Avanzados
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ===========================================================
                  // SECCIÓN 1: FILTROS BÁSICOS (Gratis)
                  // ===========================================================
                  _buildSectionHeader(
                    title: 'Filtros Básicos',
                    badgeText: 'Disponible para todos',
                    badgeColor: Colors.teal.shade700,
                    badgeBg: Colors.teal.withOpacity(0.1),
                    icon: Icons.check_circle_outline,
                  ),
                  const SizedBox(height: 14),

                  // 1. ¿A quién te interesa ver?
                  _buildSubheader('¿A quién te interesa conocer?'),
                  const SizedBox(height: 8),
                  _buildGenderSelector(),
                  const SizedBox(height: 20),

                  // 2. Rango de Edad
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSubheader('Rango de edad'),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_filters.ageRange.start.round()} - ${_filters.ageRange.end.round() >= 55 ? '55+' : '${_filters.ageRange.end.round()}'} años',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _filters.ageRange,
                    min: 18,
                    max: 55,
                    divisions: 37,
                    activeColor: AppColors.primary,
                    inactiveColor: Colors.black.withOpacity(0.08),
                    labels: RangeLabels(
                      '${_filters.ageRange.start.round()}',
                      '${_filters.ageRange.end.round() >= 55 ? '55+' : '${_filters.ageRange.end.round()}'}',
                    ),
                    onChanged: (values) {
                      setState(() {
                        _filters.ageRange = values;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // 3. Zonas de Bogotá
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSubheader('Zonas de Bogotá'),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            if (_filters.selectedZones.length == _availableZones.length) {
                              _filters.selectedZones.clear();
                            } else {
                              _filters.selectedZones = Set.from(_availableZones);
                            }
                          });
                        },
                        child: Text(
                          _filters.selectedZones.length == _availableZones.length
                              ? 'Deseleccionar todas'
                              : 'Todas las zonas',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _availableZones.map((zone) {
                      final isSelected = _filters.selectedZones.contains(zone);
                      return FilterChip(
                        label: Text(zone),
                        selected: isSelected,
                        selectedColor: AppColors.primary.withOpacity(0.15),
                        checkmarkColor: AppColors.primary,
                        labelStyle: TextStyle(
                          color: isSelected ? AppColors.primary : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        backgroundColor: Colors.black.withOpacity(0.04),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: BorderSide(
                            color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.08),
                          ),
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _filters.selectedZones.add(zone);
                            } else {
                              _filters.selectedZones.remove(zone);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // ===========================================================
                  // SECCIÓN 2: FILTROS AVANZADOS (Pro & Pro+)
                  // ===========================================================
                  _buildSectionHeader(
                    title: 'Filtros Avanzados',
                    badgeText: widget.isPro ? '✨ Desbloqueado PRO' : '🔒 Exclusivo PRO',
                    badgeColor: widget.isPro ? const Color(0xFF6C2BD9) : const Color(0xFFFF5E3A),
                    badgeBg: (widget.isPro ? const Color(0xFF6C2BD9) : const Color(0xFFFF5E3A)).withOpacity(0.12),
                    icon: widget.isPro ? Icons.diamond_rounded : Icons.lock_outline_rounded,
                  ),
                  const SizedBox(height: 10),

                  // Banner de estado PRO / Upgrade
                  _buildProBanner(),
                  const SizedBox(height: 18),

                  // 1. Signo Zodiacal
                  _buildAdvancedCategory(
                    title: 'Signo Zodiacal',
                    icon: Icons.auto_awesome,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableZodiacs.map((sign) {
                        final isSelected = _filters.zodiacSigns.contains(sign);
                        return _buildLockableChip(
                          label: sign,
                          isSelected: isSelected,
                          onTap: () {
                            if (!widget.isPro) {
                              _promptProUpgrade('Signo Zodiacal');
                              return;
                            }
                            setState(() {
                              if (isSelected) {
                                _filters.zodiacSigns.remove(sign);
                              } else {
                                _filters.zodiacSigns.add(sign);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 2. Personalidad MBTI
                  _buildAdvancedCategory(
                    title: 'Personalidad (MBTI)',
                    icon: Icons.psychology_outlined,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableMbti.map((mbtiVal) {
                        final isSelected = _filters.mbti.contains(mbtiVal);
                        return _buildLockableChip(
                          label: mbtiVal,
                          isSelected: isSelected,
                          onTap: () {
                            if (!widget.isPro) {
                              _promptProUpgrade('Personalidad MBTI');
                              return;
                            }
                            setState(() {
                              if (isSelected) {
                                _filters.mbti.remove(mbtiVal);
                              } else {
                                _filters.mbti.add(mbtiVal);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 3. Lenguajes del Amor
                  _buildAdvancedCategory(
                    title: 'Lenguajes del Amor',
                    icon: Icons.favorite_border_rounded,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableLoveLanguages.map((love) {
                        final isSelected = _filters.loveLanguages.contains(love);
                        return _buildLockableChip(
                          label: love,
                          isSelected: isSelected,
                          onTap: () {
                            if (!widget.isPro) {
                              _promptProUpgrade('Lenguajes del Amor');
                              return;
                            }
                            setState(() {
                              if (isSelected) {
                                _filters.loveLanguages.remove(love);
                              } else {
                                _filters.loveLanguages.add(love);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 4. Hábitos y Estilo de Vida
                  _buildAdvancedCategory(
                    title: 'Estilo de Vida y Hábitos',
                    icon: Icons.emoji_nature_rounded,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildLockableChip(
                          label: '🐶 Con mascotas',
                          isSelected: _filters.pets == 'Con mascotas',
                          onTap: () {
                            if (!widget.isPro) {
                              _promptProUpgrade('Mascotas');
                              return;
                            }
                            setState(() {
                              _filters.pets = (_filters.pets == 'Con mascotas') ? null : 'Con mascotas';
                            });
                          },
                        ),
                        _buildLockableChip(
                          label: '🚭 No fuma',
                          isSelected: _filters.smoking == 'No fuma',
                          onTap: () {
                            if (!widget.isPro) {
                              _promptProUpgrade('Hábito de no fumar');
                              return;
                            }
                            setState(() {
                              _filters.smoking = (_filters.smoking == 'No fuma') ? null : 'No fuma';
                            });
                          },
                        ),
                        _buildLockableChip(
                          label: '🍸 No bebe',
                          isSelected: _filters.drinking == 'No bebe',
                          onTap: () {
                            if (!widget.isPro) {
                              _promptProUpgrade('Hábito de no beber');
                              return;
                            }
                            setState(() {
                              _filters.drinking = (_filters.drinking == 'No bebe') ? null : 'No bebe';
                            });
                          },
                        ),
                        _buildLockableChip(
                          label: '🏋️ Ejercicio regular',
                          isSelected: _filters.workout == 'Regular / Diario',
                          onTap: () {
                            if (!widget.isPro) {
                              _promptProUpgrade('Hábito de ejercicio');
                              return;
                            }
                            setState(() {
                              _filters.workout = (_filters.workout == 'Regular / Diario') ? null : 'Regular / Diario';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 5. Filtros Rápidos (Prompts y Verificados)
                  _buildAdvancedCategory(
                    title: 'Perfiles Destacados',
                    icon: Icons.verified_user_outlined,
                    child: Column(
                      children: [
                        _buildSwitchTile(
                          title: 'Solo con preguntas respondidas',
                          subtitle: 'Usuarios que han completado rompehielos en su perfil 💬',
                          value: _filters.onlyWithPrompts,
                          onChanged: (val) {
                            if (!widget.isPro) {
                              _promptProUpgrade('Perfiles con preguntas');
                              return;
                            }
                            setState(() => _filters.onlyWithPrompts = val);
                          },
                        ),
                        const SizedBox(height: 8),
                        _buildSwitchTile(
                          title: 'Solo perfiles Verificados / VIP',
                          subtitle: 'Cuentas verificadas y suscriptores Almona Pro ⭐',
                          value: _filters.onlyVerified,
                          onChanged: (val) {
                            if (!widget.isPro) {
                              _promptProUpgrade('Perfiles verificados');
                              return;
                            }
                            setState(() => _filters.onlyVerified = val);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // 6. Filtros para Citas y Reservas en Mapa
                  _buildAdvancedCategory(
                    title: 'Filtros para Reservas y Citas (Mapa)',
                    icon: Icons.restaurant_menu_rounded,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Tipo de plan:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['Cena', 'Tragos', 'Café', 'Fiesta'].map((plan) {
                            final isSelected = _filters.planTypes.contains(plan);
                            return _buildLockableChip(
                              label: plan == 'Cena'
                                  ? '🍽️ Cena'
                                  : plan == 'Tragos'
                                      ? '🍸 Tragos'
                                      : plan == 'Café'
                                          ? '☕ Café / Brunch'
                                          : '🎉 Fiesta',
                              isSelected: isSelected,
                              onTap: () {
                                if (!widget.isPro) {
                                  _promptProUpgrade('Tipo de cita');
                                  return;
                                }
                                setState(() {
                                  if (isSelected) {
                                    _filters.planTypes.remove(plan);
                                  } else {
                                    _filters.planTypes.add(plan);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        const Text('Estilo de pago:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: ['50/50', 'Invito yo', 'Invita él/ella'].map((pay) {
                            final isSelected = _filters.paymentTypes.contains(pay);
                            return _buildLockableChip(
                              label: pay == '50/50' ? '💳 50 / 50' : pay == 'Invito yo' ? '🎁 Invito yo' : '✨ Invita la otra persona',
                              isSelected: isSelected,
                              onTap: () {
                                if (!widget.isPro) {
                                  _promptProUpgrade('Forma de pago');
                                  return;
                                }
                                setState(() {
                                  if (isSelected) {
                                    _filters.paymentTypes.remove(pay);
                                  } else {
                                    _filters.paymentTypes.add(pay);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // Barra inferior con botón de Aplicar Filtros
          Container(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(context).padding.bottom + 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  widget.onApply(_filters);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
                child: Text(
                  activeCount > 0 ? 'Aplicar Filtros ($activeCount)' : 'Aplicar Filtros',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HELPERS DE DISEÑO Y COMPONENTES
  // ---------------------------------------------------------------------------
  Widget _buildSectionHeader({
    required String title,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBg,
    required IconData icon,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: badgeColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 11.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubheader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildGenderSelector() {
    final options = [
      {'label': 'Todos', 'icon': Icons.people_outline},
      {'label': 'Mujeres', 'icon': Icons.female},
      {'label': 'Hombres', 'icon': Icons.male},
    ];

    return Row(
      children: options.map((opt) {
        final label = opt['label'] as String;
        final icon = opt['icon'] as IconData;
        final isSelected = _filters.interestedIn.toLowerCase() == label.toLowerCase();

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                setState(() => _filters.interestedIn = label);
              },
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: isSelected ? Colors.white : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProBanner() {
    if (widget.isPro) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF6C2BD9).withOpacity(0.12),
              const Color(0xFFFF5E3A).withOpacity(0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF6C2BD9).withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.workspace_premium, color: Color(0xFF6C2BD9), size: 26),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Filtros Pro Desbloqueados!',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C2BD9), fontSize: 13.5),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Puedes filtrar por compatibilidad astrológica, personalidad MBTI, lenguajes de amor y hábitos.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E28),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFF7A00), Color(0xFFFF007A)]),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Desbloquea Filtros Avanzados',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13.5),
                ),
                const SizedBox(height: 3),
                Text(
                  'Encuentra perfiles con tu mismo signo, personalidad MBTI o estilo de vida con Almona Pro.',
                  style: TextStyle(fontSize: 11.5, color: Colors.white.withOpacity(0.7), height: 1.3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              SubscriptionPlansPage.show(context, initialTier: SubscriptionTier.pro);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5E3A),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Ver Pro', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedCategory({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: widget.isPro ? const Color(0xFF6C2BD9) : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (!widget.isPro) ...[
              const SizedBox(width: 6),
              const Icon(Icons.lock_rounded, size: 13, color: Color(0xFFFF5E3A)),
            ],
          ],
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }

  Widget _buildLockableChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isPro = widget.isPro;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isPro ? const Color(0xFF6C2BD9).withOpacity(0.15) : AppColors.primary.withOpacity(0.15))
              : Colors.black.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? (isPro ? const Color(0xFF6C2BD9) : AppColors.primary)
                : Colors.black.withOpacity(0.08),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? (isPro ? const Color(0xFF6C2BD9) : AppColors.primary)
                    : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
            if (!isPro) ...[
              const SizedBox(width: 5),
              Icon(Icons.lock_rounded, size: 12, color: Colors.black.withOpacity(0.35)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isPro = widget.isPro;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: AppColors.textPrimary),
                      ),
                    ),
                    if (!isPro) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.lock_rounded, size: 13, color: Color(0xFFFF5E3A)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary, height: 1.3),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFF6C2BD9),
            onChanged: (val) => onChanged(val),
          ),
        ],
      ),
    );
  }
}
