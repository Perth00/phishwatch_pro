import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/loading_overlay.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    LoadingOverlay.show(context, message: 'Signing in...');
    try {
      await context.read<AuthService>().signInWithEmail(
        _email.text.trim(),
        _password.text,
      );
      final verified =
          context.read<AuthService>().currentUser?.emailVerified ?? false;
      if (!verified) {
        setState(() {
          _error = 'Please verify your email. We can resend the link.';
        });
      } else {
        if (mounted) context.go('/home');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      LoadingOverlay.hide(context);
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            final confirmed = await showDialog<bool>(
              context: context,
              builder:
                  (_) => ConfirmDialog(
                    title: 'Leave sign in?',
                    message:
                        'Your input will be cleared if you leave this page.',
                    confirmText: 'Leave',
                    cancelText: 'Stay',
                    onConfirm: () {},
                  ),
            );
            if (confirmed == true) {
              context.canPop() ? context.pop() : context.go('/');
            }
          },
        ),
        title: const Text('Sign in'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(
                'Welcome back',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Sign in to continue',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.go('/forgot'),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                const SizedBox(height: 8),
              ],
              if (_error != null) _ResendCooldownButton(),
              const Spacer(),
              BouncyButton(
                onPressed: _busy ? null : _login,
                child:
                    _busy
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Sign in'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("New here?"),
                  TextButton(
                    onPressed: () => context.go('/register'),
                    child: const Text('Create account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResendCooldownButton extends StatefulWidget {
  @override
  State<_ResendCooldownButton> createState() => _ResendCooldownButtonState();
}

class _ResendCooldownButtonState extends State<_ResendCooldownButton> {
  int _cooldown = 0;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed:
            _cooldown == 0
                ? () async {
                  try {
                    await context.read<AuthService>().sendEmailVerification();
                    if (!mounted) return;
                    setState(() => _cooldown = 60);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email sent')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    final String msg = e.toString();
                    final bool throttled = msg.contains('too-many-requests');
                    setState(() => _cooldown = throttled ? 300 : 30);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          throttled
                              ? 'Too many requests. Try again later.'
                              : 'Failed to send: $msg',
                        ),
                      ),
                    );
                  }
                  Future.doWhile(() async {
                    await Future.delayed(const Duration(seconds: 1));
                    if (!mounted) return false;
                    if (_cooldown <= 1) {
                      setState(() => _cooldown = 0);
                      return false;
                    }
                    setState(() => _cooldown -= 1);
                    return true;
                  });
                }
                : null,
        child: Text(
          _cooldown == 0
              ? 'Resend verification link'
              : 'Resend in $_cooldown s',
        ),
      ),
    );
  }
}
