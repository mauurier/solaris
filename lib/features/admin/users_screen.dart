import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  String _filter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final list = _filter == 'Todos'
        ? Mock.users
        : Mock.users.where((u) => u.role.short == _filter).toList();

    return DetailScaffold(
      title: 'Usuarios y roles',
      subtitle: '${Mock.users.length} usuarios · ${Mock.users.where((u) => u.active).length} activos',
      bottomBar: AppButton(
        'Crear usuario',
        icon: Icons.person_add_alt_1_rounded,
        expand: true,
        onPressed: _newUser,
      ),
      child: Column(
        children: [
          FilterChips(
            options: const ['Todos', 'Admin', 'Supervisor', 'Técnico', 'Revisor'],
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

  Widget _card(AppUser u) {
    return GlassCard(
      onTap: () => _permissions(u),
      child: Row(
        children: [
          Opacity(
            opacity: u.active ? 1 : 0.45,
            child: InitialsAvatar(u.initials, size: 44, color: u.role.color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(u.name, style: T.h3, overflow: TextOverflow.ellipsis)),
                    if (!u.active) ...[
                      const SizedBox(width: 8),
                      const StatusPill('Inactivo', color: AppColors.textMuted, dense: true),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(u.email, style: T.tiny),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusPill(u.role.short, color: u.role.color, dense: true, icon: u.role.icon),
                    const SizedBox(width: 8),
                    Text('${u.projects} proyectos', style: T.tiny),
                  ],
                ),
              ],
            ),
          ),
          Transform.scale(
            scale: 0.75,
            child: Switch(
              value: u.active,
              onChanged: (v) => setState(() => u.active = v),
            ),
          ),
        ],
      ),
    );
  }

  void _permissions(AppUser u) {
    final perms = switch (u.role) {
      UserRole.admin => [
          'Crear y modificar usuarios',
          'Asignar roles',
          'Crear clientes y proyectos',
          'Configurar plantillas y formularios',
          'Consultar todos los proyectos',
          'Consultar estadísticas',
          'Descargar información',
          'Consultar registros históricos',
        ],
      UserRole.supervisor => [
          'Crear proyectos y visitas',
          'Asignar técnicos',
          'Revisar información y evidencia',
          'Solicitar correcciones',
          'Aprobar levantamientos',
          'Generar reportes y descargar',
          'Consultar estadísticas',
        ],
      UserRole.tecnico => [
          'Consultar proyectos asignados',
          'Descargar para trabajo offline',
          'Iniciar visitas y capturar información',
          'Tomar fotografías y videos',
          'Registrar mediciones, equipos y hallazgos',
          'Firmar el levantamiento',
          'Generar borrador del reporte',
          'Sincronizar información',
        ],
      UserRole.revisor => [
          'Consultar levantamientos',
          'Revisar información técnica y evidencia',
          'Registrar observaciones',
          'Solicitar correcciones',
          'Aprobar o rechazar levantamientos',
        ],
    };

    showAppSheet(
      context,
      title: u.name,
      subtitle: '${u.role.label} · ${u.email}',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Rol asignado'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: UserRole.values.map((r) {
                final sel = r == u.role;
                return Container(
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
                              fontSize: 12.5, color: sel ? r.color : AppColors.textSecondary)),
                    ],
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const FieldLabel('Permisos del rol'),
            ...perms.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
                      const SizedBox(width: 10),
                      Expanded(child: Text(p, style: T.small)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _newUser() {
    showAppSheet(
      context,
      title: 'Crear usuario',
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const FieldLabel('Nombre completo', required: true),
            const TextField(decoration: InputDecoration(hintText: 'Nombre y apellidos')),
            const SizedBox(height: 16),
            const FieldLabel('Correo', required: true),
            const TextField(decoration: InputDecoration(hintText: 'usuario@solaris.mx')),
            const SizedBox(height: 16),
            const FieldLabel('Rol', required: true),
            SegmentedPicker(
              options: const ['Admin', 'Superv.', 'Técnico', 'Revisor'],
              selected: 'Técnico',
              onSelected: (_) {},
            ),
            const SizedBox(height: 22),
            AppButton(
              'Crear usuario',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: () {
                Navigator.pop(context);
                showAppSnack(context, 'Usuario creado (prototipo)',
                    icon: Icons.check_circle_rounded, color: AppColors.success);
              },
            ),
          ],
        ),
      ),
    );
  }
}
