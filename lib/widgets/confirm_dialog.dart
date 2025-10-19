import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class ConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final VoidCallback onConfirm;
  final String animationAsset;

  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.onConfirm,
    this.confirmText = 'Yes',
    this.cancelText = 'No',
    this.animationAsset = 'assets/animations/log_out.json',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            animationAsset,
            width: 140,
            height: 140,
            repeat: true,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 8),
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () {
            onConfirm();
            Navigator.pop(context, true);
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}
