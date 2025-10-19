import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../services/progress_service.dart';
import 'package:go_router/go_router.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _isRegister = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final auth = context.read<AuthService>();
    try {
      if (_isRegister) {
        await auth.registerWithEmail(_email.text.trim(), _password.text);
        await context.read<ProgressService>().ensureUserProfile();
        await auth.sendEmailVerification();
        if (mounted) context.go('/verify-email');
        return;
      } else {
        await auth.signInWithEmail(_email.text.trim(), _password.text);
      }
      if (mounted) context.go('/goals');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          children: [
            TextField(
              controller: _email,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: Text(_isRegister ? 'Create account' : 'Sign in'),
              ),
            ),
            TextButton(
              onPressed:
                  _isLoading
                      ? null
                      : () => setState(() => _isRegister = !_isRegister),
              child: Text(
                _isRegister
                    ? 'Have an account? Sign in'
                    : 'New here? Create account',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
