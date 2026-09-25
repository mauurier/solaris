import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/template.dart';
import '../shell/home_shell.dart';
import '../visits/question_field.dart';

/// Edición de una pregunta: tipo, obligatoriedad, condición y dónde caen sus
/// archivos en el ZIP. Devuelve la pregunta editada con `Navigator.pop`.
class QuestionEditorScreen extends StatefulWidget {
  const QuestionEditorScreen({super.key, required this.group, required this.question});
  final GroupDef group;
  final QuestionDef question;

  @override
  State<QuestionEditorScreen> createState() => _QuestionEditorScreenState();
}

class _QuestionEditorScreenState extends State<QuestionEditorScreen> {
  late final QuestionDef q = widget.question;
  late final _label = TextEditingController(text: q.label);
  late final _hint = TextEditingController(text: q.hint);
  late final _unit = TextEditingController(text: q.unit);
  late final _options = TextEditingController(text: q.options.join('\n'));
  late final _prefix = TextEditingController(text: q.prefix);

  bool get _isNew => q.label.isEmpty;

  @override
  void dispose() {
    for (final c in [_label, _hint, _unit, _options, _prefix]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Preguntas del mismo bloque que pueden controlar la visibilidad de esta.
  List<QuestionDef> get _controllers => widget.group.questions
      .where((o) => o.id != q.id && (o.type == QType.yesNo || o.type == QType.single || o.type == QType.multi))
      .toList();

  List<String> _valuesOf(QuestionDef c) => c.type == QType.yesNo ? const ['Sí', 'No'] : c.options;

  List<String> get _folderOptions => [
        for (final f in Folders.all)
          if (f != Folders.fotos) f,
        if (widget.group.repeatable) ...[
          '${Folders.acometida}/{INSTANCIA}',
          '${Folders.tableros}/{INSTANCIA}',
          '${Folders.fvExistente}/{INSTANCIA}',
        ],
      ];

  void _save() {
    final label = _label.text.trim();
    final options = _options.text.split('\n').map((o) => o.trim()).where((o) => o.isNotEmpty).toList();
    if (label.isEmpty) {
      showAppSnack(context, 'Escribe el texto de la pregunta', color: AppColors.danger);
      return;
    }
    if (q.type.hasOptions && options.length < 2) {
      showAppSnack(context, 'Agrega al menos dos opciones, una por renglón', color: AppColors.danger);
      return;
    }
    if (q.type == QType.scale && q.max <= q.min) {
      showAppSnack(context, 'El máximo de la escala debe ser mayor que el mínimo', color: AppColors.danger);
      return;
    }
    q
      ..label = label
      ..hint = _hint.text.trim()
      ..unit = (q.type == QType.number || q.type == QType.scale) ? _unit.text.trim() : ''
      ..options = q.type.hasOptions ? options : []
      ..prefix = q.type.isEvidence ? _prefix.text.trim().toUpperCase() : '';
    if (!q.type.isEvidence) q.folder = '';
    Navigator.pop(context, q);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controllers.where((c) => c.id == q.showIf?.questionId).firstOrNull;

    return DetailScaffold(
      title: _isNew ? 'Nueva pregunta' : 'Editar pregunta',
      subtitle: widget.group.title,
      bottomBar: AppButton(_isNew ? 'Agregar pregunta' : 'Aplicar cambios',
          icon: Icons.check_rounded, expand: true, onPressed: _save),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          const FieldLabel('Pregunta', required: true),
          TextField(
            controller: _label,
            autofocus: _isNew,
            maxLines: 2,
            minLines: 1,
            decoration: const InputDecoration(hintText: 'Ej. ¿Se cuenta con fotografía legible del ITM principal?'),
          ),
          const SizedBox(height: 18),
          const FieldLabel('Tipo de respuesta'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in QType.values)
                ChoicePill(label: t.label, selected: q.type == t, onTap: () => setState(() => q.type = t)),
            ],
          ),
          const SizedBox(height: 14),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Obligatoria', style: T.body),
            subtitle: const Text('Si falta, impide cerrar el levantamiento', style: T.tiny),
            value: q.required,
            onChanged: (v) => setState(() => q.required = v),
          ),
          if (q.type.hasOptions) ...[
            const SizedBox(height: 8),
            const FieldLabel('Opciones', required: true, hint: 'Una por renglón'),
            TextField(controller: _options, maxLines: 6, minLines: 3),
          ],
          if (q.type == QType.number || q.type == QType.scale) ...[
            const SizedBox(height: 8),
            const FieldLabel('Unidad', hint: 'V, A, kVA, m…'),
            TextField(controller: _unit),
          ],
          if (q.type == QType.scale) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _stepper('Mínimo', q.min, (v) => setState(() => q.min = v))),
                const SizedBox(width: 12),
                Expanded(child: _stepper('Máximo', q.max, (v) => setState(() => q.max = v))),
              ],
            ),
          ],
          if (q.type == QType.photo || q.type == QType.video) ...[
            const SizedBox(height: 14),
            _stepper('Mínimo de archivos', q.minCount, (v) => setState(() => q.minCount = v.clamp(1, 20))),
          ],
          const SizedBox(height: 14),
          const FieldLabel('Ayuda para el técnico', hint: 'Opcional'),
          TextField(controller: _hint, maxLines: 3, minLines: 1),

          // ------------------------------------------------------ condición
          const SizedBox(height: 22),
          const SectionLabel('Mostrar sólo si…'),
          if (_controllers.isEmpty)
            const Text('Agrega antes una pregunta Sí/No o de opciones en este bloque para usarla como condición.',
                style: T.tiny)
          else ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoicePill(label: 'Siempre visible', selected: q.showIf == null, onTap: () => setState(() => q.showIf = null)),
                for (final c in _controllers)
                  ChoicePill(
                    label: c.label.length > 34 ? '${c.label.substring(0, 34)}…' : c.label,
                    selected: controller?.id == c.id,
                    onTap: () => setState(() => q.showIf = ShowIf(questionId: c.id, equals: _valuesOf(c).first)),
                  ),
              ],
            ),
            if (controller != null) ...[
              const SizedBox(height: 12),
              const FieldLabel('…cuando la respuesta sea'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final v in _valuesOf(controller))
                    ChoicePill(
                      label: v,
                      selected: q.showIf?.equals == v,
                      onTap: () => setState(() => q.showIf = ShowIf(questionId: controller.id, equals: v)),
                    ),
                ],
              ),
            ],
          ],

          // ------------------------------------------------------ archivos
          if (q.type.isEvidence) ...[
            const SizedBox(height: 22),
            const SectionLabel('Organización en el ZIP'),
            const FieldLabel('Carpeta'),
            DropdownButtonFormField<String>(
              initialValue: _folderOptions.contains(q.folder) ? q.folder : null,
              isExpanded: true,
              dropdownColor: AppColors.surfaceHigh,
              hint: const Text('Evidencias Adicionales'),
              items: [
                for (final f in _folderOptions)
                  DropdownMenuItem(value: f, child: Text(f, overflow: TextOverflow.ellipsis, style: T.small)),
              ],
              onChanged: (v) => setState(() => q.folder = v ?? ''),
            ),
            const SizedBox(height: 14),
            FieldLabel('Prefijo de archivo', hint: widget.group.repeatable ? 'Admite {INSTANCIA}' : null),
            TextField(
              controller: _prefix,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: widget.group.repeatable ? '{INSTANCIA}_PLACA' : 'MEDIDOR_CFE',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Ej. ${(_prefix.text.isEmpty ? 'EVIDENCIA' : _prefix.text.toUpperCase()).replaceAll('{INSTANCIA}', widget.group.repeatable ? widget.group.instanceName(0).toUpperCase().replaceAll(' ', '_') : '')}_001.jpg',
              style: T.mono.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepper(String label, int value, ValueChanged<int> onChanged) {
    return GlassCard(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: T.small)),
          IconButton(onPressed: () => onChanged(value - 1), icon: const Icon(Icons.remove_rounded, size: 18)),
          Text('$value', style: T.h3),
          IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add_rounded, size: 18)),
        ],
      ),
    );
  }
}
