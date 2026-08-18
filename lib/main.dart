                                                                                                                                                                                                                                                                                import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:url_launcher/url_launcher.dart';

// Enum para los estados de login
enum LoginState {
  inicial,
  cargando,
  exitoso,
  usuarioNoExiste,
  passwordIncorrect,
  error,
}

void main() {
  runApp(const AppPruebas());
}

// ============================================================
// COLORES DE LA APLICACIÓN
// ============================================================

class AppColors {
  // Fondo general
  static const Color background = Color(0xFFF5F5F3);

  // Tarjetas
  static const Color white = Color(0xFFFFFFFF);

  // Texto
  static const Color textPrimary = Color(0xFF111111);
  static const Color textSecondary = Color(0xFF6F6F6F);
  static const Color textLight = Color(0xFF999999);

  // Inputs
  static const Color inputBackground = Color(0xFFF7F7F7);
  static const Color inputBorder = Color(0xFFE2E2E2);

  // Botones
  static const Color primary = Color(0xFF111111);
  static const Color primaryLight = Color(0xFF333333);

  // Iconos
  static const Color icon = Color(0xFF555555);

  // Líneas
  static const Color divider = Color(0xFFE5E5E5);
}

// ============================================================
// ICONO PERSONALIZADO COPA DE MARTINI
// ============================================================

class MartiniGlassIcon extends StatelessWidget {
  final double size;
  final Color color;

  const MartiniGlassIcon({
    super.key,
    this.size = 40,
    this.color = AppColors.white,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _MartiniGlassPainter(color: color),
      ),
    );
  }
}

class _MartiniGlassPainter extends CustomPainter {
  final Color color;

  _MartiniGlassPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.065;

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // 1. Palillo (diagonal desde el interior del vaso hacia la esquina superior derecha)
    canvas.drawLine(
      Offset(w * 0.55, h * 0.44),
      Offset(w * 0.92, h * 0.08),
      strokePaint,
    );

    // 2. Aceituna en el palillo
    canvas.save();
    canvas.translate(w * 0.77, h * 0.22);
    canvas.rotate(-0.785); // -45 grados
    final oliveRect = Rect.fromCenter(
      center: Offset.zero,
      width: w * 0.20,
      height: w * 0.12,
    );
    canvas.drawOval(oliveRect, fillPaint);
    canvas.restore();

    // 3. Contorno del Vaso estilo Martini
    final bowlPath = Path()
      ..moveTo(w * 0.16, h * 0.28)
      ..lineTo(w * 0.84, h * 0.28)
      ..lineTo(w * 0.50, h * 0.60)
      ..close();
    canvas.drawPath(bowlPath, strokePaint);

    // 4. Relleno del líquido dentro de la copa
    final liquidPath = Path()
      ..moveTo(w * 0.23, h * 0.35)
      ..lineTo(w * 0.77, h * 0.35)
      ..lineTo(w * 0.50, h * 0.58)
      ..close();
    canvas.drawPath(liquidPath, fillPaint);

    // 5. Tallo vertical
    canvas.drawLine(
      Offset(w * 0.50, h * 0.60),
      Offset(w * 0.50, h * 0.88),
      strokePaint,
    );

    // 6. Base de la copa
    final basePath = Path()
      ..moveTo(w * 0.32, h * 0.94)
      ..lineTo(w * 0.68, h * 0.94)
      ..lineTo(w * 0.50, h * 0.86)
      ..close();
    canvas.drawPath(basePath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MartiniGlassPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ============================================================
// APP
// ============================================================

class AppPruebas extends StatelessWidget {
  const AppPruebas({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Conecta',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
      ),
      home: const LoginPage(),
    );
  }
}

// ============================================================
// LOGIN
// ============================================================

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool ocultarPassword = true;
  bool estaCargando = false;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // Simulador de usuarios válidos
  final Map<String, String> usuariosValidos = {
    'juan@ejemplo.com': '123456',
    'maria@ejemplo.com': 'password123',
    'usuario@test.com': 'test123',
  };

