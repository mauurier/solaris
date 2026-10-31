import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/formatting.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/auth/auth_service.dart';
import '../../data/auth/profile.dart';
import '../../data/auth/user_directory.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';

/// Cuentas de la tabla `perfil`. Todos los admin la ven; solo el superadmin
/// crea cuentas y cambia rol, estado y vigencia.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _dir = UserDirectory.instance;
  String _filter = 'Todos';
  final _busy = <String>{};

  bool get _demo => AppState.instance.profile == null;
  bool get _canManage => AppState.instance.profile?.isSuperadmin ?? false;

  @override
  void initState() {
    super.initState();
    _dir.addListener(_refresh);
    _dir.refresh();
  }

  @override
  void dispose() {
    _dir.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final all = _dir.users;
    final list = _filter == 'Todos' ? all : all.where((u) => u.role.short == _filter).toList();

    return DetailScaffold(
      title: 'Usuarios y roles',
      subtitle: '${all.length} usuarios · ${all.where((u) => u.active).length} activos',
      bottomBar: _canManage
          ? AppButton('Crear usuario', icon: Icons.person_add_alt_1_rounded, expand: true, onPressed: _newUser)
          : null,
      child: Column(
        children: [
          FilterChips(
            options: const ['Todos', 'Admin', 'Supervisor', 'Técnico'],
            selected: _filter,
            onSelected: (v) => setState(() => _filter = v),
          ),
          const SizedBox(height: 12),
          if (_demo || _dir.error != null || !_canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: _demo
                  ? const InfoBanner('Modo demo: usuarios de ejemplo. Inicia sesión para ver las cuentas reales.')
                  : _dir.error != null
                  ? InfoBanner(
                      'No se pudo actualizar la lista. ${_dir.error}',
                      icon: Icons.cloud_off_rounded,
                      color: AppColors.warning,
                    )
                  : const InfoBanner('Solo el superadmin puede crear y modificar cuentas.'),
            ),
          if (_dir.loading && all.isEmpty)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _dir.refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _card(list[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _editable(AppUser u) => _canManage && u.profile != null && !u.isSuperadmin;

  Widget _card(AppUser u) {
    final status = _statusPill(u);
    return GlassCard(
      onTap: () => _details(u),
      child: Row(
        children: [
          Opacity(
            opacity: u.assignable ? 1 : 0.45,
            child: InitialsAvatar(u.initials, size: 44, color: u.role.color),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(u.name, style: T.h3, overflow: TextOverflow.ellipsis),
                    ),
                    if (status != null) ...[const SizedBox(width: 8), status],
                  ],
                ),
                const SizedBox(height: 4),
                Text(u.email, style: T.tiny),
                const SizedBox(height: 8),
                Row(
                  children: [
                    StatusPill(
                      u.isSuperadmin ? 'Superadmin' : u.role.short,
                      color: u.role.color,
                      dense: true,
                      icon: u.role.icon,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(_detail(u), style: T.tiny, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_busy.contains(u.email))
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (_editable(u) || _demo)
            Transform.scale(
              scale: 0.75,
              child: Switch(value: u.active, onChanged: (v) => _setActive(u, v)),
            ),
        ],
      ),
    );
  }

  String _detail(AppUser u) {
    final p = u.profile;
    if (p == null) return '${u.projects ?? 0} proyectos';
    if (p.isSuperadmin) return 'No vence';
    return p.endsOn == null ? 'Sin fecha de fin' : 'Hasta el ${fmtDate(p.endsOn!)}';
  }

  Widget? _statusPill(AppUser u) {
    final p = u.profile;
    if (p == null) return u.active ? null : const StatusPill('Inactivo', color: AppColors.textMuted, dense: true);
    return switch (p.statusOn(DateTime.now())) {
      AccountStatus.ok => null,
      AccountStatus.inactive => const StatusPill('Inactivo', color: AppColors.textMuted, dense: true),
      AccountStatus.notStarted => StatusPill('Desde ${fmtDate(p.startsOn)}', color: AppColors.blue, dense: true),
      AccountStatus.expired => const StatusPill('Vencida', color: AppColors.danger, dense: true),
    };
  }

  Future<void> _setActive(AppUser u, bool active) async {
    final p = u.profile;
    if (p == null) {
      setState(() => u.active = active);
      return;
    }
    setState(() => _busy.add(u.email));
    try {
      await _dir.update(u, role: p.role, active: active, startsOn: p.startsOn, endsOn: p.endsOn);
      if (mounted) {
        showAppSnack(
          context,
          active ? '${u.name} puede entrar a la app' : '${u.name} ya no puede entrar',
          icon: Icons.check_circle_rounded,
          color: AppColors.success,
        );
      }
    } on AuthFailure catch (e) {
      if (mounted) showAppSnack(context, e.message, icon: Icons.error_outline_rounded, color: AppColors.danger);
    } finally {
      if (mounted) setState(() => _busy.remove(u.email));
    }
  }

  void _details(AppUser u) {
    showAppSheet(
      context,
      title: u.name,
      subtitle: '${u.isSuperadmin ? 'Superadmin' : u.role.label} · ${u.email}',
      child: _UserSheet(user: u, editable: _editable(u)),
    );
  }

  Future<void> _newUser() async {
    final created = await showAppSheet<(AppUser, String)>(
      context,
      title: 'Crear usuario',
      subtitle: 'La persona entra con este correo y contraseña',
      child: const _NewUserSheet(),
    );
    if (created == null || !mounted) return;
    final (user, password) = created;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cuenta creada'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comparte estos datos con ${user.name}. La contraseña no se vuelve a mostrar.', style: T.small),
            const SizedBox(height: 14),
            SelectableText('Correo: ${user.email}\nContraseña: $password', style: T.body),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: 'Correo: ${user.email}\nContraseña: $password'));
              Navigator.pop(ctx);
              showAppSnack(context, 'Datos copiados', icon: Icons.copy_rounded);
            },
            child: const Text('Copiar y cerrar'),
          ),
        ],
      ),
    );
  }
}

