import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/auth/profile.dart';
import 'package:proyecto_app/data/models.dart';

Profile _perfil({
  String rol = 'tecnico',
  bool activo = true,
  String inicio = '2026-11-01',
  String? fin = '2026-12-15',
  bool eliminado = false,
}) =>
    Profile.fromJson({
      'id': 'u1',
      'email': 'tec@solaris.mx',
      'nombre': 'Juan Pérez',
      'rol': rol,
      'activo': activo,
      'inicio_vigencia': inicio,
      'fin_vigencia': fin,
      'eliminado_en': eliminado ? '2026-10-30T00:00:00Z' : null,
    });

void main() {
  group('vigencia de la cuenta', () {
    test('dentro del periodo, incluidos el primer y el último día', () {
      final p = _perfil();
      expect(p.statusOn(DateTime(2026, 11, 1, 8)), AccountStatus.ok);
      expect(p.statusOn(DateTime(2026, 12, 15, 23, 59)), AccountStatus.ok);
    });

    test('antes de empezar y después de vencer', () {
      final p = _perfil();
      expect(p.statusOn(DateTime(2026, 10, 31, 23)), AccountStatus.notStarted);
      expect(p.statusOn(DateTime(2026, 12, 16)), AccountStatus.expired);
      expect(p.blockedMessage(DateTime(2026, 12, 16)), contains('15 Dic 2026'));
      expect(p.blockedMessage(DateTime(2026, 10, 31)), contains('01 Nov 2026'));
    });

    test('sin fecha de fin no vence', () {
      expect(_perfil(fin: null).statusOn(DateTime(2030, 1, 1)), AccountStatus.ok);
    });

    test('inactiva o eliminada no entra aunque esté en fechas', () {
      expect(_perfil(activo: false).statusOn(DateTime(2026, 11, 20)), AccountStatus.inactive);
      expect(_perfil(eliminado: true).statusOn(DateTime(2026, 11, 20)), AccountStatus.inactive);
    });

    test('el superadmin no vence pero sí puede desactivarse', () {
      expect(_perfil(rol: 'superadmin', fin: null, inicio: '2026-10-29').statusOn(DateTime(2040, 1, 1)),
          AccountStatus.ok);
      expect(_perfil(rol: 'superadmin', activo: false).statusOn(DateTime(2026, 11, 20)), AccountStatus.inactive);
    });
  });

  test('rol de la interfaz e iniciales', () {
    expect(_perfil(rol: 'superadmin').uiRole, UserRole.admin);
    expect(_perfil(rol: 'supervisor').uiRole, UserRole.supervisor);
    expect(_perfil().uiRole, UserRole.tecnico);
    expect(_perfil().initials, 'JP');
  });

  test('se guarda y se lee igual (perfil para usar sin conexión)', () {
    final p = _perfil();
    final copia = Profile.fromJson(p.toJson());
    expect(copia.endsOn, p.endsOn);
    expect(copia.startsOn, p.startsOn);
    expect(copia.role, p.role);
    expect(copia.statusOn(DateTime(2026, 11, 20)), AccountStatus.ok);
  });
}
