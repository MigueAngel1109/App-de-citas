import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../utils/app_colors.dart';
import '../widgets/martini_icon.dart';
import 'home_page.dart';
import 'profile_setup_page.dart';

// Enum para los estados de login
enum LoginState {
  inicial,
  cargando,
  exitoso,
  usuarioNoExiste,
  passwordIncorrect,
  error,
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

  bool esRegistro = false;
  final TextEditingController confirmPasswordController = TextEditingController();
  bool ocultarConfirmPassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void iniciarSesion() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrarMensaje('Por favor completa todos los campos', esError: true);
      return;
    }

    setState(() => estaCargando = true);

    try {
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (!mounted) return;
      await _manejarNavegacion(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      setState(() => estaCargando = false);
      String mensaje = 'Error al iniciar sesión';
      if (e.code == 'user-not-found' || e.code == 'invalid-credential') {
        mensaje = 'El usuario no existe o la contraseña es incorrecta';
      } else if (e.code == 'wrong-password') {
        mensaje = 'La contraseña es incorrecta';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El formato del correo es inválido';
      } else if (e.code == 'user-disabled') {
        mensaje = 'Esta cuenta ha sido inhabilitada';
      } else if (e.code == 'too-many-requests') {
        mensaje = 'Demasiados intentos fallidos. Intenta más tarde.';
      } else if (e.code == 'operation-not-allowed') {
        mensaje = 'El proveedor de inicio de sesión por correo aún no está activo en Firebase';
      }
      _mostrarMensaje(mensaje, esError: true);
    } catch (e) {
      setState(() => estaCargando = false);
      _mostrarMensaje('Ocurrió un error inesperado', esError: true);
    }
  }

  void registrarUsuario() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _mostrarMensaje('Por favor completa todos los campos', esError: true);
      return;
    }

    if (password.length < 6) {
      _mostrarMensaje('La contraseña debe tener al menos 6 caracteres', esError: true);
      return;
    }

    if (password != confirmPassword) {
      _mostrarMensaje('Las contraseñas no coinciden', esError: true);
      return;
    }

    setState(() => estaCargando = true);

    try {
      final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      if (!mounted) return;
      await _manejarNavegacion(userCredential.user!);
    } on FirebaseAuthException catch (e) {
      setState(() => estaCargando = false);
      String mensaje = 'Error al crear la cuenta';
      if (e.code == 'weak-password') {
        mensaje = 'La contraseña es muy débil (mínimo 6 caracteres)';
      } else if (e.code == 'email-already-in-use') {
        mensaje = 'Ya existe una cuenta con este correo';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El formato del correo es inválido';
      } else if (e.code == 'operation-not-allowed') {
        mensaje = 'El registro por correo no está habilitado en Firebase';
      }
      _mostrarMensaje(mensaje, esError: true);
    } catch (e) {
      setState(() => estaCargando = false);
      _mostrarMensaje('Ocurrió un error inesperado: $e', esError: true);
    }
  }

  void recuperarPassword() async {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      _mostrarMensaje('Ingresa tu correo para enviarte el enlace de recuperación', esError: true);
      return;
    }

    setState(() => estaCargando = true);
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() => estaCargando = false);
      _mostrarMensaje('Hemos enviado un enlace a tu correo para restablecer tu contraseña.', esError: false, titulo: 'Correo enviado');
    } on FirebaseAuthException catch (e) {
      setState(() => estaCargando = false);
      String mensaje = 'No se pudo enviar el correo';
      if (e.code == 'user-not-found') {
        mensaje = 'No existe una cuenta registrada con este correo';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El formato del correo es inválido';
      }
      _mostrarMensaje(mensaje, esError: true);
    } catch (e) {
      setState(() => estaCargando = false);
      _mostrarMensaje('Error al enviar solicitud', esError: true);
    }
  }

  void _mostrarMensaje(String mensaje, {bool esError = false, String? titulo}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          titulo ?? (esError ? 'Error' : 'Información'),
          style: TextStyle(
            color: esError ? Colors.redAccent : AppColors.textPrimary,
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
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _manejarNavegacion(User user) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!mounted) return;
      
      setState(() => estaCargando = false);

      if (doc.exists && doc.data()?['isProfileComplete'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomePage(email: user.email ?? '')),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileSetupPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => estaCargando = false);
        _mostrarMensaje('Error verificando perfil', esError: true);
      }
    }
  }

  void iniciarConGoogle() async {
    setState(() => estaCargando = true);

    try {
      User? user;
      if (kIsWeb) {
        GoogleAuthProvider googleProvider = GoogleAuthProvider();
        final userCred = await FirebaseAuth.instance.signInWithPopup(googleProvider);
        user = userCred.user;
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        
        if (googleUser == null) {
          if (mounted) setState(() => estaCargando = false);
          return;
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
        user = userCred.user;
      }

      if (!mounted) return;
      if (user != null) {
        await _manejarNavegacion(user);
      } else {
        setState(() => estaCargando = false);
      }
    } catch (e) {
      debugPrint('Error detallado Google Sign-In: $e');
      if (mounted) {
        setState(() => estaCargando = false);
        _mostrarMensaje('Error con Google: $e', esError: true);
      }
    }
  }

  void iniciarConApple() async {
    setState(() => estaCargando = true);

    try {
      User? user;
      if (kIsWeb) {
        final appleProvider = OAuthProvider('apple.com');
        appleProvider.addScope('email');
        appleProvider.addScope('name');
        final userCred = await FirebaseAuth.instance.signInWithPopup(appleProvider);
        user = userCred.user;
      } else {
        final AuthorizationCredentialAppleID appleCredential =
            await SignInWithApple.getAppleIDCredential(
          scopes: [
            AppleIDAuthorizationScopes.email,
            AppleIDAuthorizationScopes.fullName,
          ],
        );

        final OAuthCredential credential = OAuthProvider('apple.com').credential(
          idToken: appleCredential.identityToken,
          accessToken: appleCredential.authorizationCode,
        );

        final userCred = await FirebaseAuth.instance.signInWithCredential(credential);
        user = userCred.user;
      }

      if (!mounted) return;
      if (user != null) {
        await _manejarNavegacion(user);
      } else {
        setState(() => estaCargando = false);
      }
    } catch (e) {
      if (mounted) setState(() => estaCargando = false);
      _mostrarMensaje('Error al iniciar con Apple', esError: true);
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
                        // SELECTOR DE MODO (INICIAR SESIÓN / CREAR CUENTA)
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppColors.inputBackground,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (esRegistro) setState(() => esRegistro = false);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: !esRegistro ? AppColors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: !esRegistro
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.06),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      'Iniciar sesión',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: !esRegistro ? FontWeight.w700 : FontWeight.w500,
                                        color: !esRegistro ? AppColors.textPrimary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (!esRegistro) setState(() => esRegistro = true);
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      color: esRegistro ? AppColors.white : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: esRegistro
                                          ? [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.06),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : [],
                                    ),
                                    child: Text(
                                      'Crear cuenta',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: esRegistro ? FontWeight.w700 : FontWeight.w500,
                                        color: esRegistro ? AppColors.textPrimary : AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        Text(
                          esRegistro
                              ? 'Crea tu perfil y empieza a conectar'
                              : 'Ingresa tus datos para continuar',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),

                        const SizedBox(height: 24),

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
                            hintText: esRegistro ? 'Mínimo 6 caracteres' : '••••••••',

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

                        if (esRegistro) ...[
                          const SizedBox(height: 18),
                          const Text(
                            'Confirmar contraseña',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: confirmPasswordController,
                            obscureText: ocultarConfirmPassword,
                            decoration: InputDecoration(
                              hintText: 'Repite tu contraseña',
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
                                    ocultarConfirmPassword = !ocultarConfirmPassword;
                                  });
                                },
                                icon: Icon(
                                  ocultarConfirmPassword
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
                        ],

                        if (!esRegistro) ...[
                          const SizedBox(height: 8),
                          // OLVIDASTE CONTRASEÑA
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: estaCargando ? null : recuperarPassword,
                              child: const Text(
                                '¿Olvidaste tu contraseña?',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 12),

                        // ==================================================
                        // BOTON PRINCIPAL (INICIAR SESIÓN O REGISTRARSE)
                        // ==================================================
                        SizedBox(
                          height: 54,

                          child: ElevatedButton(
                            onPressed: estaCargando
                                ? null
                                : (esRegistro ? registrarUsuario : iniciarSesion),

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
                                : Text(
                                    esRegistro ? 'Crear cuenta' : 'Iniciar sesión',

                                    style: const TextStyle(
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

                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ==================================================
                  // CAMBIAR DE MODO INFERIOR
                  // ==================================================
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        esRegistro ? '¿Ya tienes una cuenta?' : '¿No tienes una cuenta?',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      TextButton(
                        onPressed: estaCargando
                            ? null
                            : () {
                                setState(() => esRegistro = !esRegistro);
                              },
                        child: Text(
                          esRegistro ? 'Iniciar sesión' : 'Crear cuenta',
                          style: const TextStyle(
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