const _roleOptions = ['Admin', 'Superv.', 'Técnico'];

String _roleLabel(String role) => switch (role) {
  'admin' => 'Admin',
  'supervisor' => 'Superv.',
  _ => 'Técnico',
};

String _roleValue(String label) => UserDirectory.assignableRoles[_roleOptions.indexOf(label)];

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Detalle de la cuenta y, para el superadmin, rol, estado y vigencia.
class _UserSheet extends StatefulWidget {
  const _UserSheet({required this.user, required this.editable});
  final AppUser user;
  final bool editable;

  @override
  State<_UserSheet> createState() => _UserSheetState();
}

class _UserSheetState extends State<_UserSheet> {
  late final Profile? _p = widget.user.profile;
  late String _role = _p?.role ?? 'tecnico';
  late bool _active = widget.user.active;
  late DateTime _start = _p?.startsOn ?? _today();
  late DateTime? _end = _p?.endsOn;
  bool _saving = false;

  UserRole get _uiRole => switch (_role) {
    'superadmin' || 'admin' => UserRole.admin,
    'supervisor' => UserRole.supervisor,
    _ => UserRole.tecnico,
  };

  Future<void> _save() async {
    if (_end == null) {
      showAppSnack(
        context,
        'Elige la fecha de fin de la vigencia',
        icon: Icons.error_outline_rounded,
        color: AppColors.danger,
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await UserDirectory.instance.update(widget.user, role: _role, active: _active, startsOn: _start, endsOn: _end!);
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnack(
        context,
        'Cuenta de ${widget.user.name} actualizada',
        icon: Icons.check_circle_rounded,
        color: AppColors.success,
      );
    } on AuthFailure catch (e) {
      if (mounted) showAppSnack(context, e.message, icon: Icons.error_outline_rounded, color: AppColors.danger);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.editable) ...[
            const FieldLabel('Rol'),
            SegmentedPicker(
              options: _roleOptions,
              selected: _roleLabel(_role),
              onSelected: (v) => setState(() => _role = _roleValue(v)),
            ),
            const SizedBox(height: 16),
            _VigenciaFields(
              start: _start,
              end: _end,
              onStart: (d) => setState(() => _start = d),
              onEnd: (d) => setState(() => _end = d),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Expanded(child: Text('Cuenta activa', style: T.body)),
                Switch(value: _active, onChanged: (v) => setState(() => _active = v)),
              ],
            ),
            const SizedBox(height: 12),
            AppButton(
              _saving ? 'Guardando…' : 'Guardar cambios',
              icon: Icons.check_rounded,
              expand: true,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: 22),
          ] else if (p != null) ...[
            KeyValue(
              'Vigencia',
              p.isSuperadmin
                  ? 'No vence'
                  : '${fmtDate(p.startsOn)} – ${p.endsOn == null ? 'sin fin' : fmtDate(p.endsOn!)}',
            ),
            const SizedBox(height: 18),
          ],
          FieldLabel('Permisos de ${_uiRole.short.toLowerCase()}'),
          ..._permissions(_uiRole, superadmin: p?.isSuperadmin ?? false).map(
            (t) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text(t, style: T.small)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static List<String> _permissions(UserRole role, {required bool superadmin}) => switch (role) {
    UserRole.admin => [
      if (superadmin) ...['Crear cuentas de admin, supervisor y técnico', 'Activar, desactivar y renovar cuentas'],
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
      'Revisar información técnica y evidencia',
      'Registrar observaciones de revisión',
      'Solicitar correcciones',
      'Aprobar o rechazar levantamientos',
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
  };
}

/// Alta de cuenta con la Edge Function. Devuelve el usuario y la contraseña
/// para mostrarla una vez.
class _NewUserSheet extends StatefulWidget {
  const _NewUserSheet();

  @override
  State<_NewUserSheet> createState() => _NewUserSheetState();
}

class _NewUserSheetState extends State<_NewUserSheet> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController(text: _generatePassword());
  String _role = 'tecnico';
  DateTime _start = _today();
  DateTime? _end;
  bool _saving = false;
  String? _error;

  static String _generatePassword() {
    // Sin caracteres que se confunden al dictarla (0/O, 1/l/I).
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(12, (_) => chars[r.nextInt(chars.length)]).join();
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? get _validation {
    if (_name.text.trim().isEmpty) return 'Escribe el nombre.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim())) return 'Escribe un correo válido.';
    if (_password.text.length < 8) return 'La contraseña debe tener al menos 8 caracteres.';
    if (_end == null) return 'Elige hasta cuándo es válida la cuenta.';
    return null;
  }

  Future<void> _create() async {
    final err = _validation;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final user = await UserDirectory.instance.create(
        email: _email.text,
        password: _password.text,
        name: _name.text,
        role: _role,
        startsOn: _start,
        endsOn: _end!,
      );
      if (mounted) Navigator.pop(context, (user, _password.text));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Nombre completo', required: true),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Nombre y apellidos'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Correo', required: true),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'usuario@solaris.mx'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Contraseña inicial', required: true, hint: 'Mínimo 8'),
          TextField(
            controller: _password,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              suffixIcon: IconButton(
                tooltip: 'Generar otra',
                icon: const Icon(Icons.refresh_rounded, size: 19),
                onPressed: () => setState(() => _password.text = _generatePassword()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Rol', required: true),
          SegmentedPicker(
            options: _roleOptions,
            selected: _roleLabel(_role),
            onSelected: (v) => setState(() => _role = _roleValue(v)),
          ),
          const SizedBox(height: 16),
          _VigenciaFields(
            start: _start,
            end: _end,
            onStart: (d) => setState(() => _start = d),
            onEnd: (d) => setState(() => _end = d),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            InfoBanner(_error!, icon: Icons.error_outline_rounded, color: AppColors.danger),
          ],
          const SizedBox(height: 18),
          AppButton(
            _saving ? 'Creando…' : 'Crear usuario',
            icon: Icons.check_rounded,
            expand: true,
            onPressed: _saving ? null : _create,
          ),
        ],
      ),
    );
  }
}

/// Inicio y fin de la vigencia. El fin no puede quedar antes del inicio.
class _VigenciaFields extends StatelessWidget {
  const _VigenciaFields({required this.start, required this.end, required this.onStart, required this.onEnd});
  final DateTime start;
  final DateTime? end;
  final ValueChanged<DateTime> onStart;
  final ValueChanged<DateTime> onEnd;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      children: [
        Expanded(
          child: _date(context, 'Válida desde', start, DateTime(now.year - 1), (d) {
            onStart(d);
            if (end != null && end!.isBefore(d)) onEnd(d);
          }),
        ),
        const SizedBox(width: 10),
        Expanded(child: _date(context, 'Hasta', end, start, onEnd)),
      ],
    );
  }

  Widget _date(BuildContext context, String label, DateTime? value, DateTime first, ValueChanged<DateTime> onPick) {
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldLabel(label, required: true),
        GlassCard(
          color: AppColors.surfaceAlt,
          padding: const EdgeInsets.all(13),
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              firstDate: first,
              lastDate: DateTime(now.year + 5),
              initialDate: value == null || value.isBefore(first) ? first : value,
            );
            if (d != null) onPick(d);
          },
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  value == null ? 'Elegir' : fmtDate(value),
                  style: T.body.copyWith(color: value == null ? AppColors.textMuted : AppColors.textPrimary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
