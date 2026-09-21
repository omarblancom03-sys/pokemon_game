import 'package:flutter/material.dart';

/// Load failure with a retry action, shared by the gallery screens.
///
/// [compact] drops the icon so it can sit in a list footer instead of filling
/// the screen.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryKey,
    this.compact = false,
  });

  final String message;
  final VoidCallback onRetry;

  /// Key for the retry button, so each screen's test can target its own.
  final Key? retryKey;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!compact)
              const Icon(Icons.wifi_off, color: Colors.white54, size: 56),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: retryKey,
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
