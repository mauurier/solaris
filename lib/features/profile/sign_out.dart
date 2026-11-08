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
/// atascaron cambios al probar con dos cuentas en un mismo teléfono.
///
/// Por eso no se deja cerrar sesión mientras quede algo que todavía se pueda
/// subir (sin conexión, sincronización pausada, archivos esperando Wi-Fi o
/// una subida que no terminó). La única excepción son los cambios que el
/// servidor rechazó: esa cuenta no los va a poder subir nunca y bloquearlos
/// dejaría el teléfono sin poder cambiar de cuenta; se avisa y se deja salir.
Future<bool> prepareSignOut(BuildContext context) async {
  if (!SurveyStore.isReady) return true;
  final store = SurveyStore.instance;
  if (await store.pendingCount() == 0) return true;

  final sync = SyncService.instance;
  final app = AppState.instance;

  // Sin forma de subir: ni se intenta.
  if (app.offlineMode || !sync.online) {
    final left = await store.pendingCount();
    if (!context.mounted) return false;
    await _blocked(
      context,
      left,
      app.offlineMode
          ? 'La sincronización está pausada. Reactívala en Perfil › Sincronización para subirlos.'
          : 'No hay conexión. Conéctate a internet para subirlos.',
    );
    return false;
  }

  if (!context.mounted) return false;
  final finished = await _uploadWithDialog(context, () async {
    await sync.sync();
    // Si ya corría una sincronización que no alcanzó lo último, otra vuelta.
    if (await store.pendingCount() > 0 &&
        !sync.interrupted &&
        sync.failures.isEmpty &&
        sync.waitingForWifi == 0) {
      await sync.sync();
    }
  });

  final left = await store.pendingCount();
  if (left == 0) return true;
  if (!context.mounted) return false;

  // Lo que todavía se puede subir bloquea la salida.
  final reason = switch (null) {
    _ when !finished => 'Cancelaste la subida antes de que terminara.',
    _ when sync.interrupted => 'Se cortó la subida: ${sync.error ?? 'sin conexión'}. Intenta de nuevo.',
    _ when sync.waitingForWifi > 0 =>
      '${sync.waitingForWifi == 1 ? 'Un archivo espera' : '${sync.waitingForWifi} archivos esperan'} Wi-Fi. '
          'Conéctate a una red Wi-Fi o desactiva "Sincronizar sólo con Wi-Fi" en Perfil.',
    _ when sync.failures.isEmpty => 'Todavía hay cambios por subir. Intenta de nuevo en un momento.',
    _ => null,
  };
  if (reason != null) {
    await _blocked(context, left, reason);
    return false;
  }

  // Sólo quedan cambios que el servidor rechazó (y lo que depende de ellos).
  final n = sync.failures.length;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(left == 1 ? 'Queda 1 cambio que el servidor rechazó' : 'Quedan $left cambios que el servidor rechazó'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('El servidor no aceptó ${n == 1 ? 'un cambio' : '$n cambios'}: ${sync.failures.values.first}',
              style: T.small.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 10),
          const Text(
            'Con esta cuenta no se van a poder subir. Si cierras sesión se quedan en el teléfono y se '
            'intentarán subir con la próxima cuenta que entre.',
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

/// Aviso de que no se puede cerrar sesión todavía, con el motivo.
Future<void> _blocked(BuildContext context, int left, String reason) async {
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Aún no puedes cerrar sesión'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(left == 1 ? 'Queda 1 cambio sin subir.' : 'Quedan $left cambios sin subir.',
              style: T.small.copyWith(color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          Text(reason, style: T.small),
          const SizedBox(height: 10),
          const Text(
            'Se cierra cuando todo esté en el servidor, para que otra cuenta no intente subir lo que hiciste.',
            style: T.tiny,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, 'ver'), child: const Text('Ver pendientes')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
      ],
    ),
  );
  if (choice == 'ver' && context.mounted) unawaited(push(context, const SyncScreen()));
}

/// Muestra "Subiendo cambios" mientras corre [upload]. Falso si la persona
/// canceló (la subida sigue por su cuenta, pero no se cierra la sesión).
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
            Text('La sesión se cierra cuando todo lo que hiciste con esta cuenta esté en el servidor.',
                style: T.small),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (!stop.isCompleted) stop.complete(false);
            },
            child: const Text('Cancelar'),
          ),
        ],
      ),
    ),
  );
  final finished = await Future.any([upload().then((_) => true), stop.future]);
  navigator.pop();
  return finished;
}
