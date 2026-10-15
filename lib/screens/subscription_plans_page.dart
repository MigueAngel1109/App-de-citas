import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/app_colors.dart';

enum SubscriptionTier { pro, proPlus }
enum BillingPeriod { semanal, mensual, trimestral }

class SubscriptionPlansPage extends StatefulWidget {
  final SubscriptionTier initialTier;

  const SubscriptionPlansPage({
    super.key,
    this.initialTier = SubscriptionTier.proPlus,
  });

  static Future<void> show(BuildContext context, {SubscriptionTier initialTier = SubscriptionTier.proPlus}) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SubscriptionPlansPage(initialTier: initialTier),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<SubscriptionPlansPage> createState() => _SubscriptionPlansPageState();
}

class _SubscriptionPlansPageState extends State<SubscriptionPlansPage> {
  late SubscriptionTier _selectedTier;
  BillingPeriod _selectedPeriod = BillingPeriod.mensual;
  bool _isProcessing = false;
  bool _showComparisonTable = false;

  @override
  void initState() {
    super.initState();
    _selectedTier = widget.initialTier;
  }

  // Precios oficiales según la tabla
  String get _currentPriceText {
    if (_selectedTier == SubscriptionTier.pro) {
      switch (_selectedPeriod) {
        case BillingPeriod.semanal:
          return r'$14.900 COP';
        case BillingPeriod.mensual:
          return r'$29.900 COP';
        case BillingPeriod.trimestral:
          return r'$69.900 COP';
      }
    } else {
      switch (_selectedPeriod) {
        case BillingPeriod.semanal:
          return r'$24.900 COP';
        case BillingPeriod.mensual:
          return r'$54.900 COP';
        case BillingPeriod.trimestral:
          return r'$119.900 COP';
      }
    }
  }

  String get _currentPerMonthText {
    if (_selectedTier == SubscriptionTier.pro) {
      switch (_selectedPeriod) {
        case BillingPeriod.semanal:
          return r'~$59.600/mes';
        case BillingPeriod.mensual:
          return r'$29.900/mes';
        case BillingPeriod.trimestral:
          return r'~$23.300/mes (Ahorra 22%)';
      }
    } else {
      switch (_selectedPeriod) {
        case BillingPeriod.semanal:
          return r'~$99.600/mes';
        case BillingPeriod.mensual:
          return r'$54.900/mes';
        case BillingPeriod.trimestral:
          return r'~$39.900/mes (Ahorra 27%)';
      }
    }
  }

  List<Color> get _tierGradient {
    if (_selectedTier == SubscriptionTier.pro) {
      return const [
        Color(0xFFFF7A00),
        Color(0xFFFF007A),
      ];
    } else {
      return const [
        Color(0xFF6366F1),
        Color(0xFF8B5CF6),
        Color(0xFFD946EF),
      ];
    }
  }

  Color get _tierAccentColor {
    return _selectedTier == SubscriptionTier.pro
        ? const Color(0xFFFF5E3A)
        : const Color(0xFF8B5CF6);
  }

