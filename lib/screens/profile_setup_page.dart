import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import 'home_page.dart';
import '../widgets/zone_selection_map.dart';

class ProfileSetupPage extends StatefulWidget {
  final bool isEditMode;

  const ProfileSetupPage({super.key, this.isEditMode = false});

  @override
  State<ProfileSetupPage> createState() => _ProfileSetupPageState();
}

class _ProfileSetupPageState extends State<ProfileSetupPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  static const int _totalSteps = 7;
  bool _isSaving = false;

  // -------------------------------------------------------------
  // 1. DATOS OBLIGATORIOS
  // -------------------------------------------------------------
  final TextEditingController _nameController = TextEditingController();
  DateTime? _birthDate;
  
  // Género & Visibilidad
  String? _gender;
  bool _showGenderOnProfile = true;
  final List<String> _genderOptions = ['Hombre', 'Mujer', 'No binario', 'Transgénero', 'Fluido', 'Otro'];

  // Orientación sexual (hasta 3 selecciones)
  final Set<String> _sexualOrientations = {};
  final List<String> _orientationOptions = [
    'Heterosexual', 'Gay', 'Lesbiana', 'Bisexual',
    'Asexual', 'Demisexual', 'Pansexual', 'Queer', 'Cuestionándome'
  ];

  // A quién quieres ver
  String? _interestedIn;
  final List<String> _interestedInOptions = ['Hombres', 'Mujeres', 'Todos'];

  // Fotos (mínimo 2 requeridas)
  final List<XFile?> _photos = List.filled(6, null);
  final List<String?> _existingPhotoUrls = List.filled(6, null);
  bool _isLoadingData = true;

  // Ubicación obligatoria
  GeoPoint? _userLocation;

  // -------------------------------------------------------------
  // 2. INTENCIÓN DE RELACIÓN Y ZONAS
  // -------------------------------------------------------------
  final Set<String> _preferredZones = {};

  final Set<String> _relationshipGoals = {};
  final List<Map<String, dynamic>> _relationshipGoalOptions = [
    {'title': 'Relación a largo plazo', 'desc': 'Buscando algo formal y duradero', 'icon': Icons.favorite},
    {'title': 'A largo plazo pero abierto a corto', 'desc': 'Quiero compromiso, pero sin prisa', 'icon': Icons.hourglass_bottom},
    {'title': 'A corto plazo pero abierto a largo', 'desc': 'Empezando casual y ver qué surge', 'icon': Icons.local_fire_department},
    {'title': 'Diversión a corto plazo', 'desc': 'Salidas divertidas sin ataduras', 'icon': Icons.nightlife},
    {'title': 'Hacer amigos', 'desc': 'Conectar con personas afines', 'icon': Icons.group},
    {'title': 'Aún no lo tengo claro', 'desc': 'Viendo qué depara la experiencia', 'icon': Icons.help_outline},
  ];

  // -------------------------------------------------------------
  // 3. ESTILO DE VIDA Y HÁBITOS (OPCIONALES)
  // -------------------------------------------------------------
  String? _pets;
  final List<String> _petsOptions = ['Perro', 'Gato', 'Reptil', 'Varios', 'Sin mascotas', 'Alérgico/a'];

  String? _drinking;
  final List<String> _drinkingOptions = ['Nunca', 'Sobrio/a', 'En ocasiones especiales', 'Socialmente fines de semana', 'Casi todas las noches'];

  String? _smokingTobacco;
  final List<String> _smokingTobaccoOptions = ['No fumo', 'Fumador/a social', 'Fumo habitualmente'];

  String? _smokingCannabis;
  final List<String> _smokingCannabisOptions = ['Sí', 'No', 'Socialmente'];

  String? _workout;
  final List<String> _workoutOptions = ['Todos los días', 'Regularmente', 'A veces', 'Nunca'];

  String? _sleepPattern;
  final List<String> _sleepPatternOptions = ['Madrugador/a 🌅', 'Noctámbulo/a 🌙'];

  // -------------------------------------------------------------
  // 4. INFORMACIÓN PERSONAL Y ANTECEDENTES (OPCIONALES)
  // -------------------------------------------------------------
  String? _zodiac;
  final List<String> _zodiacOptions = [
    'Aries ♈', 'Tauro ♉', 'Géminis ♊', 'Cáncer ♋',
    'Leo ♌', 'Virgo ♍', 'Libra ♎', 'Escorpio ♏',
    'Sagitario ♐', 'Capricornio ♑', 'Acuario ♒', 'Piscis ♓'
  ];

  // Campo MBTI (permite hasta 2 opciones)
  final Set<String> _mbti = {};
  final List<String> _mbtiOptions = [
    'INTJ', 'INTP', 'ENTJ', 'ENTP',
    'INFJ', 'INFP', 'ENFJ', 'ENFP',
    'ISTJ', 'ISFJ', 'ESTJ', 'ESFJ',
    'ISTP', 'ISFP', 'ESTP', 'ESFP',
  ];

  String? _education;
  final List<String> _educationOptions = ['Secundaria', 'En la universidad', 'Título universitario', 'Posgrado / Maestría', 'Doctorado'];

  // Lenguaje del amor ampliado (permite hasta 3 opciones)
  final Set<String> _loveLanguages = {};
  final List<String> _loveLanguageOptions = [
    'Palabras de afirmación 💬',
    'Tiempo de calidad ⏳',
    'Detalles y regalos 🎁',
    'Actos de servicio 🤝',
    'Contacto físico 🫂',
    'Risas y buen humor 😂',
    'Escucha y apoyo emocional 👂',
    'Aventuras y viajes juntos ✈️',
    'Cocinar y compartir comida 🍳',
    'Respeto al espacio personal 🧘',
  ];

  String? _familyPlans;
  final List<String> _familyPlansOptions = [
    'Quiero hijos', 'No quiero hijos', 'Tengo hijos y quiero más', 'Ya tengo hijos y no quiero más', 'Aún no lo sé'
  ];

  String? _communication;
  final List<String> _communicationOptions = ['Gran texter 💬', 'Llamadas telefónicas 📞', 'Notas de voz 🎙️', 'Malo respondiendo ⏳', 'Cara a cara ☕'];

  final Set<String> _languages = {'Español'};
  final List<String> _languagesOptions = ['Español', 'Inglés', 'Francés', 'Portugués', 'Italiano', 'Alemán', 'Mandarín', 'Japonés'];

  // -------------------------------------------------------------
  // 5. CAMPOS ABIERTOS Y REDES
  // -------------------------------------------------------------
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _workController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();

  final Set<String> _interests = {};
  final List<String> _availableInterests = [
    'Música', 'Cine', 'Café', 'Senderismo', 'Videojuegos',
    'Viajes', 'Fotografía', 'Arte', 'Cocina', 'Lectura',
    'Yoga', 'Vino & Cocktails', 'Playa', 'Festivales', 'Gym',
    'Música en vivo', 'Coctelería de autor', 'Gastrobares',
    'Museos', 'Catas de Vino', 'Running', 'Ciclismo',
    'Repostería', 'Stand-up Comedy', 'Idiomas', 'Mascotas'
  ];

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _requestInitialLocation();
    _loadExistingUserData();
  }

  Future<void> _loadExistingUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoadingData = false);
        return;
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          // Nombre
          if (data['name'] != null && data['name'].toString().isNotEmpty) {
            _nameController.text = data['name'].toString();
          }
          // Fecha de nacimiento
          if (data['birthDate'] != null && data['birthDate'] is Timestamp) {
            _birthDate = (data['birthDate'] as Timestamp).toDate();
          }
          // Género
          if (data['gender'] != null) {
            _gender = data['gender'].toString();
          }
          if (data['showGenderOnProfile'] != null) {
            _showGenderOnProfile = data['showGenderOnProfile'] as bool;
          }
          // Orientaciones
          if (data['sexualOrientation'] != null && data['sexualOrientation'] is List) {
            _sexualOrientations.clear();
            final list = data['sexualOrientation'] as List<dynamic>;
            _sexualOrientations.addAll(list.map((e) => e.toString()));
          }
          // A quién busca
          if (data['interestedIn'] != null) {
            _interestedIn = data['interestedIn'].toString();
          }
          // Fotos existentes
          final rawPhotos = (data['photoUrls'] as List?) ?? (data['photos'] as List?) ?? [];
          for (int i = 0; i < 6; i++) {
            if (i < rawPhotos.length && rawPhotos[i] != null && rawPhotos[i].toString().isNotEmpty) {
              _existingPhotoUrls[i] = rawPhotos[i].toString();
            }
          }
          // Ubicación
          if (data['location'] != null && data['location'] is GeoPoint) {
            _userLocation = data['location'] as GeoPoint;
          }
          // Objetivo y zonas
          if (data['relationshipGoals'] != null && data['relationshipGoals'] is List) {
            _relationshipGoals.clear();
            _relationshipGoals.addAll((data['relationshipGoals'] as List).map((e) => e.toString()));
          } else if (data['relationshipGoal'] != null) {
            _relationshipGoals.clear();
            final raw = data['relationshipGoal'].toString();
            if (raw.contains(' • ')) {
              _relationshipGoals.addAll(raw.split(' • ').map((e) => e.trim()));
            } else if (raw.isNotEmpty) {
              _relationshipGoals.add(raw);
            }
          }
          if (data['preferredZones'] != null && data['preferredZones'] is List) {
            _preferredZones.clear();
            _preferredZones.addAll((data['preferredZones'] as List).map((e) => e.toString()));
          }
          // Estilo de vida
          final lifestyle = data['lifestyle'] as Map<String, dynamic>? ?? {};
          _pets = lifestyle['pets']?.toString();
          _drinking = lifestyle['drinking']?.toString();
          _smokingTobacco = lifestyle['smokingTobacco']?.toString();
          _smokingCannabis = lifestyle['smokingCannabis']?.toString();
          _workout = lifestyle['workout']?.toString();
          _sleepPattern = lifestyle['sleepPattern']?.toString();

          // Información personal
          final personal = data['personal'] as Map<String, dynamic>? ?? {};
          _zodiac = personal['zodiac']?.toString();

          _mbti.clear();
          final mbtiRaw = personal['mbtis'] ?? personal['mbti'] ?? data['mbti'];
          if (mbtiRaw is List) {
            _mbti.addAll(mbtiRaw.map((e) => e.toString()));
          } else if (mbtiRaw is String && mbtiRaw.isNotEmpty) {
            if (mbtiRaw.contains(',')) {
              _mbti.addAll(mbtiRaw.split(',').map((e) => e.trim()));
            } else {
              _mbti.add(mbtiRaw.trim());
            }
          }

          _education = personal['education']?.toString();

          _loveLanguages.clear();
          final loveRaw = personal['loveLanguages'] ?? personal['loveLanguage'];
          if (loveRaw is List) {
            _loveLanguages.addAll(loveRaw.map((e) => e.toString()));
          } else if (loveRaw is String && loveRaw.isNotEmpty) {
            if (loveRaw.contains(',')) {
              _loveLanguages.addAll(loveRaw.split(',').map((e) => e.trim()));
            } else {
              _loveLanguages.add(loveRaw.trim());
            }
          }

          _familyPlans = personal['familyPlans']?.toString();
          _communication = personal['communication']?.toString();
          if (personal['languages'] != null && personal['languages'] is List) {
            _languages.clear();
            final langList = personal['languages'] as List<dynamic>;
            _languages.addAll(langList.map((e) => e.toString()));
          }

          // Campos abiertos
          if (data['bio'] != null) _bioController.text = data['bio'].toString();
          if (data['work'] != null) _workController.text = data['work'].toString();
          if (data['school'] != null) _schoolController.text = data['school'].toString();
          if (data['instagramHandle'] != null) _instagramController.text = data['instagramHandle'].toString();

          // Intereses
          if (data['interests'] != null && data['interests'] is List) {
            _interests.clear();
            final intList = data['interests'] as List<dynamic>;
            _interests.addAll(intList.map((e) => e.toString()));
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading existing profile data: $e');
    } finally {
      if (mounted) setState(() => _isLoadingData = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _bioController.dispose();
    _workController.dispose();
    _schoolController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  Future<bool> _requestInitialLocation() async {
    setState(() {
      _userLocation = const GeoPoint(4.6097, -74.0817);
    });
    return true;
  }

  // -------------------------------------------------------------
  // VALIDACIONES POR PASO (Modo Wizard)
  // -------------------------------------------------------------
  void _nextPage() async {
    if (_currentPage == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Por favor ingresa tu nombre de pila');
        return;
      }
      if (_birthDate == null) {
        _showError('Ingresa tu fecha de nacimiento');
        return;
      }
      final age = DateTime.now().year - _birthDate!.year;
      if (age < 18) {
        _showError('Debes tener al menos 18 años para usar la aplicación');
        return;
      }
    }

    if (_currentPage == 1) {
      if (_gender == null) {
        _showError('Por favor selecciona tu género');
        return;
      }
      if (_sexualOrientations.isEmpty) {
        _showError('Selecciona al menos una orientación sexual');
        return;
      }
    }

    if (_currentPage == 2) {
      if (_interestedIn == null) {
        _showError('Selecciona a quién te gustaría ver');
        return;
      }
      if (_relationshipGoals.isEmpty) {
        _showError('Por favor selecciona al menos una opción de lo que buscas en la app');
        return;
      }
      if (_preferredZones.isEmpty) {
        _showError('Selecciona al menos una zona de preferencia para tus reservas');
        return;
      }
    }

    if (_currentPage == 3) {
      final uploadedCount = List.generate(6, (i) => _photos[i] != null || (_existingPhotoUrls[i] != null && _existingPhotoUrls[i]!.isNotEmpty)).where((b) => b).length;
      if (uploadedCount < 2) {
        _showError('Es obligatorio subir al menos 2 fotos para activar tu cuenta');
        return;
      }
    }

    if (_currentPage == _totalSteps - 1) {
      _saveProfile();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (image != null) {
      setState(() {
        _photos[index] = image;
      });
    }
  }

  Future<void> _saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('Sesión no encontrada');
      return;
    }

    // Validar mínimo fotos
    final uploadedCount = List.generate(6, (i) => _photos[i] != null || (_existingPhotoUrls[i] != null && _existingPhotoUrls[i]!.isNotEmpty)).where((b) => b).length;
    if (uploadedCount < 2) {
      _showError('Es obligatorio tener al menos 2 fotos de perfil');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final List<String> photoUrls = [];
      for (int i = 0; i < 6; i++) {
        if (_photos[i] != null) {
          final ref = FirebaseStorage.instance.ref().child('users/${user.uid}/photos/photo_$i.jpg');
          if (kIsWeb) {
            await ref.putData(await _photos[i]!.readAsBytes());
          } else {
            await ref.putFile(File(_photos[i]!.path));
          }
          final url = await ref.getDownloadURL();
          photoUrls.add(url);
        } else if (_existingPhotoUrls[i] != null && _existingPhotoUrls[i]!.isNotEmpty) {
          photoUrls.add(_existingPhotoUrls[i]!);
        }
      }

      final profileData = {
        'name': _nameController.text.trim(),
        'birthDate': _birthDate,
        'gender': _gender,
        'showGenderOnProfile': _showGenderOnProfile,
        'sexualOrientation': _sexualOrientations.toList(),
        'interestedIn': _interestedIn,
        'photoUrls': photoUrls,
        'photos': photoUrls,
        'location': _userLocation,
        'isProfileComplete': true,
        'createdAt': FieldValue.serverTimestamp(),

        'relationshipGoal': _relationshipGoals.join(' • '),
        'relationshipGoals': _relationshipGoals.toList(),
        'preferredZones': _preferredZones.toList(),

        'lifestyle': {
          'pets': _pets,
          'drinking': _drinking,
          'smokingTobacco': _smokingTobacco,
          'smokingCannabis': _smokingCannabis,
          'workout': _workout,
          'sleepPattern': _sleepPattern,
        },

        'personal': {
          'zodiac': _zodiac,
          'mbti': _mbti.join(', '),
          'mbtis': _mbti.toList(),
          'education': _education,
          'loveLanguage': _loveLanguages.join(', '),
          'loveLanguages': _loveLanguages.toList(),
          'familyPlans': _familyPlans,
          'communication': _communication,
          'languages': _languages.toList(),
        },

        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'school': _schoolController.text.trim(),
        'interests': _interests.toList(),
        'instagramHandle': _instagramController.text.trim().replaceAll('@', ''),
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        profileData,
        SetOptions(merge: true),
      );

      // Actualizar foto y nombre en las reservas
      try {
        final myReservations = await FirebaseFirestore.instance
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .get();
        if (myReservations.docs.isNotEmpty) {
          final batch = FirebaseFirestore.instance.batch();
          for (var doc in myReservations.docs) {
            batch.update(doc.reference, {
              'userName': _nameController.text.trim(),
              'userPhoto': photoUrls.isNotEmpty ? photoUrls[0] : '',
            });
          }
          await batch.commit();
        }
      } catch (e) {
        debugPrint('Warning: Could not batch update user reservations: $e');
      }

      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Perfil actualizado con éxito! 🎉'),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomePage(email: user.email ?? '')),
        );
      }
    } catch (e) {
      _showError('Error al guardar perfil: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // -------------------------------------------------------------
  // HELPER CHIPS SIN BUG DE REFLOW NI FONDO NEGRO
  // -------------------------------------------------------------
  Widget _buildChipSelector(String title, List<String> options, String? currentValue, ValueChanged<String?> onSelected) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = currentValue == opt;
              return GestureDetector(
                onTap: () => onSelected(isSelected ? null : opt),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.inputBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiChipSelector({
    required String title,
    required List<String> options,
    required Set<String> selectedSet,
    required int maxSelection,
    Widget? subtitleWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Text(
                '(${selectedSet.length}/$maxSelection)',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ],
          ),
          if (subtitleWidget != null) ...[
            const SizedBox(height: 6),
            subtitleWidget,
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((opt) {
              final isSelected = selectedSet.contains(opt);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedSet.remove(opt);
                    } else if (selectedSet.length < maxSelection) {
                      selectedSet.add(opt);
                    } else {
                      _showError('Puedes seleccionar máximo $maxSelection opciones');
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.inputBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    opt,
                    style: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMbtiLinkBanner() {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse('https://www.16personalities.com/es/test-de-personalidad');
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF2E7D32).withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.25)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF2E7D32)),
            SizedBox(width: 6),
            Text(
              '¿No sabes tu tipo? ',
              style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32), fontWeight: FontWeight.w500),
            ),
            Text(
              'Conoce más y haz el test aquí ↗',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF2E7D32),
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultiSelectChips({
    required List<String> options,
    required Set<String> selectedSet,
    required void Function(String item) onToggle,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((item) {
        final isSelected = selectedSet.contains(item);
        return GestureDetector(
          onTap: () => onToggle(item),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.inputBorder,
                width: 1.2,
              ),
            ),
            child: Text(
              item,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // -------------------------------------------------------------
  // CONSTRUCCIÓN DE LA VISTA (Wizard vs Continuous Scroll)
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16),
              Text('Cargando tu información...', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            ],
          ),
        ),
      );
    }

    // Modo 1: Edición Continua en un solo Scroll (desde MyProfilePage)
    if (widget.isEditMode) {
      return _buildContinuousEditView();
    }

    // Modo 2: Wizard por Pasos (Onboarding inicial)
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _currentPage > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary, size: 20),
                onPressed: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
              )
            : (Navigator.of(context).canPop()
                ? IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textPrimary, size: 22),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : null),
        title: Text(
          'Paso ${_currentPage + 1} de $_totalSteps',
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_currentPage + 1) / _totalSteps,
                  minHeight: 6,
                  backgroundColor: AppColors.divider,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  _buildNameAndBirthStep(),
                  _buildGenderAndOrientationStep(),
                  _buildPreferencesAndIntentStep(),
                  _buildPhotosAndLocationStep(),
                  _buildLifestyleStep(),
                  _buildPersonalInfoStep(),
                  _buildBioAndDetailsStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _nextPage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _currentPage == _totalSteps - 1 ? 'Finalizar Perfil' : 'Continuar',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // VISTA DE EDICIÓN CONTINUA EN UN SOLO SCROLL
  // -------------------------------------------------------------
  Widget _buildContinuousEditView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Editar Perfil',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                : const Text('Guardar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sección 1: Fotos
              _buildSectionHeader('Tus Fotos de Perfil'),
              const SizedBox(height: 12),
              _buildPhotosGrid(),
              const SizedBox(height: 28),

              // Sección 2: Zonas de Preferencia
              _buildSectionHeader('📍 Zonas de Preferencia'),
              const SizedBox(height: 8),
              _buildZoneSelectorTile(),
              const SizedBox(height: 28),

              // Sección 3: Datos Básicos
              _buildSectionHeader('Datos Básicos'),
              const SizedBox(height: 14),
              _buildTextFieldWithIcon('Nombre completo', _nameController, 'Tu nombre', Icons.person_outline),
              const SizedBox(height: 14),
              _buildTextFieldWithIcon('💼 Ocupación', _workController, 'Ej. Diseñador / Arquitecto / Emprendedor', Icons.work_outline),
              const SizedBox(height: 14),
              _buildTextFieldWithIcon('📸 Usuario de Instagram', _instagramController, 'tu_usuario (sin @)', Icons.camera_alt_outlined),
              const SizedBox(height: 28),

              // Sección 4: Biografía
              _buildSectionHeader('Sobre Ti (Biografía)'),
              const SizedBox(height: 10),
              TextField(
                controller: _bioController,
                maxLines: 4,
                maxLength: 500,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Cuéntanos qué te apasiona, tus planes favoritos o una anécdota divertida...',
                  hintStyle: const TextStyle(color: AppColors.textLight),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
                ),
              ),
              const SizedBox(height: 28),

              // Sección 5: Personalidad MBTI
              _buildSectionHeader('🧠 Personalidad (MBTI)'),
              const SizedBox(height: 6),
              _buildMbtiLinkBanner(),
              const SizedBox(height: 10),
              _buildMultiChipSelector(
                title: 'Tipo MBTI (Elige hasta 2)',
                options: _mbtiOptions,
                selectedSet: _mbti,
                maxSelection: 2,
              ),
              const SizedBox(height: 24),

              // Sección 6: ¿Qué buscas en Conecta?
              _buildSectionHeader('🎯 ¿Qué estás buscando en Conecta? (Elige hasta 2)'),
              const SizedBox(height: 12),
              ..._relationshipGoalOptions.map((goal) {
                final title = goal['title'] as String;
                final isSelected = _relationshipGoals.contains(title);
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.primary : AppColors.inputBorder, width: isSelected ? 2 : 1),
                  ),
                  child: ListTile(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _relationshipGoals.remove(title);
                        } else if (_relationshipGoals.length < 2) {
                          _relationshipGoals.add(title);
                        } else {
                          _showError('Puedes seleccionar máximo 2 opciones');
                        }
                      });
                    },
                    leading: Icon(goal['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.icon),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                    subtitle: Text(goal['desc'] as String, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  ),
                );
              }),
              const SizedBox(height: 28),

              // Sección 7: Intereses y Pasiones
              _buildSectionHeader('🌟 Intereses y Pasiones (Hasta 5)'),
              const SizedBox(height: 12),
              _buildMultiSelectChips(
                options: _availableInterests,
                selectedSet: _interests,
                onToggle: (item) {
                  setState(() {
                    if (_interests.contains(item)) {
                      _interests.remove(item);
                    } else if (_interests.length < 5) {
                      _interests.add(item);
                    } else {
                      _showError('Puedes seleccionar máximo 5 intereses');
                    }
                  });
                },
              ),
              const SizedBox(height: 28),

              // Sección 8: Estilo de Vida y Hábitos
              _buildSectionHeader('🌱 Estilo de Vida y Hábitos'),
              const SizedBox(height: 14),
              _buildChipSelector('🐾 Mascotas', _petsOptions, _pets, (val) => setState(() => _pets = val)),
              _buildChipSelector('🍷 Bebida', _drinkingOptions, _drinking, (val) => setState(() => _drinking = val)),
              _buildChipSelector('🚬 Fumar (Tabaco)', _smokingTobaccoOptions, _smokingTobacco, (val) => setState(() => _smokingTobacco = val)),
              _buildChipSelector('🌿 Fumar (Cannabis)', _smokingCannabisOptions, _smokingCannabis, (val) => setState(() => _smokingCannabis = val)),
              _buildChipSelector('💪 Ejercicio', _workoutOptions, _workout, (val) => setState(() => _workout = val)),
              _buildChipSelector('⏰ Patrón de sueño', _sleepPatternOptions, _sleepPattern, (val) => setState(() => _sleepPattern = val)),
              const SizedBox(height: 24),

              // Sección 9: Más sobre ti
              _buildSectionHeader('✨ Más Sobre Ti'),
              const SizedBox(height: 14),
              _buildChipSelector('⭐ Signo del Zodiaco', _zodiacOptions, _zodiac, (val) => setState(() => _zodiac = val)),
              _buildMultiChipSelector(
                title: '💖 Lenguaje del Amor (Elige hasta 3)',
                options: _loveLanguageOptions,
                selectedSet: _loveLanguages,
                maxSelection: 3,
              ),
              _buildChipSelector('👶 Planes de Familia / Hijos', _familyPlansOptions, _familyPlans, (val) => setState(() => _familyPlans = val)),
              _buildChipSelector('💬 Estilo de Comunicación', _communicationOptions, _communication, (val) => setState(() => _communication = val)),
              _buildChipSelector('🎓 Nivel de Educación', _educationOptions, _education, (val) => setState(() => _education = val)),

              const SizedBox(height: 20),
              // Botón Guardar al final del scroll
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Guardar Todos los Cambios', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
    );
  }

  Widget _buildZoneSelectorTile() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push<Set<String>>(
          context,
          MaterialPageRoute(
            builder: (_) => ZoneSelectionMap(
              initialSelectedZones: _preferredZones,
            ),
          ),
        );
        if (result != null) {
          setState(() {
            _preferredZones.clear();
            _preferredZones.addAll(result);
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.map_outlined, color: AppColors.primary, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Zonas seleccionadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(
                    _preferredZones.isNotEmpty
                        ? '${_preferredZones.length} zonas elegidas'
                        : 'Toca para seleccionar tus zonas',
                    style: TextStyle(
                      fontSize: 12,
                      color: _preferredZones.isNotEmpty ? Colors.green : AppColors.textSecondary,
                      fontWeight: _preferredZones.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.textLight, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotosGrid() {
    final uploadedCount = List.generate(6, (i) => _photos[i] != null || (_existingPhotoUrls[i] != null && _existingPhotoUrls[i]!.isNotEmpty)).where((b) => b).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: 6,
          itemBuilder: (context, i) {
            final hasNewPhoto = _photos[i] != null;
            final hasExistingPhoto = _existingPhotoUrls[i] != null && _existingPhotoUrls[i]!.isNotEmpty;
            final isPopulated = hasNewPhoto || hasExistingPhoto;

            return GestureDetector(
              onTap: () => _pickImage(i),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPopulated ? AppColors.primary : AppColors.inputBorder,
                    width: isPopulated ? 1.8 : 1,
                  ),
                ),
                child: !isPopulated
                    ? const Center(
                        child: Icon(Icons.add_a_photo_outlined, color: AppColors.textLight, size: 28),
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: hasNewPhoto
                                ? (kIsWeb
                                    ? Image.network(_photos[i]!.path, fit: BoxFit.cover)
                                    : Image.file(File(_photos[i]!.path), fit: BoxFit.cover))
                                : Image.network(
                                    _existingPhotoUrls[i]!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image)),
                                  ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _photos[i] = null;
                                _existingPhotoUrls[i] = null;
                              }),
                              child: Container(
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black54),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          if (i == 0)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('Principal', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Text(
          'Fotos cargadas: $uploadedCount/2 requeridas mínimo',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: uploadedCount >= 2 ? Colors.green : Colors.redAccent,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // PASOS WIZARD (ONBOARDING)
  // -------------------------------------------------------------
  Widget _buildNameAndBirthStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Cómo te llamas?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Así aparecerás en tu perfil y reservas.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            style: const TextStyle(fontSize: 18, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'Tu nombre de pila',
              hintStyle: const TextStyle(color: AppColors.textLight),
              filled: true,
              fillColor: AppColors.surface,
              prefixIcon: const Icon(Icons.person, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 32),
          const Text('¿Cuándo naciste?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Tu edad será visible. Debes tener al menos 18 años.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime(2000, 1, 1),
                firstDate: DateTime(1940),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    _birthDate != null ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}' : 'Seleccionar fecha',
                    style: TextStyle(
                      fontSize: 16,
                      color: _birthDate != null ? AppColors.textPrimary : AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderAndOrientationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿Cuál es tu género?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildChipSelector('Género', _genderOptions, _gender, (val) => setState(() => _gender = val)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar género en mi perfil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            value: _showGenderOnProfile,
            activeColor: AppColors.primary,
            onChanged: (val) => setState(() => _showGenderOnProfile = val),
          ),
          const SizedBox(height: 24),
          const Text('Orientación sexual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          _buildMultiSelectChips(
            options: _orientationOptions,
            selectedSet: _sexualOrientations,
            onToggle: (item) {
              setState(() {
                if (_sexualOrientations.contains(item)) {
                  _sexualOrientations.remove(item);
                } else if (_sexualOrientations.length < 3) {
                  _sexualOrientations.add(item);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesAndIntentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('¿A quién te gustaría ver?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          _buildChipSelector('Preferencia de perfiles', _interestedInOptions, _interestedIn, (val) => setState(() => _interestedIn = val)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('¿Qué estás buscando en Conecta?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('(${_relationshipGoals.length}/2)', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Elige hasta 2 opciones que definan tu objetivo.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 14),
          ..._relationshipGoalOptions.map((goal) {
            final title = goal['title'] as String;
            final isSelected = _relationshipGoals.contains(title);
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.inputBorder, width: isSelected ? 2 : 1),
              ),
              child: ListTile(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _relationshipGoals.remove(title);
                    } else if (_relationshipGoals.length < 2) {
                      _relationshipGoals.add(title);
                    } else {
                      _showError('Puedes seleccionar hasta 2 opciones');
                    }
                  });
                },
                leading: Icon(goal['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.icon),
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                subtitle: Text(goal['desc'] as String, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : const Icon(Icons.radio_button_unchecked, color: AppColors.textLight),
              ),
            );
          }),
          const SizedBox(height: 24),
          _buildZoneSelectorTile(),
        ],
      ),
    );
  }

  Widget _buildPhotosAndLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sube tus fotos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Sube al menos 2 fotos para que otros te reconozcan en tus citas.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),
          _buildPhotosGrid(),
        ],
      ),
    );
  }

  Widget _buildLifestyleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Estilo de Vida y Hábitos', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Son opcionales, pero ayudan a encontrar afinidades reales.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          _buildChipSelector('🐾 Mascotas', _petsOptions, _pets, (val) => setState(() => _pets = val)),
          _buildChipSelector('🍷 Bebida', _drinkingOptions, _drinking, (val) => setState(() => _drinking = val)),
          _buildChipSelector('🚬 Fumar (Tabaco)', _smokingTobaccoOptions, _smokingTobacco, (val) => setState(() => _smokingTobacco = val)),
          _buildChipSelector('🌿 Fumar (Cannabis)', _smokingCannabisOptions, _smokingCannabis, (val) => setState(() => _smokingCannabis = val)),
          _buildChipSelector('💪 Ejercicio', _workoutOptions, _workout, (val) => setState(() => _workout = val)),
          _buildChipSelector('⏰ Patrón de sueño', _sleepPatternOptions, _sleepPattern, (val) => setState(() => _sleepPattern = val)),
        ],
      ),
    );
  }

  Widget _buildPersonalInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Información Personal', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Conoce y hazte conocer con detalles que marcan la diferencia.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          _buildMultiChipSelector(
            title: '🧠 Tipo de Personalidad (MBTI)',
            options: _mbtiOptions,
            selectedSet: _mbti,
            maxSelection: 2,
            subtitleWidget: _buildMbtiLinkBanner(),
          ),
          _buildChipSelector('⭐ Signo del Zodiaco', _zodiacOptions, _zodiac, (val) => setState(() => _zodiac = val)),
          _buildMultiChipSelector(
            title: '💖 Lenguaje del Amor',
            options: _loveLanguageOptions,
            selectedSet: _loveLanguages,
            maxSelection: 3,
          ),
          _buildChipSelector('👶 Planes de Familia / Hijos', _familyPlansOptions, _familyPlans, (val) => setState(() => _familyPlans = val)),
          _buildChipSelector('💬 Estilo de Comunicación', _communicationOptions, _communication, (val) => setState(() => _communication = val)),
          _buildChipSelector('🎓 Nivel de Educación', _educationOptions, _education, (val) => setState(() => _education = val)),
          const SizedBox(height: 12),
          const Text('🗣️ Idiomas que hablas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _buildMultiSelectChips(
            options: _languagesOptions,
            selectedSet: _languages,
            onToggle: (lang) {
              setState(() {
                if (_languages.contains(lang)) {
                  _languages.remove(lang);
                } else {
                  _languages.add(lang);
                }
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBioAndDetailsStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sobre Ti y Redes', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('El toque final para hacer tu perfil único e irresistible.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 24),
          const Text('Biografía (hasta 500 caracteres)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _bioController,
            maxLines: 4,
            maxLength: 500,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Cuéntanos qué te apasiona, tus planes favoritos o una anécdota divertida...',
              hintStyle: const TextStyle(color: AppColors.textLight),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextFieldWithIcon('💼 Ocupación', _workController, 'Ej. Diseñador / Arquitecto / Emprendedor', Icons.work_outline),
          const SizedBox(height: 16),
          _buildTextFieldWithIcon('📸 Usuario de Instagram', _instagramController, 'Ej. tu_usuario (sin @)', Icons.camera_alt_outlined),
          const SizedBox(height: 24),
          const Text('🌟 Intereses y Pasiones (Elige hasta 5)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          _buildMultiSelectChips(
            options: _availableInterests,
            selectedSet: _interests,
            onToggle: (interest) {
              setState(() {
                if (_interests.contains(interest)) {
                  _interests.remove(interest);
                } else if (_interests.length < 5) {
                  _interests.add(interest);
                } else {
                  _showError('Puedes seleccionar máximo 5 intereses');
                }
              });
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextFieldWithIcon(String label, TextEditingController controller, String hint, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppColors.textLight),
            filled: true,
            fillColor: AppColors.surface,
            prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }
}
