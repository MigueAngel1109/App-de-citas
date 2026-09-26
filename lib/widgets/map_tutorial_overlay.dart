import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Overlay único post-login con tarjeta de bienvenida y 5 módulos en blanco y negro.
class MapTutorialOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const MapTutorialOverlay({super.key, required this.onDismiss});

  static Future<void> markAsSeen() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'hasSeenMapTutorial': true,
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Error marking tutorial as seen: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Fondo oscuro semitransparente
          GestureDetector(
            onTap: onDismiss,
            child: Container(
              color: Colors.black.withOpacity(0.80),
            ),
          ),

          // Contenido explicativo estático y responsive
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 72,   // Baja el grupo para quedar despejado debajo del selector "Reservas en Mapa / Descubrir Personas"
                bottom: 160, // Arriba del botón "Hacer reserva" del mapa
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Tarjeta de bienvenida destacada
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.22)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.auto_awesome, color: Colors.amberAccent, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Bienvenido a Conecta!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Guía rápida de los 5 módulos de la app',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Lista de las 5 tarjetas explicativas en blanco y negro
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        children: [
                          _buildCallout(
                            iconWidget: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF212121), size: 22),
                            title: 'Explora a tu ritmo',
                            description: 'Alterna arriba entre el mapa de reservas y el carrusel de personas.',
                          ),
                          const SizedBox(height: 8),
                          _buildCallout(
                            iconWidget: const Icon(Icons.restaurant_rounded, color: Color(0xFF212121), size: 22),
                            title: 'Planes y Restaurantes',
                            description: 'Toca los pines con fotos para ver los planes, fechas y quién invita.',
                          ),
                          const SizedBox(height: 8),
                          _buildCallout(
                            iconWidget: const Icon(Icons.calendar_month, color: Color(0xFF212121), size: 22),
                            title: 'Publica tu Reserva',
                            description: 'Usa el botón de hacer reserva para subir tu mesa y recibir solicitudes.',
                          ),
                          const SizedBox(height: 8),
                          _buildCallout(
                            iconWidget: const Icon(Icons.favorite, color: Color(0xFF212121), size: 22),
                            title: 'Módulo de Citas',
                            description: 'Revisa solicitudes de citas, confirma tus salidas y chatea con tus acompañantes.',
                          ),
                          const SizedBox(height: 8),
                          _buildCallout(
                            iconWidget: const Icon(Icons.person, color: Color(0xFF212121), size: 22),
                            title: 'Módulo de Perfil',
                            description: 'Personaliza tus fotos, intereses, estilo de vida y personalidad MBTI.',
                          ),
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Botón Entendido negro, posicionado arriba de "Hacer reserva"
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF141414),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text(
                        '¡Entendido, a explorar!',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
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

  Widget _buildCallout({
    required Widget iconWidget,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: iconWidget,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF666666),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum ArrowDirection { up, center, down }
