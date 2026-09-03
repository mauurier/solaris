import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../dashboard/dashboard_screen.dart';
import '../shell/home_shell.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _filter = 'Todo';

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Historial y trazabilidad',
      subtitle: 'TRUPER Monterrey · ${Mock.history.length} eventos',
      child: Column(
        children: [
          FilterChips(
            options: const ['Todo', 'Evidencias', 'Formularios', 'Estados', 'Sincronización'],
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
              children: [
                GlassCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < Mock.history.length; i++)
                        TimelineRow(
                          event: Mock.history[i],
                          isLast: i == Mock.history.length - 1,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                GlassCard(
                  color: AppColors.surfaceAlt,
                  child: Row(
                    children: [
                      const IconBadge(Icons.verified_user_rounded, color: AppColors.teal, size: 36),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Cada cambio queda registrado con usuario, fecha, hora y ubicación para garantizar la trazabilidad.',
                          style: T.tiny,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
