import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';

class ResetPasswordSentScreen extends StatefulWidget {
  final String email;
  const ResetPasswordSentScreen({super.key, required this.email});

  @override
  State<ResetPasswordSentScreen> createState() =>
      _ResetPasswordSentScreenState();
}

class _ResetPasswordSentScreenState extends State<ResetPasswordSentScreen> {
  int _cooldown = 60;
  Timer? _timer;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _cooldown = _cooldown > 0 ? _cooldown - 1 : 0;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_cooldown > 0 || _busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await context.read<AuthService>().sendPasswordReset(widget.email);
      if (!mounted) return;
      setState(() {
        _message = 'Reset email sent again.';
        _cooldown = 60;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _message = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Check your email')),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We sent a password reset link to:\n${widget.email}',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Please open your inbox (and Spam/Promotions) and follow the link to reset your password.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.8),
                height: 1.5,
              ),
            ),
            const Spacer(),
            if (_message != null) ...[
              Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.successColor,
                ),
              ),
              const SizedBox(height: 8),
            ],
            ElevatedButton(
              onPressed: (_cooldown == 0 && !_busy) ? _resend : null,
              child:
                  _busy
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(
                        _cooldown == 0
                            ? 'Resend reset email'
                            : 'Resend in $_cooldown s',
                      ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Back to Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
