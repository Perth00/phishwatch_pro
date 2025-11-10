import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/loading_overlay.dart';
import '../services/history_service.dart';
import '../services/sound_service.dart';

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

  Future<void> _login() async {
    // Prevent multiple clicks
    if (_busy) return;

    // Check if credentials are empty
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
    LoadingOverlay.show(context, message: 'Signing in...');
    try {
      await authService.signInWithEmail(
        _email.text.trim(),
        _password.text,
      );
      final verified = authService.currentUser?.emailVerified ?? false;
      if (!verified) {
        setState(() {
          _error = 'Please verify your email. We can resend the link.';
          _busy = false; // Allow retry if email not verified
        });
      } else {
        // Sync history with cloud before entering home
        try {
          await context.read<HistoryService>().syncWithCloud();
        } catch (_) {}
        if (mounted) context.go('/home');
      }
    } catch (e) {
      SoundService.playErrorSound();
      setState(() {
        _error = e.toString();
        _busy = false; // Allow retry on error
      });
    } finally {
      LoadingOverlay.hide(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WillPopScope(
      onWillPop: () async {
        // Navigate back to previous page if available, otherwise go to home
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
        return false;
      },
      child: Scaffold(
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
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            }
          },
        ),
        title: const Text('Sign in'),
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
                        // Only show resend button if email is not verified
                        if (_error != null && _error!.contains('verify your email')) _ResendCooldownButton(),
                        const Spacer(),
                        BouncyButton(
                          onPressed: _busy ? null : _login,
                          child: _busy
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
              ),
            );
          },
        ),
      ),
    ));
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
                    SoundService.playSuccessSound();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Verification email sent')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    SoundService.playErrorSound();
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
