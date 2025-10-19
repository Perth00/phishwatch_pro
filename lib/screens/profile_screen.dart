import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../services/progress_service.dart';
import '../services/sound_service.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/confirm_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with WidgetsBindingObserver {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _age = TextEditingController();
  bool _loading = true;
  // retained for future use if actions expanded
  // removed unused state; edit actions happen in dedicated screen
  String? _message;
  Color? _messageColor;
  int _currentNavIndex = 3;
  Timer? _verifyCheckTimer;
  static void _noop() {}

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // When returning from email app/browser, refresh user state
      context.read<AuthService>().reloadCurrentUser().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final auth = context.read<AuthService>();
    final progress = context.read<ProgressService>();
    if (!auth.isAuthenticated) {
      setState(() => _loading = false);
      return;
    }
    final data = await progress.getUserProfile();
    _name.text = (data['name'] ?? '') as String;
    final dynamic ageVal = data['age'];
    _age.text = ageVal == null ? '' : ageVal.toString();
    setState(() => _loading = false);
  }

  // No direct save on this list page; edits happen on the dedicated edit screen

  Future<void> _sendVerification() async {
    try {
      await context.read<AuthService>().sendEmailVerification();
      setState(() {
        _message = 'Verification email sent.';
        _messageColor = AppTheme.successColor;
      });
      // Briefly poll for verification to auto-hide the resend UI
      _verifyCheckTimer?.cancel();
      int attempts = 0;
      _verifyCheckTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        attempts += 1;
        await context.read<AuthService>().reloadCurrentUser();
        final verified =
            context.read<AuthService>().currentUser?.emailVerified ?? false;
        if (!mounted) return;
        if (verified || attempts >= 24) {
          // up to ~2 minutes
          t.cancel();
          setState(() {});
          if (verified) {
            setState(() {
              _message = 'Email verified!';
              _messageColor = AppTheme.successColor;
            });
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _message = 'Unable to send email: $e';
        _messageColor = Theme.of(context).colorScheme.error;
      });
    }
  }

  void _onNavTap(int index) {
    SoundService.playButtonSound();
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 0:
        context.go('/home');
        break;
      case 1:
        _showScanDialog();
        break;
      case 2:
        context.go('/learn');
        break;
      case 3:
        // already here
        break;
    }
  }

  void _showScanDialog() {
    SoundService.playButtonSound();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildScanBottomSheet(),
    );
  }

  Widget _buildScanBottomSheet() {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingM),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.borderRadius * 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
            Text(
              'Choose Scan Type',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXL),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/scan-result');
                },
                icon: const Icon(Icons.message_outlined),
                label: const Text('Scan Message'),
              ),
            ),
            const SizedBox(height: AppConstants.spacingM),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.go('/scan-result');
                },
                icon: const Icon(Icons.link_outlined),
                label: const Text('Scan URL'),
              ),
            ),
            const SizedBox(height: AppConstants.spacingL),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _verifyCheckTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : Padding(
                padding: const EdgeInsets.all(AppConstants.spacingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header with avatar and email/guest
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Text(
                            (user?.email ?? '?')
                                .trim()
                                .toUpperCase()
                                .characters
                                .first,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user?.email ?? 'Guest'),
                              const SizedBox(height: 4),
                              if (auth.isAuthenticated)
                                Row(
                                  children: [
                                    Icon(
                                      user!.emailVerified
                                          ? Icons.verified
                                          : Icons.mark_email_unread_outlined,
                                      color:
                                          user.emailVerified
                                              ? AppTheme.successColor
                                              : theme.colorScheme.error,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user.emailVerified
                                          ? 'Email verified'
                                          : 'Email not verified',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                    if (!user.emailVerified) ...[
                                      const SizedBox(width: 8),
                                      _ResendCooldownInline(
                                        onResend: _sendVerification,
                                      ),
                                    ],
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Button list
                    _AnimatedListButton(
                      icon: Icons.person_outline,
                      label: 'Edit profile',
                      onPressed:
                          auth.isAuthenticated
                              ? () => context.push('/profile/edit')
                              : null,
                    ),
                    const SizedBox(height: 12),
                    _AnimatedListButton(
                      icon: auth.isAuthenticated ? Icons.logout : Icons.login,
                      label: auth.isAuthenticated ? 'Log out' : 'Log in',
                      onPressed: () async {
                        if (auth.isAuthenticated) {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder:
                                (_) => const ConfirmDialog(
                                  title: 'Log out?',
                                  message:
                                      'You will be signed out of your account.',
                                  confirmText: 'Log out',
                                  cancelText: 'Cancel',
                                  onConfirm: _noop,
                                ),
                          );
                          if (confirmed == true) {
                            await context.read<AuthService>().signOut();
                            if (mounted) setState(() {});
                          }
                        } else {
                          context.push('/login');
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    _AnimatedListButton(
                      icon: Icons.app_registration_outlined,
                      label: 'Create account',
                      onPressed:
                          auth.isAuthenticated
                              ? null
                              : () => context.push('/register'),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _message!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _messageColor ?? AppTheme.successColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentNavIndex,
        onTap: _onNavTap,
        onProfileTap: () => context.go('/profile'),
      ),
    );
  }
}

class _AnimatedListButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _AnimatedListButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_AnimatedListButton> createState() => _AnimatedListButtonState();
}

class _AnimatedListButtonState extends State<_AnimatedListButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scale = Tween<double>(
      begin: 1,
      end: 1.03,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool disabled = widget.onPressed == null;
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapCancel: () => _controller.reverse(),
      onTapUp: (_) => _controller.reverse(),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: ShapeDecoration(
                color:
                    disabled
                        ? theme.colorScheme.surfaceVariant
                        : theme.colorScheme.surface,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: theme.colorScheme.outline.withOpacity(0.25),
                  ),
                ),
                shadows: [
                  if (!disabled)
                    BoxShadow(
                      color: theme.colorScheme.shadow.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
              child: Row(
                children: [
                  Icon(widget.icon, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ResendCooldownInline extends StatefulWidget {
  final Future<void> Function() onResend;
  const _ResendCooldownInline({required this.onResend});

  @override
  State<_ResendCooldownInline> createState() => _ResendCooldownInlineState();
}

class _ResendCooldownInlineState extends State<_ResendCooldownInline> {
  int _cooldown = 0;
  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed:
          _cooldown == 0
              ? () async {
                await widget.onResend();
                if (!mounted) return;
                setState(() => _cooldown = 60);
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
      child: Text(_cooldown == 0 ? 'Send link' : 'Resend in $_cooldown s'),
    );
  }
}
