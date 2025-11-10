import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../services/progress_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/confirm_dialog.dart';
import '../services/sound_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
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
    _password.dispose();
    _confirm.dispose();
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

  Future<void> _register() async {
    // Prevent multiple clicks
    if (_busy) return;

    // Check password match
    if (_password.text != _confirm.text) {
      await _showValidationAlert('Passwords do not match');
      return;
    }

    // Validate credentials
    final authService = context.read<AuthService>();
    final validationError =
        authService.validateCredentials(_email.text, _password.text);

    if (validationError != null) {
      await _showValidationAlert(validationError);
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
      await authService.registerWithEmail(
        _email.text.trim(),
        _password.text,
      );
      await context.read<ProgressService>().ensureUserProfile();
      await authService.sendEmailVerification();
      if (mounted) context.go('/verify-email', extra: true);
    } catch (e) {
      SoundService.playErrorSound();
      setState(() {
        _error = e.toString();
        _busy = false; // Allow retry on error
      });
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
      appBar: AppBar(
        leading: Builder(
          builder:
              (context) => IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (_) => ConfirmDialog(
                          title: 'Leave this page?',
                          message: 'Your progress on this form will be lost.',
                          confirmText: 'Leave',
                          cancelText: 'Stay',
                          onConfirm: () {},
                        ),
                  );
                  if (confirmed == true) {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/login');
                    }
                  }
                },
              ),
        ),
        title: const Text('Create account'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
            return SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spacingL),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Create account',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'We will email you a verification link',
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
                        const SizedBox(height: 12),
                        TextField(
                          controller: _confirm,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Confirm Password',
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 8),
                          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                        ],
                        const Spacer(),
                        BouncyButton(
                          onPressed: _busy ? null : _register,
                          child:
                              _busy
                                  ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                  : const Text('Create account'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Already have an account?'),
                            TextButton(
                              onPressed: () => context.go('/login'),
                              child: const Text('Sign in'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ));
  }
}
