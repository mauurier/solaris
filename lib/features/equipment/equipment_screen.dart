import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import 'equipment_detail_screen.dart';

class EquipmentScreen extends StatefulWidget {
  const EquipmentScreen({super.key});

  @override
  State<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends State<EquipmentScreen> {
  String _filter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final cats = ['Todos', 'Transformador', 'Tablero', 'Inversor'];
    final list = _filter == 'Todos'
        ? Mock.equipment
        : Mock.equipment.where((e) => e.category == _filter).toList();

    return DetailScaffold(
      title: '06 Equipos',
      subtitle: '${Mock.equipment.length} registrados · 1 incompleto',
      bottomBar: AppButton(
        'Registrar equipo',
        icon: Icons.add_rounded,
        expand: true,
        onPressed: () => push(context, const EquipmentDetailScreen(), fullscreenDialog: true),
      ),
      child: Column(
        children: [
          FilterChips(
            options: cats,
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _card(list[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(Equipment e) {
    return GlassCard(
      onTap: () => push(context, EquipmentDetailScreen(equipment: e)),
      borderColor: e.complete ? null : AppColors.danger.withValues(alpha: 0.28),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(e.icon, color: e.complete ? AppColors.blue : AppColors.danger, size: 42),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.name, style: T.h3),
                    const SizedBox(height: 3),
                    Text('${e.brand} · ${e.model}', style: T.tiny),
                  ],
                ),
              ),
              if (!e.complete)
                const StatusPill('Incompleto', color: AppColors.danger, dense: true)
              else
                const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _tag(Icons.bolt_rounded, e.capacity),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _tag(Icons.place_rounded, e.location),
              const Spacer(),
              _tag(Icons.photo_camera_rounded, '${e.photos} fotos'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(IconData i, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(i, size: 12, color: AppColors.textMuted),
          const SizedBox(width: 5),
          Flexible(child: Text(t, style: T.tiny, overflow: TextOverflow.ellipsis)),
        ],
      );
}
