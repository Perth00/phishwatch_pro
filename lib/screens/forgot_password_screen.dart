import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/bouncy_button.dart';
import '../services/sound_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _email = TextEditingController();
  final bool _sent = false;
  bool _busy = false;
  String? _error;
  late ConnectivityService _connectivityService;

  @override
  void initState() {
    super.initState();
    _connectivityService = ConnectivityService();
  }

  @override
  void dispose() {
    _email.dispose();
    _connectivityService.dispose();
    super.dispose();
  }

  Future<void> _showValidationAlert(String message) async {
    SoundService.playErrorSound();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
        ),
        title: const Text('Validation Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    final email = _email.text.trim();

    // Validate email
    if (email.isEmpty) {
      await _showValidationAlert('Please enter your email address');
      return;
    }

    if (!email.contains('@')) {
      await _showValidationAlert('Please enter a valid email address');
      return;
    }

    // Check internet connectivity
    final isConnected = await _connectivityService.checkConnection();
    if (!isConnected) {
      if (mounted) {
        await _showValidationAlert(
          'No internet connection. Please check your network and try again.',
        );
      }
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().sendPasswordReset(email);
      if (!mounted) return;
      SoundService.playSuccessSound();
      context.go('/reset-sent', extra: email);
    } catch (e) {
      SoundService.playErrorSound();
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to previous page
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/login');
        }
        return false;
      },
      child: Scaffold(
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
    ));
  }
}
