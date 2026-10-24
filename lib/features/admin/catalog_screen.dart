import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/catalog.dart';
import '../../data/survey_store.dart';
import '../../main.dart';
import '../shell/home_shell.dart';

/// Catálogos que edita el administrador: tipos de proyecto y motivos de visita.
class CatalogsScreen extends StatelessWidget {
  const CatalogsScreen({super.key});

  static const _icons = {
    CatalogKind.projectTypes: (Icons.category_rounded, AppColors.blue),
    CatalogKind.visitMotives: (Icons.event_note_rounded, AppColors.teal),
  };

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => DetailScaffold(
        title: 'Catálogos',
        subtitle: 'Opciones que aparecen al crear proyectos y visitas',
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
          children: [
            for (final kind in CatalogKind.values) ...[
              GlassCard(
                onTap: () => push(context, CatalogScreen(kind: kind)),
                child: Row(
                  children: [
                    IconBadge(_icons[kind]!.$1, color: _icons[kind]!.$2, size: 44),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(kind.title, style: T.h3),
                          const SizedBox(height: 4),
                          Text(
                            store.catalog(kind).map((i) => i.name).join(' · '),
                            style: T.tiny,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${store.catalog(kind).length}', style: T.h2.copyWith(color: AppColors.accent)),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

/// Lista de un catálogo: agregar, renombrar o eliminar elementos.
class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, required this.kind});
  final CatalogKind kind;

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final items = store.catalog(kind);
        return DetailScaffold(
          title: kind.title,
          subtitle: kind.usedWhen,
          bottomBar: AppButton(
            'Nuevo ${kind.singular}',
            icon: Icons.add_rounded,
            expand: true,
            onPressed: () => showCatalogItemSheet(context, kind),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final item = items[i];
              final uses = store.catalogUses(kind, item.name);
              return GlassCard(
                onTap: () => showCatalogItemSheet(context, kind, editing: item),
                child: Row(
                  children: [
                    Expanded(child: Text(item.name, style: T.h3, maxLines: 2, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('$uses', style: T.h2.copyWith(color: AppColors.accent)),
                        Text('${kind.usedBy}${uses == 1 ? '' : 's'}', style: T.tiny),
                      ],
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Alta o edición de un elemento. Devuelve el elemento creado o editado, o
/// `null` si se cancela o se elimina.
Future<CatalogItem?> showCatalogItemSheet(BuildContext context, CatalogKind kind, {CatalogItem? editing}) {
  return showAppSheet<CatalogItem>(
    context,
    title: editing == null ? 'Nuevo ${kind.singular}' : 'Editar ${kind.singular}',
    subtitle: editing == null
        ? kind.usedWhen
        : 'Las ${kind.usedBy}s que lo usan se actualizan con el nuevo nombre.',
    child: _CatalogItemForm(kind: kind, editing: editing),
  );
}

class _CatalogItemForm extends StatefulWidget {
  const _CatalogItemForm({required this.kind, this.editing});
  final CatalogKind kind;
  final CatalogItem? editing;

  @override
  State<_CatalogItemForm> createState() => _CatalogItemFormState();
}

class _CatalogItemFormState extends State<_CatalogItemForm> {
  final _store = SurveyStore.instance;
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  String? _error;
  bool _saving = false;

  CatalogKind get kind => widget.kind;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final error = _store.validateCatalogName(kind, _name.text, except: widget.editing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() => _saving = true);
    final editing = widget.editing;
    final CatalogItem result;
    if (editing == null) {
      result = await _store.addCatalogItem(kind, _name.text);
    } else {
      await _store.renameCatalogItem(kind, editing, _name.text);
      result = editing;
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _delete() async {
    await _store.removeCatalogItem(kind, widget.editing!);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.editing;
    final uses = editing == null ? 0 : _store.catalogUses(kind, editing.name);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const FieldLabel('Nombre', required: true),
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: kind.hint, errorText: _error),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 18),
          AppButton(
            editing == null ? 'Agregar ${kind.singular}' : 'Guardar cambios',
            icon: Icons.check_rounded,
            expand: true,
            onPressed: _saving ? null : _save,
          ),
          if (editing != null) ...[
            const SizedBox(height: 10),
            AppButton(
              'Eliminar ${kind.singular}',
              icon: Icons.delete_outline_rounded,
              kind: AppButtonKind.danger,
              expand: true,
              onPressed: _saving || uses > 0 ? null : _delete,
            ),
            if (uses > 0) ...[
              const SizedBox(height: 8),
              Text(
                'No se puede eliminar: lo usa${uses == 1 ? '' : 'n'} $uses ${kind.usedBy}${uses == 1 ? '' : 's'}.',
                style: T.tiny,
              ),
            ],
          ],
        ],
      ),
    );
  }
}
