import 'package:flutter/material.dart';

import '../../core/services/formatting.dart';
import '../../core/services/location_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../../data/survey/entities.dart';
import '../../data/survey/template.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../shell/home_shell.dart';
import '../visits/question_field.dart';
import 'project_detail_screen.dart';
import 'project_documents.dart';

/// Alta de proyecto en cuatro pasos. Al crear, los documentos se copian a la
/// app y se genera la primera visita asignada al técnico.
class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  static const _steps = ['Datos', 'Ubicación', 'Equipo', 'Plantilla y documentos'];
  static const _types = ['Viabilidad FV', 'Levantamiento eléctrico', 'Auditoría FV'];

  final _store = SurveyStore.instance;
  int _step = 0;
  bool _saving = false;

  final _code = TextEditingController();
  final _name = TextEditingController();
  final _site = TextEditingController();
  final _address = TextEditingController();
  final _coordsText = TextEditingController();
  final _description = TextEditingController();

  String? _client;
  String _type = _types.first;
  DateTime? _date;
  bool _locating = false;

  late String _supervisor = Mock.users.firstWhere((u) => u.role == UserRole.supervisor).name;
  final _techs = <String>{};
  late TemplateDef? _template = _store.activeTemplates.firstOrNull;
  final _docs = <PickedDocument>[];

  @override
  void dispose() {
    for (final c in [_code, _name, _site, _address, _coordsText, _description]) {
      c.dispose();
    }
    super.dispose();
  }

  String? get _stepError => switch (_step) {
        0 => _code.text.trim().isEmpty
            ? 'Escribe la clave del proyecto'
            : _name.text.trim().isEmpty
                ? 'Escribe el nombre del proyecto'
                : _client == null
                    ? 'Elige el cliente'
                    : null,
        1 => _site.text.trim().isEmpty
            ? 'Escribe el nombre del sitio'
            : _coordsText.text.trim().isNotEmpty && GeoPoint.tryParse(_coordsText.text) == null
                ? 'Coordenadas inválidas: usa "latitud, longitud"'
                : null,
        2 => _techs.isEmpty ? 'Asigna al menos un técnico' : null,
        _ => _template == null ? 'Elige una plantilla' : null,
      };

  Future<void> _next() async {
    FocusScope.of(context).unfocus();
    final err = _stepError;
    if (err != null) {
      showAppSnack(context, err, icon: Icons.error_outline_rounded, color: AppColors.danger);
      return;
    }
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      return;
    }
    setState(() => _saving = true);
    try {
      final project = await _store.createProject(
        code: _code.text,
        name: _name.text,
        client: _client!,
        site: _site.text,
        address: _address.text,
        coords: GeoPoint.tryParse(_coordsText.text),
        scheduledAt: _date,
        supervisor: _supervisor,
        technicians: _techs.toList(),
        template: _template!,
        type: _type,
        description: _description.text,
        docs: _docs,
      );
      if (!mounted) return;
      Navigator.pop(context);
      push(context, ProjectDetailScreen(project: project));
      showAppSnack(context, 'Proyecto creado · visita asignada a ${_techs.first}',
          icon: Icons.check_circle_rounded, color: AppColors.success);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showAppSnack(context, 'No se pudo crear el proyecto: $e', color: AppColors.danger);
      }
    }
  }

  Future<void> _useGps() async {
    setState(() => _locating = true);
    final fix = await LocationService.current(timeout: const Duration(seconds: 10));
    if (!mounted) return;
    setState(() => _locating = false);
    if (fix.point == null) {
      showAppSnack(context, fix.problem, icon: Icons.location_off_rounded, color: AppColors.warning);
    } else {
      _coordsText.text = fix.point!.label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = _step == _steps.length - 1;
    return DetailScaffold(
      title: 'Nuevo proyecto',
      subtitle: 'Paso ${_step + 1} de ${_steps.length} · ${_steps[_step]}',
      bottomBar: Row(
        children: [
          if (_step > 0) ...[
            AppButton('Atrás', kind: AppButtonKind.secondary, onPressed: () => setState(() => _step--)),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: AppButton(
              _saving ? 'Creando…' : last ? 'Crear proyecto' : 'Continuar',
              icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
              expand: true,
              onPressed: _saving ? null : _next,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Row(
              children: List.generate(_steps.length, (i) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: i == _steps.length - 1 ? 0 : 6),
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: i <= _step ? AppColors.accent : AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          Expanded(
            child: switch (_step) {
              1 => _location(),
              2 => _team(),
              3 => _templateAndDocs(),
              _ => _data(),
            },
          ),
        ],
      ),
    );
  }

  Widget _wrap(String key, List<Widget> children) => ListView(
        key: ValueKey(key),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: children,
      );

  Widget _data() => _wrap('data', [
        const FieldLabel('Clave del proyecto', required: true, hint: 'Nombra el ZIP y los archivos'),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'Ej. REY01202'),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Nombre del proyecto', required: true),
        TextField(controller: _name, decoration: const InputDecoration(hintText: 'Ej. PROLOGIS Reynosa DSV')),
        const SizedBox(height: 18),
        const FieldLabel('Cliente', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in Mock.clients)
              ChoicePill(label: c.name, selected: _client == c.name, onTap: () => setState(() => _client = c.name)),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Tipo de proyecto', required: true),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in _types) ChoicePill(label: t, selected: _type == t, onTap: () => setState(() => _type = t)),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Descripción'),
        TextField(
          controller: _description,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Alcance y consideraciones del levantamiento…'),
        ),
      ]);

  Widget _location() => _wrap('loc', [
        const FieldLabel('Nombre del sitio', required: true),
        TextField(controller: _site, decoration: const InputDecoration(hintText: 'Ej. Nave DSV · Parque Colonial')),
        const SizedBox(height: 18),
        const FieldLabel('Dirección'),
        TextField(
          controller: _address,
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Calle, número, colonia, ciudad, estado'),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Coordenadas', hint: 'latitud, longitud'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _coordsText,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(hintText: '26.07346, -98.38151'),
              ),
            ),
            const SizedBox(width: 10),
            AppButton(
              _locating ? '…' : 'Mi ubicación',
              icon: Icons.my_location_rounded,
              kind: AppButtonKind.secondary,
              compact: true,
              onPressed: _locating ? null : _useGps,
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text('Úsalo si estás en el sitio; si no, pega las coordenadas del mapa.', style: T.tiny),
        const SizedBox(height: 18),
        const FieldLabel('Fecha programada'),
        GlassCard(
          color: AppColors.surfaceAlt,
          padding: const EdgeInsets.all(14),
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              firstDate: DateTime(now.year - 1),
              lastDate: DateTime(now.year + 2),
              initialDate: _date ?? now,
            );
            if (d != null) setState(() => _date = d);
          },
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 17, color: AppColors.textSecondary),
              const SizedBox(width: 12),
              Text(_date == null ? 'Elegir fecha' : fmtDate(_date!),
                  style: T.body.copyWith(color: _date == null ? AppColors.textMuted : AppColors.textPrimary)),
            ],
          ),
        ),
      ]);

  Widget _team() {
    final supervisors = Mock.users.where((u) => u.role == UserRole.supervisor && u.active).toList();
    final techs = Mock.users.where((u) => u.role == UserRole.tecnico && u.active).toList();
    return _wrap('team', [
      const FieldLabel('Supervisor', required: true),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in supervisors)
            ChoicePill(label: s.name, selected: _supervisor == s.name, onTap: () => setState(() => _supervisor = s.name)),
        ],
      ),
      const SizedBox(height: 20),
      const FieldLabel('Técnicos asignados', required: true, hint: 'El primero recibe la visita'),
      for (final u in techs)
        Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: GlassCard(
            color: AppColors.surfaceAlt,
            padding: const EdgeInsets.all(11),
            borderColor: _techs.contains(u.name) ? AppColors.accent.withValues(alpha: 0.4) : null,
            onTap: () => setState(() => _techs.contains(u.name) ? _techs.remove(u.name) : _techs.add(u.name)),
            child: Row(
              children: [
                InitialsAvatar(u.initials, size: 34, color: _techs.contains(u.name) ? AppColors.accent : AppColors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: T.h3.copyWith(fontSize: 14)),
                      Text(u.email, style: T.tiny),
                    ],
                  ),
                ),
                Icon(
                  _techs.contains(u.name) ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 20,
                  color: _techs.contains(u.name) ? AppColors.accent : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
    ]);
  }

  Widget _templateAndDocs() => _wrap('tpl', [
        const FieldLabel('Plantilla de levantamiento', required: true),
        for (final t in _store.activeTemplates)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: GlassCard(
              borderColor: _template?.id == t.id ? AppColors.accent.withValues(alpha: 0.45) : null,
              color: _template?.id == t.id ? AppColors.accent.withValues(alpha: 0.05) : AppColors.surfaceAlt,
              onTap: () => setState(() => _template = t),
              child: Row(
                children: [
                  IconBadge(Icons.dashboard_customize_rounded,
                      color: _template?.id == t.id ? AppColors.accent : AppColors.textMuted, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.name, style: T.h3),
                        const SizedBox(height: 3),
                        Text('${t.version} · ${t.sections.length} secciones · ${t.questionCount} preguntas',
                            style: T.tiny),
                      ],
                    ),
                  ),
                  Icon(
                    _template?.id == t.id ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    size: 20,
                    color: _template?.id == t.id ? AppColors.accent : AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const FieldLabel('Documentos iniciales', hint: 'Opcional'),
        const Text(
          'Súbelos desde Archivos, iCloud o Drive. Quedan en la carpeta que les corresponde del ZIP y, si la '
          'plantilla los pide, cuentan como respondidos.',
          style: T.tiny,
        ),
        const SizedBox(height: 12),
        for (final cat in DocCategory.all)
          DocCategoryCard(
            category: cat,
            files: [
              for (final d in _docs.where((d) => d.category == cat.id))
                (name: d.name, size: d.file.existsSync() ? d.file.lengthSync() : 0),
            ],
            onAdd: () async {
              final picked = await pickDocuments(context, cat.id);
              setState(() => _docs.addAll(picked));
            },
            onRemove: (i) => setState(() => _docs.remove(_docs.where((d) => d.category == cat.id).elementAt(i))),
          ),
      ]);
}
