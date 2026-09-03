import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'photo_group_screen.dart';

class PhotoSectionsScreen extends StatefulWidget {
  const PhotoSectionsScreen({super.key});

  @override
  State<PhotoSectionsScreen> createState() => _PhotoSectionsScreenState();
}

class _PhotoSectionsScreenState extends State<PhotoSectionsScreen> {
  final _groups = Mock.photoGroups();
  bool _onlyPending = false;

  int get _captured => _groups.fold(0, (a, g) => a + g.captured);
  int get _total => _groups.fold(0, (a, g) => a + g.slots.length);
  int get _pending => _groups.fold(0, (a, g) => a + g.requiredPending);

  @override
  Widget build(BuildContext context) {
    final visible = _onlyPending ? _groups.where((g) => g.requiredPending > 0).toList() : _groups;

    return DetailScaffold(
      title: '03 Fotografías',
      subtitle: 'TRUPER Monterrey · VIS-001',
      actions: [
        HeaderIconButton(
          _onlyPending ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
          color: _onlyPending ? AppColors.accent : null,
          onTap: () => setState(() => _onlyPending = !_onlyPending),
        ),
      ],
      bottomBar: AppButton(
        'Ver estructura de carpetas',
        icon: Icons.account_tree_rounded,
        kind: AppButtonKind.secondary,
        expand: true,
        onPressed: () => _showStructure(),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        children: [
          GlassCard(
            child: Column(
              children: [
                Row(
                  children: [
                    ProgressRing(value: _captured / _total, size: 62, stroke: 6),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$_captured de $_total evidencias', style: T.h2),
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              StatusPill('$_pending obligatorias pendientes',
                                  color: AppColors.danger, dense: true, icon: Icons.error_outline_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cada fotografía se nombra y clasifica automáticamente en su subsección.',
                        style: T.tiny,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionLabel('Subsecciones'),
          ...visible.map(
            (g) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GlassCard(
                padding: const EdgeInsets.all(14),
                borderColor: g.requiredPending > 0 ? AppColors.danger.withValues(alpha: 0.28) : null,
                onTap: () async {
                  await push(context, PhotoGroupScreen(group: g));
                  if (mounted) setState(() {});
                },
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconBadge(g.icon,
                            color: g.requiredPending > 0 ? AppColors.danger : AppColors.accent, size: 40),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${g.code} ${g.title}', style: T.h3),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Text('${g.captured}/${g.slots.length} capturadas', style: T.tiny),
                                  if (g.requiredPending > 0) ...[
                                    const SizedBox(width: 8),
                                    StatusPill('${g.requiredPending} pendiente',
                                        color: AppColors.danger, dense: true),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        for (var i = 0; i < g.slots.length && i < 5; i++) ...[
                          Expanded(
                            child: AspectRatio(
                              aspectRatio: 1,
                              child: PhotoThumb(
                                seed: g.code.hashCode + i,
                                captured: g.slots[i].captured,
                                radius: 9,
                              ),
                            ),
                          ),
                          if (i < 4 && i < g.slots.length - 1) const SizedBox(width: 6),
                        ],
                        if (g.slots.length < 5)
                          for (var i = g.slots.length; i < 5; i++) const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showStructure() {
    showAppSheet(
      context,
      title: 'Estructura automática',
      subtitle: '03 Fotografías · generada por la plantilla',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('03 Fotografías', style: T.mono.copyWith(color: AppColors.accent)),
              const SizedBox(height: 6),
              ..._groups.map((g) => Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 6),
                    child: Text('├── ${g.code} ${g.title}', style: T.mono),
                  )),
              const SizedBox(height: 10),
              const Divider(),
              const SizedBox(height: 10),
              Text('3.4 Tableros y Canalizaciones', style: T.mono.copyWith(color: AppColors.accent)),
              const SizedBox(height: 6),
              ...['Tablero Principal', 'Tablero 01', 'Tablero 02', 'Tablero 03'].map(
                (t) => Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: Text('├── $t', style: T.mono),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
