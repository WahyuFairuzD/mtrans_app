import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../widgets/branch_selection_sheet.dart';
import '../../theme/app_theme.dart';
import 'register_page.dart';
import 'verify_otp_page.dart';

const _red = Color(0xFFD9191F);
const _redTop = Color(0xFFA8132B);
const _redBottom = Color(0xFF6E0A1A);

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;
  bool _remember = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _email.text.trim();

    try {
      await AuthService.instance.login(
        email: email,
        password: _password.text,
        selectBranch: () => selectAttendanceBranch(context),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      if (e.isEmailNotVerified) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VerifyOtpPage(email: email, sendCodeOnOpen: true),
          ),
        );
      } else {
        setState(() => _error = e.message);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint, IconData icon, [Widget? suffix]) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c, width: w),
    );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
      prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(_red, 1.5),
      errorBorder: border(Colors.red),
      focusedErrorBorder: border(_red, 1.5),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_redTop, _redBottom],
          ),
        ),
        child: Stack(
          children: [
            // Garis gelombang dekoratif
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 380,
              child: CustomPaint(painter: _WavePainter()),
            ),
            SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Bagian atas (logo + subtitle)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 24,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    _Logo(),
                                    SizedBox(height: 16),
                                    Text(
                                      'Internal Bus Washing Management System',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            // Bottom sheet putih
                            Center(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 480,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.fromLTRB(
                                    24,
                                    12,
                                    24,
                                    24,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(32),
                                    ),
                                  ),
                                  child: Form(
                                    key: _formKey,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        // Handle
                                        Center(
                                          child: Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 20),

                                        _label('Email'),
                                        TextFormField(
                                          controller: _email,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          textInputAction: TextInputAction.next,
                                          autofillHints: const [
                                            AutofillHints.email,
                                          ],
                                          decoration: _decoration(
                                            'Enter your email',
                                            Icons.person_outline,
                                          ),
                                          validator: (value) {
                                            final text = value?.trim() ?? '';
                                            if (text.isEmpty) {
                                              return 'Email wajib diisi.';
                                            }
                                            if (!text.contains('@') ||
                                                !text.contains('.')) {
                                              return 'Format email tidak valid.';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),

                                        _label('Password'),
                                        TextFormField(
                                          controller: _password,
                                          obscureText: _obscure,
                                          textInputAction: TextInputAction.done,
                                          autofillHints: const [
                                            AutofillHints.password,
                                          ],
                                          onFieldSubmitted: (_) =>
                                              _loading ? null : _submit(),
                                          decoration: _decoration(
                                            'Enter your password',
                                            Icons.lock_outline,
                                            IconButton(
                                              onPressed: () => setState(
                                                () => _obscure = !_obscure,
                                              ),
                                              icon: Icon(
                                                _obscure
                                                    ? Icons
                                                          .visibility_off_outlined
                                                    : Icons.visibility_outlined,
                                                color: AppColors.textSecondary,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Password wajib diisi.';
                                            }
                                            return null;
                                          },
                                        ),

                                        if (_error != null) ...[
                                          const SizedBox(height: 16),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.error_outline,
                                                  size: 18,
                                                  color: Colors.red.shade700,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    _error!,
                                                    style: TextStyle(
                                                      color:
                                                          Colors.red.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 16),

                                        Row(
                                          children: [
                                            SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: Checkbox(
                                                value: _remember,
                                                activeColor: _red,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                onChanged: (v) => setState(
                                                  () => _remember = v ?? false,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            const Text(
                                              'Remember Me',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            const Spacer(),
                                            TextButton(
                                              onPressed: () {
                                                // TODO: sambungkan ke reset password
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Hubungi administrator untuk reset password.',
                                                    ),
                                                  ),
                                                );
                                              },
                                              style: TextButton.styleFrom(
                                                foregroundColor: _red,
                                                padding: EdgeInsets.zero,
                                                minimumSize: Size.zero,
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .shrinkWrap,
                                              ),
                                              child: const Text(
                                                'Forgot password?',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 24),

                                        SizedBox(
                                          height: 52,
                                          child: FilledButton(
                                            onPressed:
                                                _loading ? null : _submit,
                                            style: FilledButton.styleFrom(
                                              backgroundColor: _red,
                                              disabledBackgroundColor: _red
                                                  .withValues(alpha: 0.7),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                            ),
                                            child: _loading
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        'Login',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Icon(
                                                        Icons.arrow_forward,
                                                        size: 18,
                                                      ),
                                                    ],
                                                  ),
                                          ),
                                        ),
                                        const SizedBox(height: 8),

                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            const Text(
                                              'Belum punya akun?',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: _loading
                                                  ? null
                                                  : () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              const RegisterPage(),
                                                        ),
                                                      );
                                                    },
                                              style: TextButton.styleFrom(
                                                foregroundColor: _red,
                                              ),
                                              child: const Text(
                                                'Daftar',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        const Divider(color: AppColors.border),
                                        const SizedBox(height: 12),
                                        const Text(
                                          'Developed By',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const _KrevLogo(),
                                      ],
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/kpbputih.png',
          height: 140,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => const Column(
            children: [
              Icon(Icons.public, size: 96, color: Colors.white),
              SizedBox(height: 8),
              Text(
                'CV. KARYA PUTRA BUMI',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Garis aksen pengganti lingkaran
        Container(
          width: 72,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 40,
          height: 2,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < 5; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.08 + i * 0.03);

      final baseY = size.height * (0.30 + i * 0.12);
      final amp = 14.0 + i * 3;

      final path = Path()..moveTo(0, baseY);
      for (double x = 0; x <= size.width; x += 4) {
        final y =
            baseY + math.sin((x / size.width) * 2 * math.pi + i * 0.7) * amp;
        path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _KrevLogo extends StatelessWidget {
  const _KrevLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/krev.png',
      height: 35,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const Text(
        'Krev',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}