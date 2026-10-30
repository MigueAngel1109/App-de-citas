import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_colors.dart';

/// Categorías y lista de prompts oficiales de la app
class PromptCategory {
  final String title;
  final String emoji;
  final List<String> prompts;

  const PromptCategory({
    required this.title,
    required this.emoji,
    required this.prompts,
  });
}

const List<PromptCategory> kProfilePromptCategories = [
  PromptCategory(
    emoji: '🎮',
    title: 'Divertidos e interactivos',
    prompts: [
      'Dos verdades y una mentira...',
      'Mi dato curioso preferido es...',
      'Cito demasiado a...',
      'Prometo que no te juzgaré si...',
    ],
  ),
  PromptCategory(
    emoji: '🍕',
    title: 'Estilo de vida y gustos',
    prompts: [
      'Mis placeres sencillos...',
      'Si pudiera comer solo una comida por el resto de mi vida...',
      'Mi domingo ideal es...',
      'Después del trabajo me puedes encontrar...',
    ],
  ),
  PromptCategory(
    emoji: '❤️',
    title: 'Valores y citas',
    prompts: [
      'La forma más rápida de llegar a mi corazón es...',
      'Green flags (señales positivas) que busco...',
      'Nos llevaremos bien si...',
      'Mi primera cita ideal sería...',
    ],
  ),
];

/// Widget para mostrar y gestionar los Prompts desplegables en el Perfil
class ProfilePromptsSection extends StatefulWidget {
  final Map<String, dynamic> prompts;
  final String? userId; // Solo requerido si isEditable es true
  final bool isEditable;

  const ProfilePromptsSection({
    super.key,
    required this.prompts,
    this.userId,
    this.isEditable = false,
  });

  @override
  State<ProfilePromptsSection> createState() => _ProfilePromptsSectionState();
}

