import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../admin/clients_screen.dart';
import '../admin/templates_screen.dart';
import '../admin/users_screen.dart';
import '../auth/login_screen.dart';
import '../history/history_screen.dart';
import '../shell/home_shell.dart';
import '../equipment/equipment_screen.dart';
import '../findings/findings_screen.dart';
import '../report/report_preview_screen.dart';
import '../review/review_screen.dart';
import '../stats/stats_screen.dart';
import '../sync/sync_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _state = AppState.instance;

  @override
  void initState() {
    super.initState();
    _state.addListener(_refresh);
  }

  @override
  void dispose() {
    _state.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 110),
        children: [
          const TabHeader(title: 'Perfil', subtitle: 'Cuenta y preferencias'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              child: Column(
                children: [
                  Row(
                    children: [
                      InitialsAvatar(_state.userInitials, size: 56, color: _state.role.color),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_state.userName, style: T.h2),
                            const SizedBox(height: 5),
                            StatusPill(_state.role.label,
                                color: _state.role.color, icon: _state.role.icon, dense: true),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _stat('27', 'Levantamientos'),
                      _stat('4', 'Activos'),
                      _stat('4.6 h', 'Prom./visita'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel('Cambiar de rol (demo)'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: UserRole.values.map((r) {
                  final sel = r == _state.role;
                  return GestureDetector(
                    onTap: () => _state.setRole(r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                      decoration: BoxDecoration(
                        color: sel ? r.color.withValues(alpha: 0.14) : AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: sel ? r.color.withValues(alpha: 0.45) : AppColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(r.icon, size: 13, color: sel ? r.color : AppColors.textMuted),
                          const SizedBox(width: 6),
                          Text(r.short,
                              style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                                  color: sel ? r.color : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel('Preferencias de captura'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Column(
                children: [
                  _switchRow(
                    Icons.comment_rounded,
                    'Pedir comentario por fotografía',
                    'Desactívalo para capturar más rápido',
                    _state.commentPerPhoto,
                    (v) => setState(() => _state.commentPerPhoto = v),
                  ),
                  const Divider(),
                  _switchRow(
                    Icons.gps_fixed_rounded,
                    'Marca de agua con hora y GPS',
                    'Siempre activa en las fotos tomadas con Solaris',
                    true,
                    null,
                  ),
                  const Divider(),
                  _switchRow(
                    Icons.wifi_rounded,
                    'Sincronizar sólo con Wi-Fi',
                    'Evita consumo de datos con videos',
                    _state.syncOnWifiOnly,
                    (v) => setState(() => _state.syncOnWifiOnly = v),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel('Aplicación'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  if (_state.role == UserRole.admin) ...[
                    const Divider(indent: 14, endIndent: 14),
                    NavRow(
                      dense: true,
                      title: 'Usuarios y roles',
                      subtitle: '${Mock.users.length} usuarios registrados',
                      icon: Icons.group_rounded,
                      iconColor: AppColors.teal,
                      onTap: () => push(context, const UsersScreen()),
                    ),
                    const Divider(indent: 14, endIndent: 14),
                    NavRow(
                      dense: true,
                      title: 'Clientes',
                      subtitle: '${Mock.clients.length} clientes',
                      icon: Icons.business_rounded,
                      iconColor: AppColors.blue,
                      onTap: () => push(context, const ClientsScreen()),
                    ),
                    const Divider(indent: 14, endIndent: 14),
                    NavRow(
                      dense: true,
                      title: 'Plantillas de levantamiento',
                      subtitle: '${SurveyStore.instance.templates.length} configuradas · editor de secciones y preguntas',
                      icon: Icons.dashboard_customize_rounded,
                      iconColor: AppColors.accent,
                      onTap: () => push(context, const TemplatesScreen()),
                    ),
                  ],
                  const Divider(indent: 14, endIndent: 14),
                  NavRow(
                    dense: true,
                    title: 'Almacenamiento local',
                    subtitle: '${SurveyStore.instance.projects.length} proyectos · '
                        '${SurveyStore.instance.evidences.length} evidencias en este teléfono',
                    icon: Icons.sd_storage_rounded,
                    iconColor: AppColors.warning,
                    onTap: () => showAppSnack(context, 'Todo se guarda en el teléfono; comparte con Exportar ZIP'),
                  ),
                  const Divider(indent: 14, endIndent: 14),
                  NavRow(
                    dense: true,
                    title: 'Acerca de Solaris',
                    subtitle: 'Versión 1.0.0 · Fase 1 offline',
                    icon: Icons.info_outline_rounded,
                    iconColor: AppColors.textMuted,
                    onTap: () => showAppSnack(context, 'Fase 1: levantamiento offline con exportación ZIP'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: SectionLabel('Vista previa · próximas fases'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final (i, m) in _previews.indexed) ...[
                    if (i > 0) const Divider(indent: 14, endIndent: 14),
                    NavRow(
                      dense: true,
                      title: m.$1,
                      subtitle: 'Datos de ejemplo',
                      icon: m.$2,
                      iconColor: AppColors.textMuted,
                      onTap: () => push(context, m.$3()),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: AppButton(
              'Cerrar sesión',
              icon: Icons.logout_rounded,
              kind: AppButtonKind.danger,
              expand: true,
              onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                appRoute(const LoginScreen()),
                (r) => false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Column(
          children: [
            Text(v, style: T.h2),
            const SizedBox(height: 3),
            Text(l, style: T.tiny),
          ],
        ),
      );

  /// Módulos del prototipo que aún no se conectan a datos reales.
  static final _previews = <(String, IconData, Widget Function())>[
    ('Revisión del supervisor', Icons.rate_review_rounded, () => ReviewScreen(project: Mock.active)),
    ('Reporte PDF', Icons.picture_as_pdf_rounded, () => ReportPreviewScreen(project: Mock.active)),
    ('Hallazgos', Icons.report_problem_rounded, () => const FindingsScreen()),
    ('Registro de equipos', Icons.memory_rounded, () => const EquipmentScreen()),
    ('Sincronización', Icons.cloud_sync_rounded, () => const SyncScreen()),
    ('Estadísticas', Icons.insights_rounded, () => const StatsScreen()),
    ('Historial de actividad', Icons.history_rounded, () => const HistoryScreen()),
  ];

  Widget _switchRow(IconData i, String title, String sub, bool value, ValueChanged<bool>? onChanged) {
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
}
