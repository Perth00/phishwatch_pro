import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  final bool startWithCooldown;
  const VerifyEmailScreen({super.key, this.startWithCooldown = false});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  int _cooldown = 0; // seconds
  Timer? _timer;
  bool _checking = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.startWithCooldown) {
      _cooldown = 60;
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (_cooldown <= 1) {
          t.cancel();
          setState(() => _cooldown = 0);
        } else {
          setState(() => _cooldown -= 1);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_cooldown > 0) return;
    try {
      await context.read<AuthService>().sendEmailVerification();
      setState(() {
        _message = 'Verification email sent.';
        _cooldown = 60;
      });
    } catch (e) {
      setState(() {
        _message = 'Unable to send email: $e';
      });
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown -= 1);
      }
    });
  }

  Future<void> _iVerified() async {
    setState(() => _checking = true);
    try {
      await context.read<AuthService>().reloadCurrentUser();
      final verified =
          context.read<AuthService>().currentUser?.emailVerified ?? false;
      if (verified) {
        if (mounted) context.go('/login');
      } else {
        if (mounted) {
          setState(
            () => _message = 'Still not verified. Check your inbox/spam.',
          );
        }
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final email = context.read<AuthService>().currentUser?.email ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Verify your email')),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'We sent a verification link to:\n$email',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Please verify your email to continue. You can resend the email, or tap "I\'ve verified" after clicking the link.',
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
              onPressed: _cooldown == 0 ? _resend : null,
              child: Text(
                _cooldown == 0
                    ? 'Resend verification email'
                    : 'Resend in $_cooldown s',
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _checking ? null : _iVerified,
              child:
                  _checking
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text("I've verified"),
            ),
          ],
        ),
      ),
    );
  }
}
