import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../data/app_state.dart';
import '../../data/sync/sync_service.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../sync/sync_screen.dart';

/// Antes de cerrar sesión sube lo pendiente. Devuelve si ya se puede cerrar.
///
/// Los cambios guardados en el teléfono no llevan la cuenta que los hizo: si
/// se quedan, se suben con la siguiente que entre, y el servidor puede
/// rechazarlos (una foto sólo la sube quien la tomó; el técnico no puede
/// tocar una visita aprobada; sólo el supervisor registra revisiones). Así se
/// quedó una visita "Pend. sincronizar" al probar con dos cuentas en un mismo
/// teléfono. Si algo no sube, se avisa antes de salir.
Future<bool> prepareSignOut(BuildContext context) async {
  if (!SurveyStore.isReady) return true;
  final store = SurveyStore.instance;
  if (await store.pendingCount() == 0) return true;

  final sync = SyncService.instance;
  final app = AppState.instance;
  var stopped = false;
  if (sync.online && !app.offlineMode && context.mounted) {
    stopped = !await _uploadWithDialog(context, () async {
      await sync.sync();
      // Si ya corría una sincronización que no alcanzó lo último, otra vuelta.
      if (await store.pendingCount() > 0 && sync.failures.isEmpty && sync.waitingForWifi == 0 && sync.error == null) {
        await sync.sync();
      }
    });
  }

  final left = await store.pendingCount();
  if (left == 0) return true;
  if (!context.mounted) return false;

  final reason = switch (null) {
    _ when app.offlineMode => 'La sincronización está pausada.',
    _ when !sync.online => 'No hay conexión.',
    _ when stopped => 'La subida no terminó.',
    _ when sync.failures.isNotEmpty => 'El servidor no aceptó '
        '${sync.failures.length == 1 ? 'un cambio' : '${sync.failures.length} cambios'}: ${sync.failures.values.first}',
    _ when sync.waitingForWifi > 0 => '${sync.waitingForWifi == 1 ? 'Un archivo espera' : '${sync.waitingForWifi} archivos esperan'} '
        'Wi-Fi (opción "Sólo con Wi-Fi").',
    _ => sync.error ?? 'No se pudo subir todo.',
  };
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(left == 1 ? 'Queda 1 cambio sin subir' : 'Quedan $left cambios sin subir'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(reason, style: T.small.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          const Text(
            'Si cierras sesión se quedan en el teléfono y se suben con la próxima cuenta que entre. '
            'Si es otra cuenta, el servidor puede rechazarlos: por ejemplo, las fotos sólo las puede '
            'subir quien las tomó.',
            style: T.small,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, 'ver'), child: const Text('Ver pendientes')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'salir'),
          child: const Text('Cerrar sesión', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
  if (choice == 'ver' && context.mounted) unawaited(push(context, const SyncScreen()));
  return choice == 'salir';
}

/// Muestra "Subiendo cambios" mientras corre [upload]. Falso si la persona
/// dejó de esperar (la subida sigue por su cuenta).
Future<bool> _uploadWithDialog(BuildContext context, Future<void> Function() upload) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  final stop = Completer<bool>();
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Subiendo cambios'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(),
            SizedBox(height: 12),
            Text('Antes de cerrar sesión se sube lo que hiciste con esta cuenta.', style: T.small),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!stop.isCompleted) stop.complete(false);
            },
            child: const Text('Dejar de esperar'),
          ),
        ],
      ),
    ),
  );
  final finished = await Future.any([upload().then((_) => true), stop.future]);
  navigator.pop();
  return finished;
}
