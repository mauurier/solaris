import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/survey_store.dart';
import '../../data/sync/sync_queue.dart';
import '../../data/sync/sync_service.dart';
import '../shell/home_shell.dart';

/// Estado de la sincronización con Solaris: lo que falta subir, lo que el
/// servidor rechazó y las preferencias.
class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _state = AppState.instance;
  final _sync = SyncService.instance;
  List<SyncQueueItem> _queue = const [];

  /// Renglones que se dibujan; la cola completa puede tener cientos.
  static const _shown = 60;

  late final _changes = Listenable.merge([_state, _sync, if (SurveyStore.isReady) SurveyStore.instance]);

  @override
  void initState() {
    super.initState();
    _changes.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _changes.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    if (!SurveyStore.isReady) return;
    final queue = await loadSyncQueue(SurveyStore.instance);
    if (mounted) setState(() => _queue = queue);
  }

  int get _errors => _queue.where(_failed).length;
  bool _failed(SyncQueueItem q) => q.keys.any(_sync.failures.containsKey);

  @override
  Widget build(BuildContext context) {
    final body = ListView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, widget.embedded ? 110 : 40),
      children: [
        _statusCard(),
        const SizedBox(height: 20),
        _preferences(),
        const SizedBox(height: 20),
        SectionLabel(
          'Por subir',
          trailing: Text(_queue.length == 1 ? '1 elemento' : '${_queue.length} elementos', style: T.tiny),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: _queue.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Nada pendiente: todo lo del teléfono ya está en el servidor.', style: T.small),
                )
              : Column(
                  children: [
                    for (var i = 0; i < _queue.length && i < _shown; i++) ...[
                      if (i > 0) const Divider(),
                      _queueRow(_queue[i]),
                    ],
                    if (_queue.length > _shown) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text('y ${_queue.length - _shown} más', style: T.tiny),
                      ),
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Integridad'),
        GlassCard(
          child: Column(
            children: [
              _integrityRow(Icons.shield_rounded, 'Identificador único por registro',
                  'Reintentar no crea duplicados', AppColors.success),
              const Divider(),
              _integrityRow(Icons.merge_rounded, 'Cambios de otros respetados',
                  'Sólo se sube lo que cambió en este teléfono', AppColors.success),
              const Divider(),
              _integrityRow(Icons.save_rounded, 'Guardado local automático',
                  'La información no se pierde si se cierra la app', AppColors.success),
            ],
          ),
        ),
      ],
    );

    if (!widget.embedded) {
      return DetailScaffold(
        title: 'Sincronización',
        subtitle: _subtitle,
        bottomBar: AppButton(
          _sync.running ? 'Sincronizando…' : 'Sincronizar ahora',
          icon: Icons.cloud_sync_rounded,
          expand: true,
          onPressed: _sync.running ? null : _syncNow,
        ),
        child: body,
      );
    }

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          TabHeader(
            title: 'Sincronización',
            subtitle: _subtitle,
            actions: [
              const ConnectionChip(),
              const SizedBox(width: 8),
              HeaderIconButton(Icons.refresh_rounded, color: AppColors.accent, onTap: _syncNow),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  String get _subtitle => _errors == 0
      ? '${_queue.length} por subir'
      : '${_queue.length} por subir · $_errors con error';

  Widget _statusCard() {
    final (icon, color, title) = switch (this) {
      _ when _sync.running => (Icons.cloud_sync_rounded, AppColors.blue, 'Sincronizando…'),
      _ when _state.offlineMode => (Icons.pause_circle_rounded, AppColors.warning, 'Sincronización pausada'),
      _ when !_sync.online => (Icons.cloud_off_rounded, AppColors.warning, 'Sin conexión'),
      _ when _sync.error != null => (Icons.error_outline_rounded, AppColors.danger, 'Con errores'),
      _ when _queue.isEmpty => (Icons.cloud_done_rounded, AppColors.success, 'Todo al día'),
      _ => (Icons.cloud_upload_rounded, AppColors.teal, 'Cambios por subir'),
    };
    final last = _sync.lastPull;
    final detail = _sync.error ??
        (_state.offlineMode
            ? 'Los cambios se guardan en el teléfono y se suben al reanudar.'
            : last == null
                ? 'Aún no se sincroniza desde que abriste la app.'
                : 'Última sincronización: ${fmtAgo(last).toLowerCase()}');
    return GlassCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF121A1E), Color(0xFF12161E)],
      ),
      borderColor: color.withValues(alpha: 0.22),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon, color: color, size: 60, iconSize: 30),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ESTADO', style: T.overline),
                    const SizedBox(height: 8),
                    Text(title, style: T.h2),
                    const SizedBox(height: 6),
                    Text(detail, style: T.tiny),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              _stat('${_queue.length}', 'Por subir', AppColors.warning),
              _stat('${_sync.waitingForWifi}', 'Esperan Wi-Fi', AppColors.blue),
              _stat('$_errors', 'Con error', AppColors.danger),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String n, String l, Color c) => Expanded(
        child: Column(
          children: [
            Text(n, style: T.h1.copyWith(color: c)),
            const SizedBox(height: 3),
            Text(l, style: T.tiny),
          ],
        ),
      );

  Widget _preferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Preferencias'),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              _switchRow(
                Icons.autorenew_rounded,
                'Sincronización automática',
                'Al volver la conexión, tras cada cambio y cada 10 min',
                _state.autoSync,
                (v) => _state.setAutoSync(v),
              ),
              const Divider(),
              _switchRow(
                Icons.wifi_rounded,
                'Sólo con Wi-Fi',
                'Fotos, videos y documentos esperan al Wi-Fi; los datos no',
                _state.syncOnWifiOnly,
                (v) => _state.setSyncOnWifiOnly(v),
              ),
              const Divider(),
              _switchRow(
                Icons.pause_circle_rounded,
                'Pausar sincronización',
                'No sube ni baja nada hasta reanudarla',
                _state.offlineMode,
                (v) {
                  _state.offlineMode = v;
                  _state.update();
                  if (!v) unawaited(_sync.sync());
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _switchRow(IconData i, String title, String sub, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(i, size: 17, color: AppColors.textSecondary),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.body.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(sub, style: T.tiny),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.78,
            child: Switch(value: value, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _queueRow(SyncQueueItem q) {
    final error = q.keys.map((k) => _sync.failures[k]).nonNulls.firstOrNull;
    final (color, icon, label) = switch (q) {
      _ when error != null => (AppColors.danger, Icons.error_outline_rounded, 'Error'),
      _ when q.file && _sync.waitingForWifi > 0 => (AppColors.blue, Icons.wifi_rounded, 'Espera Wi-Fi'),
      _ when _sync.running => (AppColors.blue, Icons.cloud_sync_rounded, 'Subiendo'),
      _ => (AppColors.warning, Icons.schedule_rounded, 'En cola'),
    };
    final size = q.bytes == null || q.bytes == 0 ? '' : ' · ${fmtBytes(q.bytes!)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q.deleted ? 'Borrar · ${q.title}' : q.title,
                    style: T.body.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${q.detail}$size', style: T.tiny, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (error != null) ...[
                  const SizedBox(height: 3),
                  Text(error, style: T.tiny.copyWith(color: AppColors.danger)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          StatusPill(label, color: color, dense: true),
        ],
      ),
    );
  }

  Widget _integrityRow(IconData i, String title, String sub, Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(i, size: 16, color: c),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: T.body.copyWith(fontSize: 13.5)),
                const SizedBox(height: 2),
                Text(sub, style: T.tiny),
              ],
            ),
          ),
          const Icon(Icons.check_rounded, size: 15, color: AppColors.success),
        ],
      ),
    );
  }

  Future<void> _syncNow() async {
    if (_state.offlineMode) {
      showAppSnack(context, 'La sincronización está pausada', icon: Icons.pause_circle_rounded, color: AppColors.warning);
      return;
    }
    await _sync.sync();
    if (!mounted) return;
    final error = _sync.error;
    if (error != null) {
      showAppSnack(context, error, icon: Icons.cloud_off_rounded, color: AppColors.warning);
    } else {
      showAppSnack(context, 'Sincronización completa', icon: Icons.cloud_done_rounded, color: AppColors.success);
    }
  }
}
