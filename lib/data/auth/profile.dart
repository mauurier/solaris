import '../../core/services/formatting.dart';
import '../models.dart';

/// Si la cuenta puede usar la app hoy. Lo mismo que revisa `mi_rol()` en la
/// base; aquí se repite para avisar con un mensaje claro y para poder
/// revisarlo sin conexión.
enum AccountStatus { ok, inactive, notStarted, expired }

/// Fila de la tabla `perfil` del usuario con sesión.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.active,
    required this.startsOn,
    this.endsOn,
    this.deleted = false,
  });

  final String id;
  final String email;
  final String name;

  /// Rol tal como está en la base: superadmin | admin | supervisor | tecnico.
  final String role;
  final bool active;
  final DateTime startsOn;

  /// Nulo = no vence.
  final DateTime? endsOn;
  final bool deleted;

  bool get isSuperadmin => role == 'superadmin';

  /// Rol con el que se arma la interfaz. El superadmin usa la del admin.
  UserRole get uiRole => switch (role) {
        'superadmin' || 'admin' => UserRole.admin,
        'supervisor' => UserRole.supervisor,
        _ => UserRole.tecnico,
      };

  String get initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return (words.first[0] + words[1][0]).toUpperCase();
  }

  AccountStatus statusOn(DateTime now) {
    if (!active || deleted) return AccountStatus.inactive;
    if (isSuperadmin) return AccountStatus.ok;
    final today = DateTime(now.year, now.month, now.day);
    if (today.isBefore(startsOn)) return AccountStatus.notStarted;
    if (endsOn != null && today.isAfter(endsOn!)) return AccountStatus.expired;
    return AccountStatus.ok;
  }

  /// Mensaje para el usuario cuando la cuenta no puede entrar; nulo si sí puede.
  String? blockedMessage(DateTime now) => switch (statusOn(now)) {
        AccountStatus.ok => null,
        AccountStatus.inactive => 'Tu cuenta está desactivada. Pide al superadmin que la active.',
        AccountStatus.notStarted => 'Tu cuenta estará activa a partir del ${fmtDate(startsOn)}.',
        AccountStatus.expired =>
          'Tu cuenta venció el ${fmtDate(endsOn!)}. Pide al superadmin que la renueve.',
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'] as String,
        email: (j['email'] as String?) ?? '',
        name: (j['nombre'] as String?) ?? '',
        role: j['rol'] as String,
        active: j['activo'] as bool,
        startsOn: DateTime.parse(j['inicio_vigencia'] as String),
        endsOn: j['fin_vigencia'] == null ? null : DateTime.parse(j['fin_vigencia'] as String),
        deleted: j['eliminado_en'] != null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': name,
        'rol': role,
        'activo': active,
        'inicio_vigencia': _date(startsOn),
        'fin_vigencia': endsOn == null ? null : _date(endsOn!),
        'eliminado_en': deleted ? DateTime.now().toIso8601String() : null,
      };

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);
}