  void iniciarSesion() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrarError('Por favor completa todos los campos');
      return;
    }

    setState(() => estaCargando = true);

    // Simular verificación en servidor
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    // Validaciones
    if (!usuariosValidos.containsKey(email)) {
      setState(() => estaCargando = false);
      _mostrarError('El usuario no existe');
      return;
    }

    if (usuariosValidos[email] != password) {
      setState(() => estaCargando = false);
      _mostrarError('La contraseña es incorrecta');
      return;
    }

    // Login exitoso
    setState(() => estaCargando = false);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DiscoverPage()),
      );
    }
  }

  void _mostrarError(String mensaje) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text(
          'Error',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          mensaje,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Aceptar',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  void iniciarConGoogle() async {
    setState(() => estaCargando = true);

    // Simular autenticación con Google
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => estaCargando = false);

    // Simulamos que Google devuelve un usuario
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DiscoverPage(),
        ),
      );
    }
  }

  void iniciarConApple() async {
    setState(() => estaCargando = true);

    // Simular autenticación con Apple
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() => estaCargando = false);

    // Simulamos que Apple devuelve un usuario
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const DiscoverPage(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),

            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),

              child: Column(
                children: [
                  // ==================================================
                  // LOGO
                  // ==================================================
                  Container(
                    width: 76,
                    height: 76,

                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(24),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.10),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),

                    child: const Center(
                      child: MartiniGlassIcon(
                        size: 44,
                        color: AppColors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ==================================================
                  // TITULO
                  // ==================================================
                  const Text(
                    'Conecta',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 6),

                  const Text(
                    'Personas reales. Conexiones reales.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // TARJETA LOGIN
                  // ==================================================
                  Container(
                    padding: const EdgeInsets.all(24),

                    decoration: BoxDecoration(
                      color: AppColors.white,

                      borderRadius: BorderRadius.circular(28),

                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.07),
                          blurRadius: 30,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),

                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,

                      children: [
                        // TITULO LOGIN
                        const Text(
                          'Iniciar sesión',
                          textAlign: TextAlign.center,

                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 8),

                        const Text(
                          'Ingresa tus datos para continuar',
                          textAlign: TextAlign.center,

                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ==================================================
                        // EMAIL
                        // ==================================================
                        const Text(
                          'Correo electrónico',

                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: emailController,

                          keyboardType: TextInputType.emailAddress,

                          decoration: InputDecoration(
                            hintText: 'correo@ejemplo.com',

                            hintStyle: const TextStyle(
                              color: AppColors.textLight,
                            ),

                            prefixIcon: const Icon(
                              Icons.email_outlined,
                              color: AppColors.icon,
                            ),

                            filled: true,

                            fillColor: AppColors.inputBackground,

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: BorderSide.none,
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: const BorderSide(
                                color: AppColors.inputBorder,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ==================================================
                        // CONTRASEÑA
                        // ==================================================
                        const Text(
                          'Contraseña',

                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),

                        const SizedBox(height: 8),

                        TextField(
                          controller: passwordController,

                          obscureText: ocultarPassword,

                          decoration: InputDecoration(
                            hintText: '••••••••',

                            hintStyle: const TextStyle(
                              color: AppColors.textLight,
                            ),

                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              color: AppColors.icon,
                            ),

                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  ocultarPassword = !ocultarPassword;
                                });
                              },

                              icon: Icon(
                                ocultarPassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,

                                color: AppColors.icon,
                              ),
                            ),

                            filled: true,

                            fillColor: AppColors.inputBackground,

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: BorderSide.none,
                            ),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: const BorderSide(
                                color: AppColors.inputBorder,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ==================================================
                        // OLVIDASTE CONTRASEÑA
                        // ==================================================
                        Align(
                          alignment: Alignment.centerRight,

                          child: TextButton(
                            onPressed: () {},

                            child: const Text(
                              '¿Olvidaste tu contraseña?',

                              style: TextStyle(
                                color: AppColors.textPrimary,

                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 8),

                        // ==================================================
                        // BOTON INICIAR SESION
                        // ==================================================
                        SizedBox(
                          height: 54,

                          child: ElevatedButton(
                            onPressed: estaCargando ? null : iniciarSesion,

                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,

                              foregroundColor: AppColors.white,

                              elevation: 0,

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),

                            child: estaCargando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.white,
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Iniciar sesión',

                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 25),

                        // ==================================================
                        // DIVISOR
                        // ==================================================
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.divider,
                              ),
                            ),

                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),

                              child: Text(
                                'o continúa con',

                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 13,
                                ),
                              ),
                            ),

                            Expanded(
                              child: Container(
                                height: 1,
                                color: AppColors.divider,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // ==================================================
                        // GOOGLE
                        // ==================================================
                        SizedBox(
                          height: 52,

                          child: OutlinedButton(
                            onPressed: estaCargando ? null : iniciarConGoogle,

                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,

                              side: const BorderSide(
                                color: AppColors.inputBorder,
                              ),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),

                            child: estaCargando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,

                                    children: const [
                                      Text(
                                        'G',

                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),

                                      SizedBox(width: 10),

                                      Text(
                                        'Continuar con Google',

                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ==================================================
                        // APPLE
                        // ==================================================
                        SizedBox(
                          height: 52,

                          child: OutlinedButton(
                            onPressed: estaCargando ? null : iniciarConApple,

                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textPrimary,

                              side: const BorderSide(
                                color: AppColors.inputBorder,
                              ),

                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),

                            child: estaCargando
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary,
                                      ),
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,

                                    children: const [
                                      Icon(Icons.apple, size: 25),

                                      SizedBox(width: 10),

                                      Text(
                                        'Continuar con Apple',

                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // CREAR CUENTA
                  // ==================================================
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes una cuenta?',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text(
                          'Crear cuenta',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    'Al continuar aceptas nuestros términos y condiciones.',

                    textAlign: TextAlign.center,

                    style: TextStyle(fontSize: 11, color: AppColors.textLight),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// HOME PAGE - VISTA DESPUÉS DE LOGIN EXITOSO
// ============================================================

class HomePage extends StatelessWidget {
  final String email;

  const HomePage({super.key, required this.email});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          '¡Bienvenido!',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              _mostrarConfirmacionCierreSesion(context);
            },
            icon: const Icon(Icons.logout, color: AppColors.icon),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // TARJETA DE BIENVENIDA
              // ==================================================
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.07),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Sesión iniciada',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // ==================================================
              // SECCIÓN DE OPCIONES
              // ==================================================
              const Text(
                'Opciones disponibles',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),

              const SizedBox(height: 16),

              // Opción 1
              _construirOpcion(
                icono: Icons.calendar_today,
                titulo: 'Agendar Cita',
                descripcion: 'Programa tu próxima cita',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DiscoverPage(),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Opción 2
              _construirOpcion(
                icono: Icons.history,
                titulo: 'Mis Citas',
                descripcion: 'Ver historial de citas',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ir a mis citas')),
                  );
                },
              ),

              const SizedBox(height: 12),

              // Opción 3
              _construirOpcion(
                icono: Icons.person_outline,
                titulo: 'Perfil',
                descripcion: 'Edita tu información',
                onTap: () {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Ir a perfil')));
                },
              ),

              const SizedBox(height: 12),

              // Opción 4
              _construirOpcion(
                icono: Icons.settings,
                titulo: 'Configuración',
                descripcion: 'Ajusta tus preferencias',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ir a configuración')),
                  );
                },
              ),

              const SizedBox(height: 30),

              // ==================================================
              // BOTÓN CERRAR SESIÓN
              // ==================================================
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    _mostrarConfirmacionCierreSesion(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.red,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _construirOpcion({
    required IconData icono,
    required String titulo,
    required String descripcion,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    descripcion,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.icon),
          ],
        ),
      ),
    );
  }

  static void _mostrarConfirmacionCierreSesion(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text(
          '¿Cerrar sesión?',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          '¿Estás seguro de que deseas cerrar sesión?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const LoginPage()),
              );
            },
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// DISCOVER PAGE - VISTA PARA AGENDAR CITAS
// ============================================================
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  int _tabActual = 0;
  String zonaSeleccionada = 'Todas';
  int lugarActual = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<String> zonas = [
    'Todas',
    'Zona T',
    'Zona G',
    'Usaquén',
    'Parque 93',
  ];

  final List<Map<String, String>> lugares = [
    {
      'id': '1',
      'nombre': 'Andrés D.C.',
      'zona': 'Zona T',
      'plan': 'Cena & Tragos 🍸',
      'hora': 'Hoy 9:00 PM',
      'usuario': 'Mateo, 28',
      'bio': 'Amante de la salsa y la gastronomía.',
      'instagram': '@davidgandy_official',
      'instagram_url': 'https://www.instagram.com/davidgandy_official',
      'imagen': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?auto=format&fit=crop&w=1000&q=80',
      'avatar': 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': '2',
      'nombre': 'La Brasserie',
      'zona': 'Zona G',
      'plan': 'Vino & Cena 🍷',
      'hora': 'Hoy 8:00 PM',
      'usuario': 'Ana, 26',
      'bio': 'Arquitecta apasionada por el buen vino.',
      'instagram': '@gigihadid',
      'instagram_url': 'https://www.instagram.com/gigihadid',
      'imagen': 'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?auto=format&fit=crop&w=1000&q=80',
      'avatar': 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': '3',
      'nombre': 'El Cielo Rooftop',
      'zona': 'Parque 93',
      'plan': 'Cócteles de Autor 🍹',
      'hora': 'Mañana 7:30 PM',
      'usuario': 'Luis, 30',
      'bio': 'Me encantan las vistas nocturnas.',
      'instagram': '@seanopry55',
      'instagram_url': 'https://www.instagram.com/seanopry55',
      'imagen': 'https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=1000&q=80',
      'avatar': 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': '4',
      'nombre': 'Mini-Mal Café',
      'zona': 'Usaquén',
      'plan': 'Café & Postres ☕',
      'hora': 'Hoy 5:30 PM',
      'usuario': 'Sofia, 24',
      'bio': 'Diseñadora gráfica y catadora de café.',
      'instagram': '@kendalljenner',
      'instagram_url': 'https://www.instagram.com/kendalljenner',
      'imagen': 'https://images.unsplash.com/photo-1442512595331-e89e73853f31?auto=format&fit=crop&w=1000&q=80',
      'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': '5',
      'nombre': 'Humo Bar & Grill',
      'zona': 'Zona T',
      'plan': 'Asado & Cerveza 🍺',
      'hora': 'Mañana 8:30 PM',
      'usuario': 'Carlos, 29',
      'bio': 'Emprendedor y amante del deporte.',
      'instagram': '@davidbeckham',
      'instagram_url': 'https://www.instagram.com/davidbeckham',
      'imagen': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1000&q=80',
      'avatar': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': '6',
      'nombre': 'Oci 83',
      'zona': 'Zona G',
      'plan': 'Cena Gourmet 🍽️',
      'hora': 'Sábado 9:00 PM',
      'usuario': 'Valentina, 27',
      'bio': 'Fotógrafa y fanática del jazz.',
      'instagram': '@emrata',
      'instagram_url': 'https://www.instagram.com/emrata',
      'imagen': 'https://images.unsplash.com/photo-1544025162-d76694265947?auto=format&fit=crop&w=1000&q=80',
      'avatar': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': '7',
      'nombre': 'Apache Speakeasy',
      'zona': 'Parque 93',
      'plan': 'Tragos & Jazz 🎷',
      'hora': 'Viernes 10:00 PM',
      'usuario': 'Diego, 31',
      'bio': 'Músico descubriendo sitios secretos.',
      'instagram': '@charliehunnam',
      'instagram_url': 'https://www.instagram.com/charliehunnam',
      'imagen': 'https://images.unsplash.com/photo-1572116469696-31de0f17cc34?auto=format&fit=crop&w=1000&q=80',
      'avatar': 'https://images.unsplash.com/photo-1519085360753-af0119f7cbe7?auto=format&fit=crop&w=300&q=80',
    },
    {
      'id': '8',
      'nombre': 'Abasto Usaquén',
      'zona': 'Usaquén',
      'plan': 'Brunch de Domingo 🥞',
      'hora': 'Domingo 11:30 AM',
      'usuario': 'Camila, 25',
      'bio': 'Médica veterinaria, mimosas y mañanas.',
      'instagram': '@taylor_hill',
      'instagram_url': 'https://www.instagram.com/taylor_hill',
      'imagen': 'https://images.unsplash.com/photo-1533089860892-a7c6f0a88666?auto=format&fit=crop&w=1000&q=80',
      'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=300&q=80',
    },
  ];

  List<Map<String, String>> get _lugaresFiltrados {
    if (zonaSeleccionada == 'Todas') {
      return lugares;
    }
    final list = lugares.where((l) => l['zona'] == zonaSeleccionada).toList();
    return list.isEmpty ? lugares : list;
  }

  Future<void> _abrirInstagram(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      debugPrint('Error abriendo Instagram: $e');
    }
  }

  void _abrirImagenModal(BuildContext context, Map<String, String> lugar) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lugar['usuario'] ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lugar['nombre'] ?? '',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                      color: AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.52,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    lugar['imagen']!,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 280,
                        color: Colors.grey[200],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => _abrirInstagram(lugar['instagram_url']!),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                      shadowColor: const Color(0xFFFD1D1D).withValues(alpha: 0.4),
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF833AB4),
                            Color(0xFFFD1D1D),
                            Color(0xFFF56040),
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Instagram ${lugar['instagram']}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.open_in_new, color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _solicitarUnirse([Map<String, String>? lugarOverride]) {
    final list = _lugaresFiltrados;
    final indexSeguro = lugarActual.clamp(0, list.isEmpty ? 0 : list.length - 1);
    final lugar = lugarOverride ?? (list.isNotEmpty ? list[indexSeguro] : lugares[0]);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        title: const Text(
          'Solicitud enviada',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          '¡Hemos enviado tu solicitud a ${lugar['usuario']} para la cita en ${lugar['nombre']}!',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Aceptar',
              style: TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    switch (_tabActual) {
      case 1:
        bodyContent = _buildFavoritosView();
        break;
      case 2:
        bodyContent = _buildCitasView();
        break;
      case 3:
        bodyContent = _buildPerfilView();
        break;
      case 0:
      default:
        bodyContent = _buildDescubrirMapaView();
        break;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: bodyContent,
    );
  }

  // ============================================================
  // VISTA 0: DESCUBRIR / MAPA
  // ============================================================
  Widget _buildDescubrirMapaView() {
    return Stack(
      children: [
        // MAPA DE FONDO
        FlutterMap(
          options: MapOptions(
            initialCenter: const LatLng(4.7110, -74.0055), // Bogotá, Colombia
            initialZoom: 13.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app_pruebas',
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: const LatLng(4.7110, -74.0055),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
                Marker(
                  point: const LatLng(4.7200, -74.0100),
                  width: 40,
                  height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.restaurant,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),

        // HEADER CON BÚSQUEDA Y FILTROS (Flotante)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.95),
                border: const Border(
                  bottom: BorderSide(
                    color: AppColors.divider,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Descubrir',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.inputBorder,
                              ),
                            ),
                            child: const Icon(
                              Icons.tune,
                              color: AppColors.icon,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.inputBorder,
                              ),
                            ),
                            child: const Icon(
                              Icons.menu,
                              color: AppColors.icon,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Barra de búsqueda
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar restaurantes o zonas en E...',
                      hintStyle: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppColors.icon,
                        size: 18,
                      ),
                      isDense: true,
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.inputBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.inputBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Filtros por zonas
                  SizedBox(
                    height: 36,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: zonas.length,
                      itemBuilder: (context, index) {
                        final zona = zonas[index];
                        final estaSeleccionada = zona == zonaSeleccionada;

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: FilterChip(
                            label: Text(
                              zona,
                              style: const TextStyle(fontSize: 12),
                            ),
                            selected: estaSeleccionada,
                            onSelected: (selected) {
                              setState(() {
                                zonaSeleccionada = zona;
                              });
                            },
                            backgroundColor: AppColors.white,
                            selectedColor: AppColors.primary.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: estaSeleccionada
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: estaSeleccionada
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            side: BorderSide(
                              color: estaSeleccionada
                                  ? AppColors.primary
                                  : AppColors.inputBorder,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // TARJETA MODAL EN LA PARTE INFERIOR (CARRUSEL DE CITAS APILADAS)
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Borde superior de tarjeta apilada visible detrás (Efecto de tarjetas apiladas)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.6),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              // Tarjeta principal apilada
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 25,
                      offset: const Offset(0, -6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tirador y barra superior de navegación de citas apiladas
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                      child: Column(
                        children: [
                          Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: AppColors.inputBorder,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.primary.withValues(alpha: 0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.style, size: 13, color: AppColors.primary),
                                    const SizedBox(width: 5),
                                    Text(
                                      'CITA ${lugarActual + 1} DE ${_lugaresFiltrados.length}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.primary,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    icon: Icon(
                                      Icons.arrow_back_ios_new_rounded,
                                      size: 15,
                                      color: lugarActual > 0 ? AppColors.primary : AppColors.textLight,
                                    ),
                                    onPressed: lugarActual > 0
                                        ? () {
                                            _pageController.previousPage(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        : null,
                                  ),
                                  const SizedBox(width: 4),
                                  Row(
                                    children: List.generate(
                                      _lugaresFiltrados.length,
                                      (idx) => AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(horizontal: 2),
                                        width: idx == lugarActual ? 14 : 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: idx == lugarActual
                                              ? AppColors.primary
                                              : AppColors.inputBorder,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: const EdgeInsets.all(4),
                                    icon: Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 15,
                                      color: lugarActual < _lugaresFiltrados.length - 1
                                          ? AppColors.primary
                                          : AppColors.textLight,
                                    ),
                                    onPressed: lugarActual < _lugaresFiltrados.length - 1
                                        ? () {
                                            _pageController.nextPage(
                                              duration: const Duration(milliseconds: 300),
                                              curve: Curves.easeInOut,
                                            );
                                          }
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Carrusel PageView de tarjetas de citas
                    SizedBox(
                      height: 375,
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            lugarActual = index;
                          });
                        },
                        itemCount: _lugaresFiltrados.length,
                        itemBuilder: (context, index) {
                          final lugar = _lugaresFiltrados[index];
                          return _buildTarjetaCitaIndividual(lugar);
                        },
                      ),
                    ),

                    // Barra de navegación inferior compartida
                    _buildBottomNavBarRow(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // TARJETA INDIVIDUAL DE CITA DENTRO DEL CARRUSEL
  // ============================================================
  Widget _buildTarjetaCitaIndividual(Map<String, String> lugar) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del lugar / modelo con tap para ampliar
            GestureDetector(
              onTap: () => _abrirImagenModal(context, lugar),
              child: Container(
                width: double.infinity,
                height: 135,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.grey[200],
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Image.network(
                          lugar['imagen']!,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              color: Colors.grey[200],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[300],
                              child: Center(
                                child: Icon(
                                  Icons.local_bar,
                                  size: 40,
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Tag del tipo de plan
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            lugar['plan'] ?? 'Cita',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // Botón Instagram sobre la foto
                      Positioned(
                        bottom: 10,
                        left: 10,
                        child: GestureDetector(
                          onTap: () => _abrirInstagram(lugar['instagram_url']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF833AB4),
                                  Color(0xFFFD1D1D),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 13),
                                const SizedBox(width: 4),
                                Text(
                                  lugar['instagram']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // Toca para ampliar
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.zoom_in, color: Colors.white, size: 14),
                              SizedBox(width: 4),
                              Text(
                                'Toca para ampliar',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Info del sitio y horario
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lugar['nombre']!,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            lugar['zona']!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Icon(
                            Icons.access_time,
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            lugar['hora']!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Anfitrión con avatar e Instagram
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundImage: NetworkImage(lugar['avatar']!),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'ANFITRIÓN: ',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              lugar['usuario']!,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        if (lugar['bio'] != null)
                          Text(
                            lugar['bio']!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Botón Solicitar unirme
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _solicitarUnirse(lugar),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Solicitar unirme a ${lugar['usuario']!.split(',')[0]}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BARRA DE NAVEGACIÓN COMPARTIDA
  // ============================================================
  Widget _buildBottomNavBarRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            onPressed: () => setState(() => _tabActual = 0),
            icon: Icon(
              Icons.restaurant_menu,
              color: _tabActual == 0 ? AppColors.primary : AppColors.icon,
              size: 22,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _tabActual = 1),
            icon: Icon(
              _tabActual == 1 ? Icons.favorite : Icons.favorite_border,
              color: _tabActual == 1 ? Colors.red : AppColors.icon,
              size: 22,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _tabActual = 2),
            icon: Icon(
              _tabActual == 2 ? Icons.calendar_month : Icons.calendar_today,
              color: _tabActual == 2 ? AppColors.primary : AppColors.icon,
              size: 22,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _tabActual = 3),
            icon: Icon(
              _tabActual == 3 ? Icons.person : Icons.person_outline,
              color: _tabActual == 3 ? AppColors.primary : AppColors.icon,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // VISTA 1: FAVORITOS
  // ============================================================
  Widget _buildFavoritosView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Mis Favoritos',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lugares.length,
        itemBuilder: (context, index) {
          final lugar = lugares[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
            color: AppColors.white,
            child: InkWell(
              onTap: () => _abrirImagenModal(context, lugar),
              borderRadius: BorderRadius.circular(16),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: Container(
                      height: 140,
                      width: double.infinity,
                      child: Image.network(lugar['imagen']!, fit: BoxFit.cover),
                    ),
                  ),
                  ListTile(
                    title: Text(lugar['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${lugar['zona']!} • Anfitrión: ${lugar['usuario']!}'),
                    trailing: const Icon(Icons.favorite, color: Colors.red),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavBarRow(),
    );
  }

  // ============================================================
  // VISTA 2: MIS CITAS / EVENTOS
  // ============================================================
  Widget _buildCitasView() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        elevation: 0,
        title: const Text(
          'Mis Citas & Eventos',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: lugares.length,
        itemBuilder: (context, index) {
          final lugar = lugares[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.white,
            elevation: 1,
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                radius: 26,
                backgroundImage: NetworkImage(lugar['avatar']!),
              ),
              title: Text(lugar['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('${lugar['hora']!} • ${lugar['zona']!}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Confirmado',
                  style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNavBarRow(),
    );
  }

  // ============================================================
  // VISTA 3: PERFIL DE USUARIO / MODELO
  // ============================================================
  Widget _buildPerfilView() {
    final perfil = lugares[lugarActual];
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            children: [
              // CABECERA CON PORTADA Y AVATAR
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: 180,
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.network(
                            perfil['imagen']!,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                          const Positioned(
                            top: 16,
                            left: 20,
                            child: Text(
                              'Mi Perfil',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -45,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundImage: NetworkImage(perfil['avatar']!),
                          ),
                          Positioned(
                            bottom: 2,
                            right: 2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified_rounded,
                                color: Colors.blueAccent,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 55),

              // INFORMACIÓN DEL MODELO
              Text(
                perfil['usuario']!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${perfil['zona']!}, Bogotá',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Botón de Instagram de Supermodelo
              GestureDetector(
                onTap: () => _abrirInstagram(perfil['instagram_url']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF833AB4),
                        Color(0xFFFD1D1D),
                        Color(0xFFF56040),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFD1D1D).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        perfil['instagram']!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.open_in_new, color: Colors.white, size: 14),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ESTADÍSTICAS DEL PERFIL
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildEstadistica('4.9 ★', 'Valoración'),
                      Container(height: 30, width: 1, color: AppColors.divider),
                      _buildEstadistica('24', 'Salidas'),
                      Container(height: 30, width: 1, color: AppColors.divider),
                      _buildEstadistica('100%', 'Respuesta'),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // SOBRE MÍ
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sobre mí',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Apasionado por la gastronomía de autor, coctelería exclusiva y eventos de alta costura. Me encanta conectar con personas interesantes y compartir momentos memorables.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Intereses',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildChipInteres('🍷 Alta Cocina'),
                          _buildChipInteres('🎷 Jazz & Lounge'),
                          _buildChipInteres('🍸 Mixología'),
                          _buildChipInteres('📸 Fotografía'),
                          _buildChipInteres('✈️ Viajes'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // GALERÍA DE FOTOS
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Galería',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        TextButton(
                          onPressed: () => _abrirImagenModal(context, perfil),
                          child: const Text('Ver foto'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 110,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: lugares.length,
                        itemBuilder: (context, index) {
                          final item = lugares[index];
                          return GestureDetector(
                            onTap: () => _abrirImagenModal(context, item),
                            child: Container(
                              width: 100,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                color: Colors.grey[200],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(
                                  item['imagen']!,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // OPCIONES DE CUENTA
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildOpcionMenu(
                        icono: Icons.person_outline,
                        titulo: 'Editar Perfil',
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 50),
                      _buildOpcionMenu(
                        icono: Icons.favorite_border,
                        titulo: 'Mis Favoritos',
                        onTap: () => setState(() => _tabActual = 1),
                      ),
                      const Divider(height: 1, indent: 50),
                      _buildOpcionMenu(
                        icono: Icons.settings_outlined,
                        titulo: 'Configuración',
                        onTap: () {},
                      ),
                      const Divider(height: 1, indent: 50),
                      _buildOpcionMenu(
                        icono: Icons.logout,
                        titulo: 'Cerrar Sesión',
                        colorTexto: Colors.red,
                        colorIcono: Colors.red,
                        onTap: () {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const LoginPage()),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildBottomNavBarRow(),
    );
  }

  Widget _buildEstadistica(String valor, String etiqueta) {
    return Column(
      children: [
        Text(
          valor,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildChipInteres(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildOpcionMenu({
    required IconData icono,
    required String titulo,
    required VoidCallback onTap,
    Color colorTexto = AppColors.textPrimary,
    Color colorIcono = AppColors.icon,
  }) {
    return ListTile(
      leading: Icon(icono, color: colorIcono, size: 22),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colorTexto,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}
