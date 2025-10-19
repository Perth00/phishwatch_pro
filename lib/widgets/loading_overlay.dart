import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class LoadingOverlay {
  static Future<void> show(BuildContext context, {String? message}) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        return WillPopScope(
          onWillPop: () async => false,
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Lottie.asset(
                    'assets/animations/loading.json',
                    width: 160,
                    height: 120,
                    repeat: true,
                    fit: BoxFit.contain,
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 8),
                    Text(message, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static void hide(BuildContext context) {
    Navigator.of(context, rootNavigator: true).pop();
  }
}
