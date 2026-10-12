import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:ui';
import '../../services/auth_service.dart';
import '../../core/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _bgController;

  bool get _isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux);

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn(String provider) async {
    setState(() => _isLoading = true);
    try {
      if (provider == 'Continue as Guest') {
        await ref.read(authServiceProvider).signInAnonymously();
      } else if (provider == 'Continue with Google') {
        if (_isDesktop) {
          await _handleDesktopGoogleSignIn();
          return;
        }
        await ref.read(authServiceProvider).signInWithGoogle();
      } else if (provider == 'Continue with Apple') {
        await ref.read(authServiceProvider).signInWithApple();
      } else if (provider == 'Telefon ile Hızlı Bağlan (QR Kod)') {
        await _showDesktopPairDialog();
      } else if (provider == 'Continue with Mail/Password') {
        await _showEmailPasswordDialog();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red[800],
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openBrowser(String url) {
    if (Platform.isWindows) {
      Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isLinux) {
      Process.run('xdg-open', [url]);
    }
  }

  Future<void> _handleDesktopGoogleSignIn() async {
    final authService = ref.read(authServiceProvider);
    setState(() => _isLoading = true);
    String? pairCode;
    try {
      pairCode = await authService.createDevicePairSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Google oturumu başlatılamadı: $e')),
        );
      }
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = false);
    if (!mounted) return;

    final authUrl = 'https://mozemusic.web.app/auth.html?session=$pairCode';
    _openBrowser(authUrl);

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StreamBuilder(
          stream: authService.listenToPairSession(pairCode!),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            if (data != null && data['status'] == 'approved') {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (!mounted) return;
                setState(() => _isLoading = true);
                try {
                  await authService.completePairOnDesktop(pairCode!, data);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Giriş tamamlama hatası: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              });

              return AlertDialog(
                backgroundColor: AppTheme.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 16),
                    Icon(Icons.check_circle_rounded, color: Color(0xFF1DB954), size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Giriş Başarılı!',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Masaüstü MozeMusic açılıyor...', style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 16),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF181818),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.g_mobiledata_rounded, color: Colors.white, size: 36),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Google ile Giriş Yap',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'İnternet tarayıcınızda (Chrome/Edge) Google oturum açma sayfası açıldı.',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Lütfen tarayıcı penceresinden Google hesabınızı seçin.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Color(0xFF1DB954)),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Tarayıcıdan onay bekleniyor...',
                        style: TextStyle(color: Color(0xFF1DB954), fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: () => _openBrowser(authUrl),
                    icon: const Icon(Icons.open_in_browser, color: Colors.white70, size: 18),
                    label: const Text('Tarayıcıyı Tekrar Aç', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showDesktopPairDialog() async {
    final authService = ref.read(authServiceProvider);
    setState(() => _isLoading = true);
    String? pairCode;
    try {
      pairCode = await authService.createDevicePairSession();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Eşleşme oturumu başlatılamadı: $e')),
        );
      }
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    if (mounted) setState(() => _isLoading = false);

    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return StreamBuilder(
          stream: authService.listenToPairSession(pairCode!),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            if (data != null && data['status'] == 'approved') {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (!mounted) return;
                setState(() => _isLoading = true);
                try {
                  await authService.completePairOnDesktop(pairCode!, data);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(content: Text('Oturum tamamlama hatası: $e')),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              });

              return AlertDialog(
                backgroundColor: AppTheme.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 16),
                    Icon(Icons.check_circle_rounded, color: Color(0xFF1DB954), size: 64),
                    SizedBox(height: 16),
                    Text(
                      'Giriş Başarılı!',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Masaüstü oturumu açılıyor...', style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 16),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF181818),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1DB954), size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Google / Telefon ile Giriş',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Telefonunuzdaki MozeMusic uygulamasında Profil > "Moze Connect" seçeneğine dokunarak bu QR kodu tarayın veya aşağıdaki 6 haneli kodu girin:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1DB954).withValues(alpha: 0.25),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: QrImageView(
                      data: pairCode!,
                      version: QrVersions.auto,
                      size: 180.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Eşleşme Kodu: ',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                        Text(
                          pairCode,
                          style: const TextStyle(
                            color: Color(0xFF1DB954),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954)),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Telefondan onay bekleniyor...',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showEmailPasswordDialog() async {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surfaceLight,
          title: const Text('Sign In or Register', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Email', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
              TextField(
                controller: passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Password', labelStyle: TextStyle(color: AppTheme.textSecondary)),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await ref.read(authServiceProvider).createUserWithEmailPassword(
                    emailController.text.trim(),
                    passwordController.text,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  final msg = e.toString().replaceFirst('Exception: ', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red[800]),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Register', style: TextStyle(color: AppTheme.redAccent)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redAccent),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);
                try {
                  await ref.read(authServiceProvider).signInWithEmailPassword(
                    emailController.text.trim(),
                    passwordController.text,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  final msg = e.toString().replaceFirst('Exception: ', '');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(msg), backgroundColor: Colors.red[800]),
                  );
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              },
              child: const Text('Login', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background
          AnimatedBuilder(
            animation: _bgController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _bgController.value * 2 * pi,
                child: Transform.scale(
                  scale: 2.0,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: SweepGradient(
                        colors: [
                          AppTheme.backgroundBlack,
                          AppTheme.redAccent,
                          AppTheme.backgroundBlack,
                          Color(0xFFB71C1C), // Colors.red[900]
                          AppTheme.backgroundBlack,
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          // Glassmorphism blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
              child: Container(color: AppTheme.backgroundBlack.withValues(alpha: 0.4)),
            ),
          ),
          
          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo
                      Center(
                        child: Image.asset('assets/logo.png', width: 90, height: 90)
                            .animate(onPlay: (controller) => controller.repeat())
                            .shimmer(duration: 2.seconds, color: AppTheme.redAccent.withValues(alpha: 0.5)),
                      ).animate().fade(duration: 800.ms).scale(curve: Curves.easeOutBack),
                      const SizedBox(height: 20),
                      
                      // Title
                      const Text(
                        'MozeMusic',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2),
                      ).animate().fade(delay: 200.ms).slideY(begin: 0.5, curve: Curves.easeOut),
                      
                      const SizedBox(height: 6),
                      const Text(
                        'Feel the rhythm, join the jam.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                      ).animate().fade(delay: 300.ms).slideY(begin: 0.5, curve: Curves.easeOut),
                      
                      const SizedBox(height: 36),
                      
                      // Auth Buttons
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                        )
                      else ...[
                        _buildAuthButton(
                          'Continue with Google',
                          Icons.g_mobiledata_rounded,
                          Colors.white,
                          Colors.black87,
                          isGoogle: true,
                        ),
                        const SizedBox(height: 12),
                        _buildAuthButton(
                          'Continue with Mail/Password',
                          Icons.email_outlined,
                          AppTheme.surfaceLight,
                          Colors.white,
                        ),
                        const SizedBox(height: 12),
                        _buildAuthButton(
                          'Continue as Guest',
                          Icons.person_outline_rounded,
                          AppTheme.redAccent,
                          Colors.white,
                        ),
                        if (!_isDesktop) ...[
                          const SizedBox(height: 12),
                          _buildAuthButton(
                            'Continue with Apple',
                            Icons.apple,
                            Colors.white,
                            Colors.black,
                          ),
                        ],
                        if (_isDesktop) ...[
                          const SizedBox(height: 18),
                          Center(
                            child: TextButton.icon(
                              onPressed: () => _showDesktopPairDialog(),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white70,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              ),
                              icon: const Icon(Icons.qr_code_2_rounded, size: 18, color: Color(0xFF1DB954)),
                              label: const Text(
                                'Telefon ile Hızlı Bağlan (Moze Connect QR)',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ].animate(interval: 80.ms).fade(delay: 500.ms).slideY(begin: 0.15),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthButton(
    String text,
    IconData icon,
    Color bgColor,
    Color fgColor, {
    bool isGoogle = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleSignIn(text),
        borderRadius: BorderRadius.circular(30),
        highlightColor: Colors.white.withValues(alpha: 0.1),
        splashColor: Colors.white.withValues(alpha: 0.2),
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isGoogle ? Colors.transparent : Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: isGoogle
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isGoogle)
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'G',
                    style: TextStyle(
                      color: Color(0xFF4285F4),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                )
              else
                Icon(icon, color: fgColor, size: 24),
              const SizedBox(width: 12),
              Text(
                text,
                style: TextStyle(
                  color: fgColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
