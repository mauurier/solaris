import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/ui.dart';
import '../../data/survey/entities.dart';
import '../../data/survey_store.dart';
import '../shell/home_shell.dart';

/// Clientes guardados en el teléfono (tabla `cliente`). Sus sitios se crean
/// desde el alta de proyecto.
class ClientsScreen extends StatelessWidget {
  const ClientsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SurveyStore.instance;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => DetailScaffold(
        title: 'Clientes',
        subtitle: '${store.clients.length} registrados',
        bottomBar: AppButton(
          'Nuevo cliente',
          icon: Icons.add_business_rounded,
          expand: true,
          onPressed: () => showClientSheet(context),
        ),
        child: store.clients.isEmpty
            ? const EmptyState(
                icon: Icons.business_rounded,
                title: 'Sin clientes',
                message: 'Da de alta el primero para poder crear proyectos.',
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
                itemCount: store.clients.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) => _card(context, store, store.clients[i]),
              ),
      ),
    );
  }

  Widget _card(BuildContext context, SurveyStore store, SurveyClient c) {
    final sites = store.sitesOf(c.id).length;
    final projects = store.projectsOfClient(c.id);
    return GlassCard(
      onTap: () => showClientSheet(context, editing: c),
      child: Row(
        children: [
          InitialsAvatar(c.name.substring(0, 1).toUpperCase(), size: 44, color: AppColors.blue),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: T.h3),
                const SizedBox(height: 4),
                Text(c.rfc.isEmpty ? 'Sin RFC' : 'RFC ${c.rfc}', style: T.tiny),
                if (c.contact.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Flexible(child: Text(c.contact, style: T.tiny, overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$projects', style: T.h2.copyWith(color: AppColors.accent)),
              Text(projects == 1 ? 'proyecto' : 'proyectos', style: T.tiny),
              Text('$sites ${sites == 1 ? 'sitio' : 'sitios'}', style: T.tiny),
            ],
          ),
        ],
      ),
    );
  }
}

/// Alta o edición de un cliente. Devuelve el cliente guardado.
Future<SurveyClient?> showClientSheet(BuildContext context, {SurveyClient? editing}) => showAppSheet<SurveyClient>(
      context,
      title: editing == null ? 'Nuevo cliente' : 'Editar cliente',
      child: _ClientForm(editing: editing),
    );

class _ClientForm extends StatefulWidget {
  const _ClientForm({this.editing});
  final SurveyClient? editing;

  @override
  State<_ClientForm> createState() => _ClientFormState();
}

class _ClientFormState extends State<_ClientForm> {
  final _store = SurveyStore.instance;
  late final _name = TextEditingController(text: widget.editing?.name);
  late final _rfc = TextEditingController(text: widget.editing?.rfc);
  late final _contact = TextEditingController(text: widget.editing?.contact);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _rfc.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final editing = widget.editing;
    final error = _store.validateClient(_name.text, rfc: _rfc.text, except: editing);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    final SurveyClient saved;
    if (editing == null) {
      saved = await _store.addClient(_name.text, rfc: _rfc.text, contact: _contact.text);
    } else {
      editing
        ..name = _name.text.trim()
        ..rfc = _rfc.text.trim().toUpperCase()
        ..contact = _contact.text.trim();
      await _store.updateClient(editing);
      saved = editing;
    }
    if (mounted) Navigator.pop(context, saved);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Razón social', required: true),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(hintText: 'Ej. TRUPER'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('RFC'),
          TextField(
            controller: _rfc,
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            decoration: const InputDecoration(hintText: 'Ej. TRU850214QW3'),
          ),
          const SizedBox(height: 16),
          const FieldLabel('Contacto'),
          TextField(controller: _contact, decoration: const InputDecoration(hintText: 'Nombre de quien atiende')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            InfoBanner(_error!, icon: Icons.error_outline_rounded, color: AppColors.danger),
          ],
          const SizedBox(height: 18),
          AppButton('Guardar cliente', icon: Icons.check_rounded, expand: true, onPressed: _save),
        ],
      ),
    );
  }
}
