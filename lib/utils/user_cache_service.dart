import 'package:cloud_firestore/cloud_firestore.dart';

/// Servicio en memoria para cachear perfiles de usuarios entre el Mapa,
/// Descubrir Personas, Solicitudes y el Modal de Perfil.
/// Permite mostrar los perfiles de forma instantánea (sin spinner de espera)
/// mientras sincroniza cambios en segundo plano.
class UserCacheService {
  UserCacheService._();

  static final Map<String, Map<String, dynamic>> _cache = {};

  /// Obtiene los datos cacheados de un usuario si ya fueron cargados previamente.
  static Map<String, dynamic>? get(String userId) {
    if (userId.isEmpty) return null;
    return _cache[userId];
  }

  /// Guarda o actualiza los datos de un usuario en la caché en memoria.
  static void put(String userId, Map<String, dynamic>? data) {
    if (userId.isEmpty || data == null) return;
    _cache[userId] = Map<String, dynamic>.from(data);
  }

  /// Consulta Firestore, actualiza la caché y devuelve el mapa de datos del usuario.
  static Future<Map<String, dynamic>?> fetch(String userId) async {
    if (userId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        put(userId, data);
        return data;
      }
    } catch (_) {}
    return _cache[userId];
  }
}

