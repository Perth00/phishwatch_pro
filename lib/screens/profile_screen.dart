import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:go_router/go_router.dart';
import '../constants/app_theme.dart';
import '../services/auth_service.dart';
import '../services/progress_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/theme_service.dart';
import '../services/settings_service.dart';
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
  String? _photoUrl;
  String? _photoBase64;

  String _avatarInitial(String? email) {
    final String trimmed = (email ?? '').trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.substring(0, 1).toUpperCase();
  }

  Widget _buildNotificationsTile() {
    bool value = true;
    try {
      final s = context.read<SettingsService>();
      value = s.notificationsEnabled;
    } catch (_) {}
    return SwitchListTile.adaptive(
      title: const Text('Notifications'),
      value: value,
      onChanged: (v) {
        try {
          context.read<SettingsService>().setNotificationsEnabled(v);
          setState(() {});
        } catch (_) {}
      },
    );
  }

  Widget _buildThemeTile() {
    bool isDark = false;
    try {
      isDark = context.read<ThemeService>().isDarkMode;
    } catch (_) {}
    return SwitchListTile.adaptive(
      title: const Text('Dark Mode'),
      value: isDark,
      onChanged: (_) {
        try {
          context.read<ThemeService>().toggleTheme();
          setState(() {});
        } catch (_) {}
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  ImageProvider<Object>? _avatarImageProvider() {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return NetworkImage(_photoUrl!);
    }
    if (_photoBase64 != null && _photoBase64!.isNotEmpty) {
      try {
        final bytes = base64Decode(_photoBase64!);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    return null;
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
    try {
      final auth = context.read<AuthService>();
      final progress = context.read<ProgressService>();
      if (!auth.isAuthenticated) {
        return;
      }
      final data = await progress.getUserProfile();
      _name.text = (data['name'] ?? '') as String;
      final dynamic ageVal = data['age'];
      _age.text = ageVal == null ? '' : ageVal.toString();
      _photoUrl = (data['photoUrl'] as String?) ?? '';
      _photoBase64 = (data['photoBase64'] as String?) ?? '';
      // Listen for profile doc changes to update avatar in real time
      final uid = context.read<AuthService>().currentUser?.uid;
      if (uid != null) {
        FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots()
            .listen((snap) {
              if (!mounted) return;
              final Map<String, dynamic> d = snap.data() ?? {};
              final String newUrl = (d['photoUrl'] as String?) ?? '';
              final String newB64 = (d['photoBase64'] as String?) ?? '';
              if (newUrl != _photoUrl || newB64 != _photoBase64) {
                setState(() {
                  _photoUrl = newUrl;
                  _photoBase64 = newB64;
                });
              }
            });
      }
    } catch (e) {
      // Show minimal UI even if loading profile fails
      _message = 'Unable to load profile. Some info may be unavailable.';
      _messageColor = Theme.of(context).colorScheme.error;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // No direct save on this list page; edits happen on the dedicated edit screen

  // Removed direct resend handler usage in UI; keep method for future use if needed.

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

    Widget buildSafeBody() {
      if (_loading) return const Center(child: CircularProgressIndicator());
      try {
        return ListView(
          padding: const EdgeInsets.all(AppConstants.spacingL),
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                backgroundImage: _avatarImageProvider(),
                child:
                    (() {
                      final noNetwork = _photoUrl == null || _photoUrl!.isEmpty;
                      final noB64 =
                          _photoBase64 == null || _photoBase64!.isEmpty;
                      if (noNetwork && noB64) {
                        return Text(_avatarInitial(user?.email));
                      }
                      return null;
                    })(),
              ),
              title: Text(
                auth.isAuthenticated
                    ? (() {
                      final String name = _name.text.trim();
                      return name.isEmpty ? 'New user' : name;
                    })()
                    : 'Guest',
              ),
              subtitle:
                  auth.isAuthenticated
                      ? Row(
                        children: [
                          Icon(
                            (user?.emailVerified ?? false)
                                ? Icons.verified
                                : Icons.mark_email_unread_outlined,
                            size: 16,
                            color:
                                (user?.emailVerified ?? false)
                                    ? AppTheme.successColor
                                    : theme.colorScheme.error,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (user?.emailVerified ?? false)
                                ? 'Email verified'
                                : 'Email not verified',
                          ),
                        ],
                      )
                      : const Text('Not signed in'),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed:
                    auth.isAuthenticated
                        ? () =>
                            context.push('/profile/edit').then((_) => _load())
                        : null,
              ),
            ),

            const Divider(),
            ListTile(
              leading: const Icon(Icons.alternate_email_outlined),
              title: const Text('Email'),
              subtitle: Text(user?.email ?? 'Not signed in'),
            ),
            if (auth.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap:
                    (user?.email?.isNotEmpty ?? false)
                        ? () async {
                          final email = user!.email!;
                          await context.read<AuthService>().sendPasswordReset(
                            email,
                          );
                          if (!mounted) return;
                          context.push('/reset-sent', extra: email);
                        }
                        : null,
              ),

            const Divider(),
            _buildNotificationsTile(),
            _buildThemeTile(),
            ListTile(
              leading: const Icon(Icons.language_outlined),
              title: const Text('Language'),
              subtitle: const Text('System'),
            ),

            const Divider(),
            ListTile(
              leading: Icon(auth.isAuthenticated ? Icons.logout : Icons.login),
              title: Text(auth.isAuthenticated ? 'Log out' : 'Log in'),
              onTap: () async {
                if (auth.isAuthenticated) {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (_) => const ConfirmDialog(
                          title: 'Log out?',
                          message: 'You will be signed out of your account.',
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
            if (!auth.isAuthenticated)
              ListTile(
                leading: const Icon(Icons.app_registration_outlined),
                title: const Text('Create account'),
                onTap: () => context.push('/register'),
              ),

            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(
                _message!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _messageColor ?? AppTheme.successColor,
                ),
              ),
            ],
          ],
        );
      } catch (e) {
        return Center(child: Text('Failed to render profile.'));
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: buildSafeBody(),
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
  bool _hovered = false;

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
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapCancel: () => _controller.reverse(),
        onTapUp: (_) => _controller.reverse(),
        onTap: disabled ? null : widget.onPressed,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _hovered ? -2 : 0),
              child: Transform.scale(
                scale: _scale.value,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: ShapeDecoration(
                    color:
                        disabled
                            ? theme.colorScheme.surfaceContainerHighest
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
                          color: Colors.black.withOpacity(
                            _hovered ? 0.08 : 0.04,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
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
              ),
            );
          },
        ),
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

// Legacy custom tiles kept previously; now using ListTile/SwitchListTile for simplicity.

// _ToggleTile no longer used; replaced by SwitchListTile-based helpers above.

// Legacy action tile replaced by ListTile above.
