import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/bouncy_button.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();
  bool _sent = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().sendPasswordReset(_email.text.trim());
      if (!mounted) return;
      context.go('/reset-sent', extra: _email.text.trim());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const Spacer(),
            if (_sent)
              Text(
                'We sent a reset link to your email. Please check your inbox.',
                style: theme.textTheme.bodyMedium,
              ),
            const SizedBox(height: 12),
            BouncyButton(
              onPressed: _busy ? null : _send,
              child:
                  _busy
                      ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Send reset link'),
            ),
          ],
        ),
      ),
    );
  }
}
