import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_app/data/auth/profile.dart';
import 'package:proyecto_app/data/auth/user_directory.dart';
import 'package:proyecto_app/data/models.dart';

import 'test_helpers.dart';

AppUser _user({String rol = 'tecnico', bool activo = true, String inicio = '2020-01-01', String? fin = '2099-12-31'}) =>
    AppUser.fromProfile(Profile.fromJson({
      'id': 'u-$rol',
      'email': '$rol@solaris.mx',
      'nombre': 'Ana Torres',
      'rol': rol,
      'activo': activo,
      'inicio_vigencia': inicio,
      'fin_vigencia': fin,
      'eliminado_en': null,
    }));

void main() {
  test('el usuario sale del perfil', () {
    final u = _user(rol: 'supervisor');
    expect(u.role, UserRole.supervisor);
    expect(u.initials, 'AT');
    expect(u.email, 'supervisor@solaris.mx');
    expect(_user(rol: 'superadmin', fin: null).isSuperadmin, isTrue);
  });

  test('se puede asignar si está activo y sin vencer, aunque empiece después', () {
    expect(_user().assignable, isTrue);
    expect(_user(inicio: '2099-01-01').assignable, isTrue);
    expect(_user(activo: false).assignable, isFalse);
    expect(_user(inicio: '2020-01-01', fin: '2020-12-31').assignable, isFalse);
  });

  test('sólo se asigna a cuentas activas; un id desconocido no truena', () {
    signInAs(UserRole.supervisor);
    final dir = UserDirectory.instance;
    expect(dir.users, hasLength(testProfiles.length));
    expect(dir.assignable(UserRole.tecnico).map((u) => u.name), isNot(contains('Sofía Herrera')));
    expect(dir.assignable(UserRole.supervisor), isNotEmpty);
    expect(dir.nameOf('borrado'), 'Usuario desconocido');
  });
}
