import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  final bool sendCodeOnOpen;

  const VerifyOtpPage({
    super.key,
    required this.email,
    this.sendCodeOnOpen = false,
  });

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  static const _codeLength = 6;
  static const _cooldownSeconds = 60;

  final _code = TextEditingController();

  Timer? _timer;
  int _cooldown = _cooldownSeconds;
  bool _verifying = false;
  bool _resending = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    _startTimer();

    if (widget.sendCodeOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        _cooldown--;
        if (_cooldown <= 0) {
          _cooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _sendCode() async {
    if (_resending) return;

    setState(() {
      _resending = true;
      _error = null;
      _info = null;
    });

    try {
      await AuthService.instance.resendOtp(widget.email);

      if (!mounted) return;
      setState(() {
        _info = 'Kode baru sudah dikirim ke email kamu.';
        _cooldown = _cooldownSeconds;
      });
      _startTimer();
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        if (e.code == 'RATE_LIMITED') {
          _cooldown = _cooldownSeconds;
        }
      });
      if (e.code == 'RATE_LIMITED') _startTimer();
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length != _codeLength || _verifying) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _verifying = true;
      _error = null;
      _info = null;
    });

    try {
      await AuthService.instance.verifyOtp(email: widget.email, code: code);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _code.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Terjadi kesalahan. Coba lagi.');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _cooldown == 0 && !_resending && !_verifying;

    return Scaffold(
      appBar: AppBar(title: const Text('Verifikasi Email')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.mark_email_unread_outlined,
                    size: 56,
                    color: AppColors.brand,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Masukkan kode verifikasi',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Kami mengirim kode $_codeLength digit ke\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _code,
                    enabled: !_verifying,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(_codeLength),
                    ],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 12,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••••',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length == _codeLength) _verify();
                    },
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(12),
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
                              style: TextStyle(color: Colors.red.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (_info != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _info!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green.shade700),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _verifying ? null : _verify,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _verifying
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Verifikasi'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: canResend ? _sendCode : null,
                    child: Text(
                      _cooldown > 0
                          ? 'Kirim ulang kode (${_cooldown}s)'
                          : 'Kirim ulang kode',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tidak menemukan emailnya? Cek folder spam.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
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
