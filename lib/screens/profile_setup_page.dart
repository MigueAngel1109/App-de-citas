import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:video_player/video_player.dart';
import '../utils/app_colors.dart';
import 'home_page.dart';

class ProfileSetupPage extends StatefulWidget {
  const ProfileSetupPage({super.key});

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
  String? _existingVideoUrl;
  bool _isLoadingData = true;

  // Ubicación obligatoria
  GeoPoint? _userLocation;
  bool _isLocating = false;

  // -------------------------------------------------------------
  // 2. INTENCIÓN DE RELACIÓN
  // -------------------------------------------------------------
  String? _relationshipGoal;
  final List<Map<String, dynamic>> _relationshipGoalOptions = [
    {'title': 'Relación a largo plazo', 'desc': 'Buscando algo formal y duradero', 'icon': Icons.favorite},
    {'title': 'A largo plazo pero abierto a corto', 'desc': 'Quiero compromiso, pero sin prisa', 'icon': Icons.hourglass_bottom},
    {'title': 'A corto plazo pero abierto a largo', 'desc': 'Empezando casual y ver qué surge', 'icon': Icons.local_fire_department},
    {'title': 'Diversión a corto plazo', 'desc': 'Citas divertidas sin ataduras', 'icon': Icons.nightlife},
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

  String? _diet;
  final List<String> _dietOptions = ['Omnívoro', 'Carnívoro', 'Vegetariano', 'Vegano', 'Pescatariano', 'Kosher', 'Halal'];

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

  String? _education;
  final List<String> _educationOptions = ['Secundaria', 'En la universidad', 'Título universitario', 'Posgrado / Maestría', 'Doctorado'];

  String? _loveLanguage;
  final List<String> _loveLanguageOptions = [
    'Palabras de afirmación', 'Tiempo de calidad', 'Regalos', 'Actos de servicio', 'Contacto físico'
  ];

  String? _familyPlans;
  final List<String> _familyPlansOptions = [
    'Quiero hijos', 'No quiero hijos', 'Ya tengo hijos y quiero más', 'Ya tengo hijos y no quiero más', 'Aún no lo sé'
  ];


  String? _communication;
  final List<String> _communicationOptions = ['Gran texter 💬', 'Llamadas telefónicas 📞', 'Notas de voz 🎙️', 'Malo respondiendo ⏳', 'Cara a cara ☕'];

  final Set<String> _languages = {'Español'};
  final List<String> _languagesOptions = ['Español', 'Inglés', 'Francés', 'Portugués', 'Italiano', 'Alemán', 'Mandarín', 'Japonés'];

  // -------------------------------------------------------------
  // 5. CAMPOS ABIERTOS Y MULTIMEDIA
  // -------------------------------------------------------------
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _workController = TextEditingController();
  final TextEditingController _schoolController = TextEditingController();
  final TextEditingController _spotifySongController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();

  final Set<String> _interests = {};
  final List<String> _availableInterests = [
    'Música', 'Cine', 'Café', 'Senderismo', 'Videojuegos',
    'Viajes', 'Fotografía', 'Arte', 'Cocina', 'Lectura',
    'Yoga', 'Vino & Cocktails', 'Playa', 'Festivales', 'Gym'
  ];

  XFile? _video;
  VideoPlayerController? _videoController;
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
          // Video
          if (data['videoUrl'] != null && data['videoUrl'].toString().isNotEmpty) {
            _existingVideoUrl = data['videoUrl'].toString();
          }
          // Ubicación
          if (data['location'] != null && data['location'] is GeoPoint) {
            _userLocation = data['location'] as GeoPoint;
          }
          // Objetivo
          if (data['relationshipGoal'] != null) {
            _relationshipGoal = data['relationshipGoal'].toString();
          }
          // Estilo de vida
          final lifestyle = data['lifestyle'] as Map<String, dynamic>? ?? {};
          _pets = lifestyle['pets']?.toString();
          _drinking = lifestyle['drinking']?.toString();
          _smokingTobacco = lifestyle['smokingTobacco']?.toString();
          _smokingCannabis = lifestyle['smokingCannabis']?.toString();
          _workout = lifestyle['workout']?.toString();
          _diet = lifestyle['diet']?.toString();
          _sleepPattern = lifestyle['sleepPattern']?.toString();

          // Información personal
          final personal = data['personal'] as Map<String, dynamic>? ?? {};
          _zodiac = personal['zodiac']?.toString();
          _education = personal['education']?.toString();
          _loveLanguage = personal['loveLanguage']?.toString();
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
          if (data['spotifyTrack'] != null) _spotifySongController.text = data['spotifyTrack'].toString();
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
    _spotifySongController.dispose();
    _instagramController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------
  // OBTENER UBICACIÓN OBLIGATORIA
  // -------------------------------------------------------------
  Future<bool> _requestInitialLocation() async {
    setState(() => _isLocating = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled().timeout(
        const Duration(seconds: 2),
        onTimeout: () => false,
      );
      if (!serviceEnabled) {
        if (mounted) setState(() => _isLocating = false);
        return false;
      }
      LocationPermission permission = await Geolocator.checkPermission().timeout(
        const Duration(seconds: 2),
        onTimeout: () => LocationPermission.denied,
      );
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission().timeout(
          const Duration(seconds: 5),
          onTimeout: () => LocationPermission.denied,
        );
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() => _isLocating = false);
          return false;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _isLocating = false);
        return false;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 4),
      );
      if (mounted) {
        setState(() {
          _userLocation = GeoPoint(position.latitude, position.longitude);
          _isLocating = false;
        });
      }
      return true;
    } catch (e) {
      debugPrint('Aviso geolocator: $e');
      if (mounted) setState(() => _isLocating = false);
      return false;
    }
  }

  // -------------------------------------------------------------
  // VALIDACIONES POR PASO
  // -------------------------------------------------------------
  void _nextPage() async {
    // Paso 0: Nombre y Fecha de Nacimiento
    if (_currentPage == 0) {
      if (_nameController.text.trim().isEmpty) {
        _showError('Por favor ingresa tu nombre de pila');
        return;
      }
      if (_birthDate == null) {
        _showError('Por favor selecciona tu fecha de nacimiento');
        return;
      }
      // Verificar mayoría de edad (18 años)
      final now = DateTime.now();
      int age = now.year - _birthDate!.year;
      if (now.month < _birthDate!.month || (now.month == _birthDate!.month && now.day < _birthDate!.day)) {
        age--;
      }
      if (age < 18) {
        _showError('Debes ser mayor de 18 años para usar la aplicación');
        return;
      }
    }

    // Paso 1: Género y Orientación Sexual
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

    // Paso 2: A quién quieres ver y qué buscas
    if (_currentPage == 2) {
      if (_interestedIn == null) {
        _showError('Selecciona a quién te gustaría ver');
        return;
      }
      if (_relationshipGoal == null) {
        _showError('Por favor dinos qué buscas en la app');
        return;
      }
    }

    // Paso 3: Fotos y Ubicación
    if (_currentPage == 3) {
      final uploadedCount = _photos.where((p) => p != null).length;
      if (uploadedCount < 2) {
        _showError('Es obligatorio subir al menos 2 fotos para activar tu cuenta');
        return;
      }
      if (_userLocation == null) {
        final success = await _requestInitialLocation();
        if (!success || _userLocation == null) {
          _showError('El permiso de geolocalización es obligatorio para continuar');
          return;
        }
      }
    }

    // Pasos 4 y 5 son de hábitos e información opcional, se permiten continuar/saltar directamente.

    // Paso 6: Último paso (Campos abiertos y multimedia) -> Guardar
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
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // -------------------------------------------------------------
  // SELECCIÓN DE MULTIMEDIA
  // -------------------------------------------------------------
  Future<void> _pickImage(int index) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) {
      setState(() {
        _photos[index] = image;
        _existingPhotoUrls[index] = null; // Reemplazado por nueva foto local
      });
    }
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 15),
    );
    if (video != null) {
      setState(() {
        _video = video;
      });
      _videoController?.dispose();
      if (kIsWeb) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(video.path));
      } else {
        _videoController = VideoPlayerController.file(File(video.path));
      }
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.play();
      setState(() {});
    }
  }

  // -------------------------------------------------------------
  // GUARDAR EN FIRESTORE Y STORAGE
  // -------------------------------------------------------------
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay sesión de usuario activa');

      List<String> photoUrls = [];
      String? videoUrl = _existingVideoUrl;

      // Subir fotos o conservar fotos existentes
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      for (int i = 0; i < 6; i++) {
        if (_photos[i] != null) {
          final ref = FirebaseStorage.instance.ref().child('users/${user.uid}/photos/photo_${i}_$timestamp.jpg');
          final metadata = SettableMetadata(contentType: 'image/jpeg');
          if (kIsWeb) {
            await ref.putData(await _photos[i]!.readAsBytes(), metadata);
          } else {
            await ref.putFile(File(_photos[i]!.path), metadata);
          }
          final url = await ref.getDownloadURL();
          photoUrls.add(url);
        } else if (_existingPhotoUrls[i] != null && _existingPhotoUrls[i]!.isNotEmpty) {
          photoUrls.add(_existingPhotoUrls[i]!);
        }
      }

      // Subir video si se grabó o seleccionó uno nuevo
      if (_video != null) {
        final ref = FirebaseStorage.instance.ref().child('users/${user.uid}/video/presentation.mp4');
        if (kIsWeb) {
          await ref.putData(await _video!.readAsBytes());
        } else {
          await ref.putFile(File(_video!.path));
        }
        videoUrl = await ref.getDownloadURL();
      }

      final profileData = {
        // Obligatorios iniciales
        'name': _nameController.text.trim(),
        'birthDate': _birthDate,
        'gender': _gender,
        'showGenderOnProfile': _showGenderOnProfile,
        'sexualOrientation': _sexualOrientations.toList(),
        'interestedIn': _interestedIn,
        'photoUrls': photoUrls,
        'photos': photoUrls, // Para retrocompatibilidad con mapa
        'location': _userLocation,
        'isProfileComplete': true,
        'createdAt': FieldValue.serverTimestamp(),

        // Intención de relación
        'relationshipGoal': _relationshipGoal,

        // Estilo de vida y hábitos
        'lifestyle': {
          'pets': _pets,
          'drinking': _drinking,
          'smokingTobacco': _smokingTobacco,
          'smokingCannabis': _smokingCannabis,
          'workout': _workout,
          'diet': _diet,
          'sleepPattern': _sleepPattern,
        },

        // Información personal
        'personal': {
          'zodiac': _zodiac,
          'education': _education,
          'loveLanguage': _loveLanguage,
          'familyPlans': _familyPlans,
          'communication': _communication,
          'languages': _languages.toList(),
        },

        // Campos abiertos y multimedia
        'bio': _bioController.text.trim(),
        'work': _workController.text.trim(),
        'school': _schoolController.text.trim(),
        'interests': _interests.toList(),
        'spotifyTrack': _spotifySongController.text.trim(),
        'instagramHandle': _instagramController.text.trim().replaceAll('@', ''),
        'videoUrl': videoUrl,
      };

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        profileData,
        SetOptions(merge: true),
      );

      // Actualizar foto y nombre en todas las citas publicadas activas de este usuario
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
  // CONSTRUCCIÓN DE LA VISTA
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
  // PASO 1: NOMBRE Y FECHA DE NACIMIENTO
  // -------------------------------------------------------------
  Widget _buildNameAndBirthStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comencemos con lo básico', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Tu nombre visible y tu edad no se pueden cambiar fácilmente luego.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 36),

          const Text('Nombre de pila *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 18),
            decoration: InputDecoration(
              hintText: 'Ej. Valentina o Carlos',
              hintStyle: const TextStyle(color: AppColors.textLight),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.all(18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
            ),
          ),

          const SizedBox(height: 32),
          const Text('Fecha de nacimiento *', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
                firstDate: DateTime(1920),
                lastDate: DateTime.now().subtract(const Duration(days: 365 * 18)),
                helpText: 'Selecciona tu fecha de nacimiento',
              );
              if (date != null) setState(() => _birthDate = date);
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _birthDate == null ? 'DD / MM / AAAA' : '${_birthDate!.day.toString().padLeft(2, '0')} / ${_birthDate!.month.toString().padLeft(2, '0')} / ${_birthDate!.year}',
                    style: TextStyle(fontSize: 16, color: _birthDate == null ? AppColors.textLight : AppColors.textPrimary, fontWeight: FontWeight.w500),
                  ),
                  const Icon(Icons.calendar_today, color: AppColors.primary, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Solo mostraremos tu edad calculada en tu perfil.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 2: GÉNERO Y ORIENTACIÓN SEXUAL
  // -------------------------------------------------------------
  Widget _buildGenderAndOrientationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Identidad y Orientación', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Queremos que te sientas cómodo/a y representado/a.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 28),

          const Text('¿Cuál es tu género? *', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genderOptions.map((g) {
              final isSelected = _gender == g;
              return ChoiceChip(
                label: Text(g),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                onSelected: (val) {
                  if (val) setState(() => _gender = g);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Mostrar mi género en el perfil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                Switch(
                  value: _showGenderOnProfile,
                  activeColor: AppColors.primary,
                  onChanged: (val) => setState(() => _showGenderOnProfile = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
          const Text('Orientación sexual * (Elige hasta 3)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _orientationOptions.map((ori) {
              final isSelected = _sexualOrientations.contains(ori);
              return FilterChip(
                label: Text(ori),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (_sexualOrientations.length < 3) {
                        _sexualOrientations.add(ori);
                      } else {
                        _showError('Puedes elegir máximo 3 orientaciones');
                      }
                    } else {
                      _sexualOrientations.remove(ori);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 3: PREFERENCIAS & INTENCIÓN DE RELACIÓN
  // -------------------------------------------------------------
  Widget _buildPreferencesAndIntentStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tus Expectativas', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Ayúdanos a sugerirte personas que buscan exactamente lo mismo.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 28),

          const Text('¿A quién te gustaría ver? *', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(
            children: _interestedInOptions.map((opt) {
              final isSelected = _interestedIn == opt;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: InkWell(
                    onTap: () => setState(() => _interestedIn = opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.inputBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        opt,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 32),
          const Text('¿Qué buscas en este momento? *', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          ..._relationshipGoalOptions.map((goal) {
            final isSelected = _relationshipGoal == goal['title'];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.06) : AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isSelected ? AppColors.primary : AppColors.inputBorder, width: isSelected ? 2 : 1),
              ),
              child: ListTile(
                onTap: () => setState(() => _relationshipGoal = goal['title']),
                leading: Icon(goal['icon'] as IconData, color: isSelected ? AppColors.primary : AppColors.icon),
                title: Text(goal['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                subtitle: Text(goal['desc'] as String, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
              ),
            );
          }),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 4: FOTOS (MÍNIMO 2) Y UBICACIÓN
  // -------------------------------------------------------------
  Widget _buildPhotosAndLocationStep() {
    final uploadedCount = List.generate(6, (i) => _photos[i] != null || (_existingPhotoUrls[i] != null && _existingPhotoUrls[i]!.isNotEmpty)).where((b) => b).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tus Fotos y Ubicación', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Sube al menos 2 fotos para activar tu cuenta. La primera será tu foto principal.', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          const SizedBox(height: 20),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.72,
            ),
            itemCount: 6,
            itemBuilder: (ctx, i) {
              final photo = _photos[i];
              final existingUrl = _existingPhotoUrls[i];
              final hasImage = photo != null || (existingUrl != null && existingUrl.isNotEmpty);

              return GestureDetector(
                onTap: () => _pickImage(i),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: i == 0 ? AppColors.primary : AppColors.inputBorder,
                      width: i == 0 ? 2 : 1,
                    ),
                  ),
                  child: !hasImage
                      ? Stack(
                          alignment: Alignment.center,
                          children: [
                            const Icon(Icons.add_a_photo, color: AppColors.textLight, size: 28),
                            if (i < 2)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                                  child: const Text('Requerida', style: TextStyle(color: Colors.redAccent, fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                              ),
                          ],
                        )
                      : Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: photo != null
                                  ? (kIsWeb
                                      ? Image.network(photo.path, fit: BoxFit.cover)
                                      : Image.file(File(photo.path), fit: BoxFit.cover))
                                  : Image.network(
                                      existingUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.broken_image, color: AppColors.textLight),
                                      ),
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

          const SizedBox(height: 32),
          const Text('Ubicación obligatoria *', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _userLocation != null ? Colors.green : AppColors.inputBorder),
            ),
            child: Row(
              children: [
                Icon(
                  _userLocation != null ? Icons.location_on : Icons.location_off_outlined,
                  color: _userLocation != null ? Colors.green : AppColors.icon,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _userLocation != null ? 'Ubicación concedida' : 'Ubicación no detectada',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _userLocation != null
                            ? 'Lat: ${_userLocation!.latitude.toStringAsFixed(3)}, Lng: ${_userLocation!.longitude.toStringAsFixed(3)}'
                            : 'Requerida para encontrar citas y perfiles cercanos',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (_isLocating)
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                else if (_userLocation == null)
                  TextButton(
                    onPressed: _requestInitialLocation,
                    child: const Text('Activar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 5: ESTILO DE VIDA Y HÁBITOS (OPCIONALES)
  // -------------------------------------------------------------
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
          _buildChipSelector('🥗 Alimentación / Dieta', _dietOptions, _diet, (val) => setState(() => _diet = val)),
          _buildChipSelector('⏰ Patrón de sueño', _sleepPatternOptions, _sleepPattern, (val) => setState(() => _sleepPattern = val)),
        ],
      ),
    );
  }

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
              return ChoiceChip(
                label: Text(opt),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (val) {
                  onSelected(val ? opt : null);
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 6: INFORMACIÓN PERSONAL Y ANTECEDENTES (OPCIONALES)
  // -------------------------------------------------------------
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

          _buildChipSelector('⭐ Signo del Zodiaco', _zodiacOptions, _zodiac, (val) => setState(() => _zodiac = val)),
          _buildChipSelector('🎓 Nivel de Educación', _educationOptions, _education, (val) => setState(() => _education = val)),
          _buildChipSelector('💖 Lenguaje del Amor', _loveLanguageOptions, _loveLanguage, (val) => setState(() => _loveLanguage = val)),
          _buildChipSelector('👶 Planes de Familia / Hijos', _familyPlansOptions, _familyPlans, (val) => setState(() => _familyPlans = val)),
          _buildChipSelector('💬 Estilo de Comunicación', _communicationOptions, _communication, (val) => setState(() => _communication = val)),

          const SizedBox(height: 12),
          const Text('🗣️ Idiomas que hablas (Selección múltiple)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _languagesOptions.map((lang) {
              final isSelected = _languages.contains(lang);
              return FilterChip(
                label: Text(lang),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _languages.add(lang);
                    } else {
                      _languages.remove(lang);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PASO 7: CAMPOS ABIERTOS, MULTIMEDIA Y REDES
  // -------------------------------------------------------------
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

          // Biografía (500 chars)
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
          _buildTextFieldWithIcon('💼 Trabajo / Empresa', _workController, 'Ej. Diseñador en Acme / Emprendedor', Icons.work_outline),
          const SizedBox(height: 16),
          _buildTextFieldWithIcon('🏛️ Escuela / Universidad', _schoolController, 'Ej. Universidad de los Andes', Icons.school_outlined),
          const SizedBox(height: 16),
          _buildTextFieldWithIcon('🎵 Himno de Spotify', _spotifySongController, 'Ej. Bohemian Rhapsody - Queen', Icons.music_note),
          const SizedBox(height: 16),
          _buildTextFieldWithIcon('📸 Usuario de Instagram', _instagramController, 'Ej. tu_usuario (sin @)', Icons.camera_alt_outlined),

          const SizedBox(height: 24),
          const Text('🌟 Intereses y Pasiones (Elige hasta 5)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableInterests.map((interest) {
              final isSelected = _interests.contains(interest);
              return FilterChip(
                label: Text(interest),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: AppColors.surface,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      if (_interests.length < 5) {
                        _interests.add(interest);
                      } else {
                        _showError('Puedes seleccionar máximo 5 intereses');
                      }
                    } else {
                      _interests.remove(interest);
                    }
                  });
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 28),
          const Text('🎬 Video Corto de Presentación (Opcional - 15 seg)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickVideo,
            child: Container(
              height: 180,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: _videoController != null && _videoController!.value.isInitialized
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: _videoController!.value.aspectRatio,
                        child: VideoPlayer(_videoController!),
                      ),
                    )
                  : const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_call, color: AppColors.textLight, size: 40),
                        SizedBox(height: 8),
                        Text('Sube un video corto de 15 segundos', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 20),
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
            prefixIcon: Icon(icon, color: AppColors.icon, size: 20),
            filled: true,
            fillColor: AppColors.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.inputBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.primary, width: 2)),
          ),
        ),
      ],
    );
  }
}
