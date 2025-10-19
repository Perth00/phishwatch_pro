import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback? onProfileTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) async {
          // Refresh auth state so emailVerified and other badges are up to date
          try {
            await context.read<AuthService>().reloadCurrentUser();
          } catch (_) {}
          onTap(i);
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: colorScheme.onSurface.withOpacity(0.6),
        selectedLabelStyle: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: theme.textTheme.labelSmall,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield),
            label: 'Scan',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Learn',
          ),
          BottomNavigationBarItem(
            icon: GestureDetector(
              onTap: onProfileTap,
              child: const Icon(Icons.person_outline),
            ),
            activeIcon: const Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
