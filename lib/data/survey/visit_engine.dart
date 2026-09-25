import 'entities.dart';
import 'template.dart';

/// Una pregunta de la plantilla ubicada en una instancia concreta de su bloque.
class ResolvedQuestion {
  const ResolvedQuestion({
    required this.section,
    required this.sectionIndex,
    required this.group,
    required this.groupIndex,
    required this.question,
    required this.questionIndex,
    required this.instance,
  });

  final SectionDef section;
  final int sectionIndex;
  final GroupDef group;
  final int groupIndex;
  final QuestionDef question;
  final int questionIndex;
  final int instance;

  AnswerKey get key => AnswerKey(group.id, instance, question.id);
  String get code => TemplateDef.code(sectionIndex, groupIndex, questionIndex);
  String get instanceName => group.instanceName(instance);

  /// Texto con contexto para listas de pendientes: "Placa de datos · Transformador 2".
  String get contextLabel => group.repeatable ? '${question.label} · $instanceName' : question.label;
}

enum PendingKind { blocking, optional, justified }

class Pending {
  const Pending(this.question, this.kind, [this.justification]);
  final ResolvedQuestion question;
  final PendingKind kind;
  final String? justification;
}

class SectionProgress {
  const SectionProgress(this.answered, this.total, this.requiredPending);
  final int answered;
  final int total;
  final int requiredPending;
  double get value => total == 0 ? 1 : answered / total;
  bool get complete => requiredPending == 0 && answered == total;
}

/// Evalúa una visita contra su plantilla: qué preguntas aplican (campos
/// condicionales y bloques repetibles), cuáles están respondidas, el avance y
/// los pendientes obligatorios u opcionales.
class VisitEngine {
  VisitEngine({
    required this.template,
    required this.instances,
    required this.answers,
    required List<Evidence> evidences,
    this.projectDocCategories = const {},
    this.justifications = const {},
  }) {
    for (final e in evidences) {
      _evidenceCount[e.key] = (_evidenceCount[e.key] ?? 0) + 1;
    }
  }

  final TemplateDef template;
  final Map<String, int> instances;
  final Map<String, String> answers;
  final Set<String> projectDocCategories;
  final Map<String, String> justifications;
  final _evidenceCount = <String, int>{};

  int instanceCount(GroupDef g) => g.repeatable ? (instances[g.id] ?? 1) : 1;

  int evidenceCount(AnswerKey key) => _evidenceCount[key.toString()] ?? 0;

  String? value(AnswerKey key) => answers[key.toString()];

  /// Valores de una opción múltiple, guardados separados por `|`.
  static List<String> splitMulti(String? v) =>
      v == null || v.isEmpty ? const [] : v.split('|').where((s) => s.isNotEmpty).toList();

  bool isVisible(GroupDef g, int instance, QuestionDef q, [int depth = 0]) {
    final cond = q.showIf;
    if (cond == null) return true;
    if (depth > 8) return false; // condición circular creada en el editor
    final controller = g.questions.where((x) => x.id == cond.questionId).firstOrNull;
    if (controller == null) return true;
    if (!isVisible(g, instance, controller, depth + 1)) return false;
    final v = value(AnswerKey(g.id, instance, controller.id));
    if (controller.type == QType.multi) return splitMulti(v).contains(cond.equals);
    return v == cond.equals;
  }

  bool isAnswered(ResolvedQuestion rq) {
    final q = rq.question;
    if (q.type.isEvidence) {
      if (q.type == QType.document &&
          q.docCategory.isNotEmpty &&
          projectDocCategories.contains(q.docCategory)) {
        return true;
      }
      return evidenceCount(rq.key) >= (q.minCount < 1 ? 1 : q.minCount);
    }
    final v = value(rq.key);
    return v != null && v.trim().isNotEmpty;
  }

  Iterable<ResolvedQuestion> questions({SectionDef? only, bool visibleOnly = true}) sync* {
    for (var si = 0; si < template.sections.length; si++) {
      final s = template.sections[si];
      if (only != null && s.id != only.id) continue;
      for (var gi = 0; gi < s.groups.length; gi++) {
        final g = s.groups[gi];
        for (var inst = 0; inst < instanceCount(g); inst++) {
          for (var qi = 0; qi < g.questions.length; qi++) {
            final q = g.questions[qi];
            if (visibleOnly && !isVisible(g, inst, q)) continue;
            yield ResolvedQuestion(
              section: s,
              sectionIndex: si,
              group: g,
              groupIndex: gi,
              question: q,
              questionIndex: qi,
              instance: inst,
            );
          }
        }
      }
    }
  }

  SectionProgress sectionProgress(SectionDef s) => _progressOf(questions(only: s));

  SectionProgress groupProgress(SectionDef s, GroupDef g, int instance) =>
      _progressOf(questions(only: s).where((rq) => rq.group.id == g.id && rq.instance == instance));

  SectionProgress get overall => _progressOf(questions());

  SectionProgress _progressOf(Iterable<ResolvedQuestion> list) {
    var answered = 0, total = 0, req = 0;
    for (final rq in list) {
      total++;
      if (isAnswered(rq)) {
        answered++;
      } else if (rq.question.required && !justifications.containsKey(rq.key.toString())) {
        req++;
      }
    }
    return SectionProgress(answered, total, req);
  }

  List<Pending> pendings() {
    final out = <Pending>[];
    for (final rq in questions()) {
      if (isAnswered(rq)) continue;
      if (!rq.question.required) {
        out.add(Pending(rq, PendingKind.optional));
      } else if (justifications.containsKey(rq.key.toString())) {
        out.add(Pending(rq, PendingKind.justified, justifications[rq.key.toString()]));
      } else {
        out.add(Pending(rq, PendingKind.blocking));
      }
    }
    return out;
  }

  int get blockingCount => pendings().where((p) => p.kind == PendingKind.blocking).length;

  /// Un levantamiento sólo se cierra sin pendientes obligatorios sin justificar.
  bool get canClose => blockingCount == 0;
}