  void _handleSubscribe() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inicia sesión para suscribirte')),
      );
      return;
    }

    _showPaymentBottomSheet(user);
  }

  void _showPaymentBottomSheet(User user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PaymentModal(
        tier: _selectedTier,
        period: _selectedPeriod,
        priceText: _currentPriceText,
        gradient: _tierGradient,
        onConfirmPayment: () async {
          Navigator.pop(ctx);
          await _activateSubscription(user);
        },
      ),
    );
  }

  Future<void> _activateSubscription(User user) async {
    setState(() => _isProcessing = true);

    try {
      final now = DateTime.now();
      Duration duration;
      switch (_selectedPeriod) {
        case BillingPeriod.semanal:
          duration = const Duration(days: 7);
          break;
        case BillingPeriod.mensual:
          duration = const Duration(days: 30);
          break;
        case BillingPeriod.trimestral:
          duration = const Duration(days: 90);
          break;
      }

      final expiresAt = now.add(duration);
      final tierName = _selectedTier == SubscriptionTier.pro ? 'pro' : 'pro_plus';

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'subscription': {
          'tier': tierName,
          'period': _selectedPeriod.name,
          'price': _currentPriceText,
          'status': 'active',
          'startDate': Timestamp.fromDate(now),
          'expiresAt': Timestamp.fromDate(expiresAt),
          'isVIP': true,
        },
        'plan': tierName,
        'isVerified': true,
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() => _isProcessing = false);

      _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error activando plan: $e'), backgroundColor: Colors.redAccent),
      );
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _tierGradient),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _tierAccentColor.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  _selectedTier == SubscriptionTier.pro ? Icons.workspace_premium : Icons.diamond,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                '¡Bienvenido a ${_selectedTier == SubscriptionTier.pro ? 'Almona Pro' : 'Almona Pro+'}!',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Todos los beneficios han sido activados en tu cuenta. Ya tienes ${_selectedTier == SubscriptionTier.pro ? 'hasta 3 reservas activas y solicitudes ilimitadas' : 'reservas ilimitadas y Top Prioridad VIP'}.',
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Cierra dialog
                    Navigator.pop(context); // Cierra pantalla de planes
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  child: const Text('Comenzar a Disfrutar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPro = _selectedTier == SubscriptionTier.pro;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14), // Fondo dark luxury adaptable estilo Tinder / Bumble VIP
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 540),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                  child: Column(
                    children: [
                      // Cabecera superior: Botón cerrar e indicador
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 28),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.bolt, color: _tierAccentColor, size: 16),
                                const SizedBox(width: 4),
                                const Text(
                                  'Almona Subscriptions',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 48), // Balance visual
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Selector de Pestañas Pro vs Pro+ estilo Tinder
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildTierTab(
                                tier: SubscriptionTier.pro,
                                title: 'Pro',
                                icon: Icons.workspace_premium_rounded,
                                isSelected: isPro,
                              ),
                            ),
                            Expanded(
                              child: _buildTierTab(
                                tier: SubscriptionTier.proPlus,
                                title: 'Pro+',
                                icon: Icons.diamond_rounded,
                                isSelected: !isPro,
                                badge: 'TOP VIP',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Banner Principal de la insignia seleccionada
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _tierGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: _tierAccentColor.withOpacity(0.4),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isPro ? Icons.workspace_premium_rounded : Icons.diamond_rounded,
                                color: Colors.white,
                                size: 44,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isPro ? 'Almona Pro' : 'Almona Pro+',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              isPro
                                  ? 'Multiplica tus planes, citas y visibilidad'
                                  : 'Exclusividad máxima, reservas ilimitadas y Top Prioridad',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Selector de Período (Semanal, Mensual, Trimestral) según Tabla 2
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Elige tu período de suscripción:',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildPeriodCard(
                              period: BillingPeriod.semanal,
                              title: '1 Semana',
                              price: isPro ? r'$14.900' : r'$24.900',
                              subText: 'Prueba rápida',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPeriodCard(
                              period: BillingPeriod.mensual,
                              title: '1 Mes',
                              price: isPro ? r'$29.900' : r'$54.900',
                              subText: isPro ? r'$29.900/mes' : r'$54.900/mes',
                              badgeText: 'MÁS POPULAR',
                              badgeColor: const Color(0xFFFF5E3A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildPeriodCard(
                              period: BillingPeriod.trimestral,
                              title: '3 Meses',
                              price: isPro ? r'$69.900' : r'$119.900',
                              subText: isPro ? r'~$23.300/mes' : r'~$39.900/mes',
                              badgeText: isPro ? '-22% DTO' : '-27% DTO',
                              badgeColor: const Color(0xFF10B981),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Lista de Beneficios Clave del Plan Seleccionado (Tabla 1)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Beneficios incluidos en ${isPro ? 'Pro' : 'Pro+'}:',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            TextButton.icon(
                              onPressed: () => setState(() => _showComparisonTable = !_showComparisonTable),
                              icon: Icon(
                                _showComparisonTable ? Icons.expand_less : Icons.table_chart_outlined,
                                size: 16,
                                color: _tierAccentColor,
                              ),
                              label: Text(
                                _showComparisonTable ? 'Ocultar tabla' : 'Comparar todo',
                                style: TextStyle(color: _tierAccentColor, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tarjetas de beneficios del plan seleccionado
                      ..._buildKeyBenefitsList(isPro),

                      // Tabla completa desplegable si el usuario desea ver Gratis vs Pro vs Pro+
                      if (_showComparisonTable) ...[
                        const SizedBox(height: 18),
                        _buildCompleteComparisonTable(),
                      ],

                      const SizedBox(height: 16),
                      // Notas legales y cancelación
                      Text(
                        'Los pagos se realizan en COP. Puedes administrar o cancelar tu suscripción en cualquier momento desde tu perfil.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.4), height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Barra Flotante Inferior de Compra
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F14).withOpacity(0.95),
                  border: const Border(top: BorderSide(color: Colors.white12, width: 1)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black54, blurRadius: 16, offset: Offset(0, -4)),
                  ],
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 540),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isProcessing ? null : _handleSubscribe,
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                          elevation: 8,
                          shadowColor: _tierAccentColor.withOpacity(0.5),
                        ),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: _tierGradient),
                            borderRadius: BorderRadius.circular(27),
                          ),
                          child: Center(
                            child: _isProcessing
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Continuar por $_currentPriceText',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                                        ],
                                      ),
                                      Text(
                                        _currentPerMonthText,
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.85),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierTab({
    required SubscriptionTier tier,
    required String title,
    required IconData icon,
    required bool isSelected,
    String? badge,
  }) {
    return InkWell(
      onTap: () => setState(() => _selectedTier = tier),
      borderRadius: BorderRadius.circular(26),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          border: isSelected ? Border.all(color: Colors.white30, width: 1.5) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white54,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 14,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodCard({
    required BillingPeriod period,
    required String title,
    required String price,
    required String subText,
    String? badgeText,
    Color? badgeColor,
  }) {
    final isSelected = _selectedPeriod == period;

    return InkWell(
      onTap: () => setState(() => _selectedPeriod = period),
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? _tierAccentColor : Colors.white12,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _tierAccentColor.withOpacity(0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              children: [
                if (badgeText != null) const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? _tierAccentColor : Colors.white38,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (badgeText != null)
            Positioned(
              top: -8,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? _tierAccentColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    badgeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildKeyBenefitsList(bool isPro) {
    final benefits = isPro
        ? [
            _BenefitItem(
              icon: Icons.calendar_today_rounded,
              title: 'Hasta 3 reservas simultáneas',
              desc: 'Publica y gestiona hasta 3 citas o salidas al mismo tiempo (vs 1 en gratis).',
            ),
            _BenefitItem(
              icon: Icons.all_inclusive_rounded,
              title: 'Solicitudes para unirse ilimitadas',
              desc: 'Postúlate a cuantas reservas quieras sin el límite diario de 3-5.',
            ),
            _BenefitItem(
              icon: Icons.priority_high_rounded,
              title: 'Prioridad destacada',
              desc: 'Tus postulaciones se muestran destacadas arriba en la bandeja del anfitrión.',
            ),
            _BenefitItem(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Mensaje de presentación amplio',
              desc: 'Exprésate libremente sin la restricción de 100 caracteres.',
            ),
            _BenefitItem(
              icon: Icons.visibility_outlined,
              title: 'Ver interesados en tus reservas',
              desc: 'Descubre qué personas han revisado y visitado tus planes.',
            ),
            _BenefitItem(
              icon: Icons.bolt_rounded,
              title: '1 Boost mensual de 24 horas',
              desc: 'Coloca tu plan en la cima del mapa durante un día entero.',
            ),
            _BenefitItem(
              icon: Icons.filter_alt_outlined,
              title: 'Filtros avanzados',
              desc: 'Filtra por estilo de pago (50/50, invita él/ella), edad y vibe del encuentro.',
            ),
            _BenefitItem(
              icon: Icons.shield_outlined,
              title: 'Escudo contra cancelaciones',
              desc: 'Soporte prioritario para reasignar tu plan en caso de cancelación.',
            ),
          ]
        : [
            _BenefitItem(
              icon: Icons.all_inclusive_rounded,
              title: 'Reservas activas ILIMITADAS',
              desc: 'Publica todas las salidas que quieras sin restricción alguna.',
            ),
            _BenefitItem(
              icon: Icons.star_rounded,
              title: 'Top Prioridad Absoluta',
              desc: 'Siempre en primer lugar con insignia distintiva VIP en cada postulación.',
            ),
            _BenefitItem(
              icon: Icons.record_voice_over_rounded,
              title: 'Nota de voz corta + Mensaje VIP',
              desc: 'Agrega un audio de presentación previo para generar máxima conexión.',
            ),
            _BenefitItem(
              icon: Icons.visibility_rounded,
              title: 'Ver quién visitó tu perfil y reservas',
              desc: 'Acceso total y sin borrosidad a las personas interesadas en ti.',
            ),
            _BenefitItem(
              icon: Icons.bolt_rounded,
              title: '3 Boosts mensuales + Boost en horas pico',
              desc: 'Triplica tus encuentros con máxima visibilidad en los momentos más activos.',
            ),
            _BenefitItem(
              icon: Icons.verified_user_rounded,
              title: 'Insignia VIP de Confiabilidad',
              desc: 'Sello exclusivo en tu perfil que brinda máxima seguridad y atractivo.',
            ),
            _BenefitItem(
              icon: Icons.visibility_off_rounded,
              title: 'Navegación Fantasma (Modo Incógnito)',
              desc: 'Navega en privado: solo podrán verte aquellos a quienes decidas solicitar.',
            ),
            _BenefitItem(
              icon: Icons.tune_rounded,
              title: 'Filtros Pro + Verificación prioritaria',
              desc: 'Accede a filtros de perfiles verificados y atención VIP prioritaria.',
            ),
          ];

    return benefits.map((b) => _buildBenefitRow(b)).toList();
  }

  Widget _buildBenefitRow(_BenefitItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _tierAccentColor.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon, color: _tierAccentColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  item.desc,
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tabla completa comparativa Gratis vs Pro vs Pro+ (según Imagen 1)
  Widget _buildCompleteComparisonTable() {
    final rows = [
      ['Reservas activas', '1 a la vez', 'Hasta 3 simultáneas', 'Ilimitadas'],
      ['Solicitudes diarias', '3 a 5 por día', 'Ilimitadas', 'Ilimitadas'],
      ['Prioridad postulación', 'Cronológica', 'Destacada anfitrión', 'Top Prioridad (VIP)'],
      ['Mensaje presentación', '100 caracteres', 'Personalizado amplio', 'Destacado + Nota de voz'],
      ['Ver interesados', 'Oculto / Borroso', 'Quién visitó reservas', 'Perfil + Reservas'],
      ['Boost de reserva', 'No incluido', '1 Boost mensual (24h)', '3 Boosts + Horas pico'],
      ['Filtros avanzados', 'Básicos', 'Pago 50/50, vibe, edad', 'Filtros Pro + Verificación'],
      ['Modo Incógnito', 'No', 'Ocultar en línea / leído', 'Modo Fantasma completo'],
      ['Garantía / Reputación', 'Sistema base', 'Escudo cancelaciones', 'Insignia VIP confiabilidad'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.white.withOpacity(0.08)),
            columnSpacing: 18,
            columns: const [
              DataColumn(label: Text('Característica', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Gratis', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Pro', style: TextStyle(color: Color(0xFFFF7A00), fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text('Pro+', style: TextStyle(color: Color(0xFFA855F7), fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: rows.map((r) {
              return DataRow(
                cells: [
                  DataCell(Text(r[0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600))),
                  DataCell(Text(r[1], style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11))),
                  DataCell(Text(r[2], style: const TextStyle(color: Color(0xFFFFB800), fontSize: 11, fontWeight: FontWeight.w600))),
                  DataCell(Text(r[3], style: const TextStyle(color: Color(0xFFC084FC), fontSize: 11, fontWeight: FontWeight.w700))),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _BenefitItem {
  final IconData icon;
  final String title;
  final String desc;

  _BenefitItem({required this.icon, required this.title, required this.desc});
}

// Modal de Pasarela de Pago Simulada
class _PaymentModal extends StatefulWidget {
  final SubscriptionTier tier;
  final BillingPeriod period;
  final String priceText;
  final List<Color> gradient;
  final VoidCallback onConfirmPayment;

  const _PaymentModal({
    required this.tier,
    required this.period,
    required this.priceText,
    required this.gradient,
    required this.onConfirmPayment,
  });

  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  String _selectedMethod = 'nequi';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E28),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: widget.gradient),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  widget.tier == SubscriptionTier.pro ? Icons.workspace_premium : Icons.diamond,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Suscripción ${widget.tier == SubscriptionTier.pro ? 'Almona Pro' : 'Almona Pro+'}',
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Período ${widget.period.name.toUpperCase()} • Total: ${widget.priceText}',
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12),
          const SizedBox(height: 12),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Método de Pago:',
              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 10),
          _buildPaymentMethodOption(id: 'nequi', title: 'Nequi / Daviplata', subtitle: 'Pago móvil al instante', icon: Icons.phone_android_rounded),
          _buildPaymentMethodOption(id: 'card', title: 'Tarjeta Débito / Crédito', subtitle: 'Visa, Mastercard, Amex', icon: Icons.credit_card_rounded),
          _buildPaymentMethodOption(id: 'pse', title: 'PSE', subtitle: 'Débito directo desde tu banco', icon: Icons.account_balance_rounded),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: widget.onConfirmPayment,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: Text(
                'Pagar ${widget.priceText}',
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOption({
    required String id,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedMethod == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _selectedMethod = id),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.12) : Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? Colors.white70 : Colors.white10),
          ),
          child: Row(
            children: [
              Icon(icon, color: isSelected ? Colors.white : Colors.white54, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
                  ],
                ),
              ),
              if (isSelected) const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