class _ProfilePromptsSectionState extends State<ProfilePromptsSection> {
  // Guarda el estado desplegado de cada categoría
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    // Por defecto, si hay respuestas en una categoría, la expandimos
    for (final cat in kProfilePromptCategories) {
      final hasAnswers = cat.prompts.any((p) => (widget.prompts[p] ?? '').toString().trim().isNotEmpty);
      _expandedCategories[cat.title] = hasAnswers;
    }
  }

  void _abrirModalRespuesta(BuildContext context, String prompt, String currentAnswer) {
    if (widget.userId == null) return;
    final textController = TextEditingController(text: currentAnswer);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Icon(Icons.forum_outlined, color: AppColors.primary, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Pregunta de Perfil',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    prompt,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: textController,
                  maxLines: 3,
                  maxLength: 250,
                  autofocus: true,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Escribe tu respuesta sincera y divertida aquí...',
                    hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.inputBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (currentAnswer.isNotEmpty) ...[
                      IconButton(
                        tooltip: 'Eliminar respuesta',
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _guardarRespuesta(prompt, '');
                        },
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final newAnswer = textController.text.trim();
                          Navigator.pop(ctx);
                          await _guardarRespuesta(prompt, newAnswer);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Guardar',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _guardarRespuesta(String prompt, String answer) async {
    if (widget.userId == null) return;
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(widget.userId);
      if (answer.isEmpty) {
        await userRef.update({
          'prompts.$prompt': FieldValue.delete(),
        });
      } else {
        await userRef.set({
          'prompts': {
            prompt: answer,
          },
        }, SetOptions(merge: true));
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(answer.isEmpty ? 'Prompt eliminado' : '¡Prompt guardado con éxito! 🎉'),
            backgroundColor: Colors.black87,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si no es editable y no tiene ninguna respuesta, no mostramos nada
    if (!widget.isEditable) {
      final hasAnyAnswer = widget.prompts.values.any((val) => (val ?? '').toString().trim().isNotEmpty);
      if (!hasAnyAnswer) return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Encabezado de la sección
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Rompehielos',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            if (widget.isEditable)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.touch_app_outlined, size: 13, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.prompts.values.where((v) => (v ?? '').toString().trim().isNotEmpty).length} respondidos',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.isEditable
              ? 'Toca cualquier categoría para desplegar y responder preguntas que romperán el hielo con tus citas.'
              : 'Respuestas y reflexiones para conocer mejor a esta persona.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.3),
        ),
        const SizedBox(height: 12),

        // Lista de categorías desplegables
        ...kProfilePromptCategories.map((cat) {
          final answeredInThisCat = cat.prompts.where((p) {
            final ans = (widget.prompts[p] ?? '').toString().trim();
            return ans.isNotEmpty;
          }).toList();

          // En modo lectura (!isEditable), ocultamos categorías que no tengan respuestas
          if (!widget.isEditable && answeredInThisCat.isEmpty) {
            return const SizedBox.shrink();
          }

          final isExpanded = _expandedCategories[cat.title] ?? false;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isExpanded ? AppColors.primary.withValues(alpha: 0.4) : AppColors.inputBorder,
                width: isExpanded ? 1.4 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Column(
                children: [
                  // Cabecera desplegable de la categoría
                  InkWell(
                    onTap: () {
                      setState(() {
                        _expandedCategories[cat.title] = !isExpanded;
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(cat.emoji, style: const TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  answeredInThisCat.isEmpty
                                      ? '${cat.prompts.length} disponibles'
                                      : '${answeredInThisCat.length}/${cat.prompts.length} respondidos',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: answeredInThisCat.isNotEmpty ? FontWeight.w600 : FontWeight.normal,
                                    color: answeredInThisCat.isNotEmpty ? AppColors.primary : AppColors.textLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: const Icon(Icons.keyboard_arrow_down, color: AppColors.textSecondary, size: 22),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Contenido expandido con los prompts individuales
                  if (isExpanded) ...[
                    const Divider(height: 1, color: AppColors.divider),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: cat.prompts.map((prompt) {
                          final answer = (widget.prompts[prompt] ?? '').toString().trim();
                          final hasAnswer = answer.isNotEmpty;

                          // Si estamos en modo lectura y no está respondida, la omitimos
                          if (!widget.isEditable && !hasAnswer) {
                            return const SizedBox.shrink();
                          }

                          return Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: hasAnswer ? AppColors.primary.withValues(alpha: 0.04) : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: hasAnswer ? AppColors.primary.withValues(alpha: 0.25) : AppColors.inputBorder,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Pregunta del Prompt
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        prompt,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13.5,
                                          color: hasAnswer ? AppColors.primary : AppColors.textPrimary,
                                        ),
                                      ),
                                    ),
                                    if (widget.isEditable)
                                      InkWell(
                                        onTap: () => _abrirModalRespuesta(context, prompt, answer),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            hasAnswer ? Icons.edit_note : Icons.add_circle_outline,
                                            size: 20,
                                            color: hasAnswer ? AppColors.primary : AppColors.textSecondary,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                // Respuesta si existe
                                if (hasAnswer) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('“', style: TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold, height: 1)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            answer,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppColors.textPrimary,
                                              height: 1.35,
                                              fontStyle: FontStyle.italic,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Text('”', style: TextStyle(fontSize: 18, color: AppColors.primary, fontWeight: FontWeight.bold, height: 1)),
                                      ],
                                    ),
                                  ),
                                ] else if (widget.isEditable) ...[
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () => _abrirModalRespuesta(context, prompt, ''),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.add, size: 14, color: AppColors.primary),
                                          SizedBox(width: 4),
                                          Text(
                                            'Toca para responder...',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

/// Tarjeta moderna tipo Hinge / Bumble para mostrar los prompts respondidos entre las fotos
class AnsweredPromptsCards extends StatelessWidget {
  final Map<String, dynamic> prompts;

  const AnsweredPromptsCards({super.key, required this.prompts});

  static bool hasAnyAnswer(dynamic promptsData) {
    if (promptsData == null || promptsData is! Map) return false;
    return promptsData.values.any((val) => (val ?? '').toString().trim().isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    final answered = <MapEntry<String, String>>[];
    for (final entry in prompts.entries) {
      final q = entry.key.toString().trim();
      final a = entry.value?.toString().trim() ?? '';
      if (a.isNotEmpty) {
        answered.add(MapEntry(q, a));
      }
    }

    if (answered.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: answered.map((entry) {
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.inputBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.chat_bubble_rounded, size: 14, color: AppColors.primary),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                entry.value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

