import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../shell/home_shell.dart';

class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Clientes',
      subtitle: '${Mock.clients.length} registrados',
      bottomBar: AppButton(
        'Nuevo cliente',
        icon: Icons.add_business_rounded,
        expand: true,
        onPressed: () => showAppSnack(context, 'Alta de cliente (prototipo)'),
      ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        itemCount: Mock.clients.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final c = Mock.clients[i];
          return GlassCard(
            onTap: () => showAppSnack(context, 'Detalle de cliente (prototipo)'),
            child: Row(
              children: [
                InitialsAvatar(c.name.substring(0, 1), size: 44, color: AppColors.blue),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.name, style: T.h3),
                      const SizedBox(height: 4),
                      Text('RFC ${c.rfc}', style: T.tiny),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textMuted),
                          const SizedBox(width: 4),
                          Text(c.contact, style: T.tiny),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${c.projects}', style: T.h2.copyWith(color: AppColors.accent)),
                    Text('proyectos', style: T.tiny),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
