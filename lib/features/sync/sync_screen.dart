import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _state = AppState.instance;
  final _queue = Mock.syncQueue;
  bool _syncing = false;

  int get _done => _queue.where((q) => q.state == 'listo').length;
  int get _pending => _queue.where((q) => q.state == 'pendiente' || q.state == 'sincronizando').length;
  int get _errors => _queue.where((q) => q.state == 'error').length;

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
          'Cola de sincronización',
          trailing: Text('${_queue.length} elementos', style: T.tiny),
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              for (var i = 0; i < _queue.length; i++) ...[
                if (i > 0) const Divider(),
                _queueRow(_queue[i]),
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
                  'Evita duplicados al reintentar', AppColors.success),
              const Divider(),
              _integrityRow(Icons.restart_alt_rounded, 'Reanudable',
                  'Si se corta la conexión, continúa donde quedó', AppColors.success),
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
        subtitle: '${(_state.syncProgress * 100).round()} % completado',
        bottomBar: AppButton(
          _syncing ? 'Sincronizando…' : 'Sincronizar ahora',
          icon: Icons.cloud_upload_rounded,
          expand: true,
          onPressed: _syncing ? null : _sync,
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
            subtitle: '$_done sincronizados · $_pending pendientes · $_errors errores',
            actions: [
              const ConnectionChip(),
              const SizedBox(width: 8),
              HeaderIconButton(Icons.refresh_rounded, color: AppColors.accent, onTap: _sync),
            ],
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _statusCard() {
    final offline = _state.offlineMode;
    return GlassCard(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF121A1E), Color(0xFF12161E)],
      ),
      borderColor: AppColors.teal.withValues(alpha: 0.22),
      child: Column(
        children: [
          Row(
            children: [
              ProgressRing(
                value: _state.syncProgress,
                size: 80,
                stroke: 7,
                color: offline ? AppColors.warning : AppColors.teal,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ESTADO', style: T.overline),
                    const SizedBox(height: 8),
                    Text(offline ? 'Sin conexión' : 'Conectado', style: T.h2),
                    const SizedBox(height: 6),
                    Text(
                      offline
                          ? 'Los cambios se guardan localmente y se enviarán al recuperar señal.'
                          : 'Última sincronización: hoy 13:04',
                      style: T.tiny,
                    ),
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
              _stat('$_done', 'Sincronizados', AppColors.success),
              _stat('$_pending', 'Pendientes', AppColors.warning),
              _stat('$_errors', 'Errores', AppColors.danger),
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
                'Al detectar conexión disponible',
                _state.autoSync,
                (v) => setState(() => _state.autoSync = v),
              ),
              const Divider(),
              _switchRow(
                Icons.wifi_rounded,
                'Sólo con Wi-Fi',
                'Evita consumo de datos móviles con videos',
                _state.syncOnWifiOnly,
                (v) => setState(() => _state.syncOnWifiOnly = v),
              ),
              const Divider(),
              _switchRow(
                Icons.cloud_off_rounded,
                'Modo offline forzado',
                'Simula trabajo en sitio sin cobertura',
                _state.offlineMode,
                (v) => setState(() {
                  _state.offlineMode = v;
                  _state.update();
                }),
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

  Widget _queueRow(SyncItem q) {
    final (color, icon, label) = switch (q.state) {
      'listo' => (AppColors.success, Icons.cloud_done_rounded, 'Sincronizado'),
      'sincronizando' => (AppColors.blue, Icons.cloud_sync_rounded, 'Subiendo'),
      'error' => (AppColors.danger, Icons.error_outline_rounded, 'Error'),
      _ => (AppColors.warning, Icons.schedule_rounded, 'En cola'),
    };

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
                Text(q.name,
                    style: T.body.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text('${q.kind} · ${q.size}', style: T.tiny),
                if (q.state == 'sincronizando') ...[
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: q.progress,
                      minHeight: 4,
                      backgroundColor: AppColors.surfaceHigh,
                      valueColor: const AlwaysStoppedAnimation(AppColors.blue),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (q.state == 'error')
            GestureDetector(
              onTap: () {
                setState(() {
                  q.state = 'sincronizando';
                  q.progress = 0.15;
                });
                showAppSnack(context, 'Reintentando envío…');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: const Text('Reintentar',
                    style: TextStyle(
                        fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.danger)),
              ),
            )
          else
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

  Future<void> _sync() async {
    if (_state.offlineMode) {
      showAppSnack(context, 'Sin conexión · la cola se enviará automáticamente',
          icon: Icons.cloud_off_rounded, color: AppColors.warning);
      return;
    }
    setState(() => _syncing = true);
    for (var i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 160));
      if (!mounted) return;
      setState(() {
        _state.syncProgress = (0.68 + i * 0.04).clamp(0.0, 1.0);
        for (final q in _queue) {
          if (q.state == 'sincronizando') {
            q.progress = (q.progress + 0.08).clamp(0.0, 1.0);
            if (q.progress >= 1.0) q.state = 'listo';
          }
        }
      });
    }
    if (!mounted) return;
    setState(() => _syncing = false);
    showAppSnack(context, 'Sincronización actualizada',
        icon: Icons.cloud_done_rounded, color: AppColors.success);
  }
}
