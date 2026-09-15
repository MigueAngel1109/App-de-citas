import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

// ============================================================
// CHAT DETALLE - PANTALLA DE CHAT INDIVIDUAL CON ANFITRIÓN
// ============================================================

class ChatDetailPage extends StatefulWidget {
  final Map<String, String> lugar;

  const ChatDetailPage({super.key, required this.lugar});

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _mensajeController = TextEditingController();
  final List<Map<String, dynamic>> _mensajes = [];

  @override
  void initState() {
    super.initState();
    // Mensajes iniciales del anfitrión
    _mensajes.addAll([
      {
        'texto': '¡Hola! Qué gusto saludarte 👋🏼 Confirmadísima nuestra reserva en ${widget.lugar['nombre']} (${widget.lugar['hora']}).',
        'esMio': false,
        'hora': '8:30 PM',
      },
      {
        'texto': '¿Tienes alguna preferencia de mesa o bebida para ir pidiendo?',
        'esMio': false,
        'hora': '8:31 PM',
      },
    ]);
  }

  @override
  void dispose() {
    _mensajeController.dispose();
    super.dispose();
  }

  void _enviarMensaje() {
    final texto = _mensajeController.text.trim();
    if (texto.isEmpty) return;

    final horaActual = '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}';

    setState(() {
      _mensajes.add({
        'texto': texto,
        'esMio': true,
        'hora': horaActual,
      });
    });

    _mensajeController.clear();

    // Simular respuesta del anfitrión tras 1.2 segundos
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final respuestasSimuladas = [
        '¡Genial! Me parece una excelente idea 😊',
        'Perfecto, te veo allá puntual 👌🏼',
        '¡Excelente! Ya agendé todo para que sea una gran velada 🥂',
        '¡Súper! Nos vemos pronto en ${widget.lugar['nombre']} 🍸',
      ];
      final respuesta = (respuestasSimuladas..shuffle()).first;

      setState(() {
        _mensajes.add({
          'texto': respuesta,
          'esMio': false,
          'hora': '${TimeOfDay.now().hour}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}',
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final usuarioNombre = widget.lugar['usuario'] ?? 'Anfitrión';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(widget.lugar['avatar']!),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    usuarioNombre,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'En línea • ${widget.lugar['nombre']}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_outlined, color: AppColors.primary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Llamando a $usuarioNombre...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.camera_alt_outlined, color: Color(0xFFFD1D1D)),
            onPressed: () {
              final url = widget.lugar['instagram_url'];
              if (url != null) {
                final Uri uri = Uri.parse(url);
                launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner de info de la reserva arriba del chat
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primary.withOpacity(0.05),
            child: Row(
              children: [
                const Icon(Icons.event_available_rounded, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reserva confirmada: ${widget.lugar['nombre']} (${widget.lugar['hora']})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de mensajes
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                final msg = _mensajes[index];
                final esMio = msg['esMio'] as bool;

                return Align(
                  alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: esMio ? AppColors.primary : AppColors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(esMio ? 18 : 4),
                        bottomRight: Radius.circular(esMio ? 4 : 18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment:
                          esMio ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Text(
                          msg['texto'],
                          style: TextStyle(
                            color: esMio ? AppColors.white : AppColors.textPrimary,
                            fontSize: 14,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          msg['hora'],
                          style: TextStyle(
                            color: esMio
                                ? AppColors.white.withOpacity(0.7)
                                : AppColors.textLight,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Barra de entrada de texto
          SafeArea(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.white,
                border: Border(
                  top: BorderSide(color: AppColors.divider),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: AppColors.icon),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Adjuntar foto o ubicación')),
                      );
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _mensajeController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Escribe un mensaje...',
                        hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 14),
                        filled: true,
                        fillColor: AppColors.inputBackground,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _enviarMensaje(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: AppColors.primary,
                    radius: 22,
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: AppColors.white, size: 18),
                      onPressed: _enviarMensaje,
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
}
