import 'package:flutter/material.dart';

/// VISTA reutilizable: mensaje de error con botón "Reintentar".
///
/// La usan la Pokédex, las generaciones y su detalle, para no repetir el
/// mismo bloque tres veces.
///
/// [compact] quita el icono para poder ponerla al final de una lista en vez
/// de a pantalla completa.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.onRetry,
    this.retryKey,
    this.compact = false,
  });

  final String message;

  /// Qué hacer al pulsar Reintentar (lo decide la pantalla que la usa).
  final VoidCallback onRetry;

  /// Key del botón, para que cada pantalla tenga la suya en los tests.
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
