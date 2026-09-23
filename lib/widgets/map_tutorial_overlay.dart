import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../utils/app_colors.dart';

/// Overlay único post-login con información estática para el mapa.
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
              color: Colors.black.withOpacity(0.78),
            ),
          ),

          // Contenido explicativo estático
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Indicador 1: Toggle superior
                  _buildCallout(
                    icon: Icons.swap_horiz_rounded,
                    title: 'Explora a tu ritmo',
                    description: 'Alterna arriba entre el mapa de reservas y el carrusel de personas.',
                    arrowDirection: ArrowDirection.up,
                  ),
                  const Spacer(),

                  // Indicador 2: Pines del mapa
                  _buildCallout(
                    icon: Icons.restaurant_rounded,
                    title: 'Planes y Restaurantes',
                    description: 'Toca los pines con fotos para ver los planes, fechas y quién invita.',
                    arrowDirection: ArrowDirection.center,
                  ),
                  const Spacer(),

                  // Indicador 3: Creación rápida
                  _buildCallout(
                    icon: Icons.add_circle_outline,
                    title: 'Publica tu Reserva',
                    description: 'Usa el botón central para subir tu mesa y recibir solicitudes.',
                    arrowDirection: ArrowDirection.down,
                  ),
                  const SizedBox(height: 24),

                  // Botón Entendido
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                      ),
                      child: const Text(
                        '¡Entendido, a explorar!',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallout({
    required IconData icon,
    required String title,
    required String description,
    required ArrowDirection arrowDirection,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
