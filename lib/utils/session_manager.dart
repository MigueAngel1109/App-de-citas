import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/login_page.dart';

class SessionManager {
  static const String _keyLastActive = 'session_last_active_ms';
  static const Duration sessionTimeout = Duration(minutes: 20);

  static Timer? _inactivityTimer;
  static GlobalKey<NavigatorState>? navigatorKey;
  static int _lastPersistedMs = 0;
  static bool _isExpiring = false;

  /// Registra o renueva la actividad del usuario en la app
  static Future<void> updateActivity() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _cancelTimer();
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Debounce de guardado persistente en disco (cada 15 segundos) para no sobrecargar el almacenamiento en web/móvil
    if (nowMs - _lastPersistedMs > 15000) {
      _lastPersistedMs = nowMs;
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt(_keyLastActive, nowMs);
      } catch (_) {}
    }

    _scheduleInactivityTimer();
  }

  /// Verifica si la sesión actual ha excedido los 20 minutos de inactividad
  static Future<bool> isSessionExpired() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastActiveMs = prefs.getInt(_keyLastActive);
      if (lastActiveMs == null) {
        // Primera verificación o sesión recién iniciada
        await updateActivity();
        return false;
      }

      final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMs);
      final difference = DateTime.now().difference(lastActive);

      return difference >= sessionTimeout;
    } catch (_) {
      return false;
    }
  }

  /// Ejecuta el cierre de sesión tras cumplirse los 20 minutos de inactividad
  static Future<void> expireSession({BuildContext? context}) async {
    if (_isExpiring) return;
    _isExpiring = true;

    _cancelTimer();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastActive);
    } catch (_) {}

    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    final navContext = context ?? navigatorKey?.currentContext;
    if (navContext != null && navContext.mounted) {
      ScaffoldMessenger.of(navContext).showSnackBar(
        const SnackBar(
          content: Text('⏱️ Tu sesión ha expirado por inactividad (20 min). Por favor inicia sesión nuevamente.'),
          backgroundColor: Colors.black87,
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(navContext).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }

    _isExpiring = false;
  }

  /// Limpia los datos de sesión al cerrar sesión manualmente
  static Future<void> clearSession() async {
    _cancelTimer();
    _lastPersistedMs = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastActive);
    } catch (_) {}
  }

  static void _scheduleInactivityTimer() {
    _cancelTimer();
    _inactivityTimer = Timer(sessionTimeout, () async {
      final expired = await isSessionExpired();
      if (expired) {
        await expireSession();
      }
    });
  }

  static void _cancelTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }
}
