import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' show ClientException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../mock_data.dart';
import '../models.dart';
import 'auth_service.dart';
import 'profile.dart';

/// Usuarios de la tabla `perfil`: la pantalla Usuarios y las listas para
/// elegir supervisor y técnicos. La lista se guarda en el teléfono para poder
/// asignar sin conexión. En el modo demo (sin cuenta) usa los de ejemplo.
class UserDirectory extends ChangeNotifier {
  UserDirectory._();
  static final instance = UserDirectory._();

  static const _cacheKey = 'usuarios.lista';
  static const _timeout = Duration(seconds: 15);
  static const _columns = 'id, email, nombre, rol, activo, inicio_vigencia, fin_vigencia, eliminado_en';
  static const _offline = 'Sin conexión. Inténtalo cuando tengas internet.';

  /// Roles que el superadmin puede asignar (el superadmin no se crea desde la app).
  static const assignableRoles = ['admin', 'supervisor', 'tecnico'];

  List<Profile> _profiles = const [];
  bool loading = false;

  /// Error de la última actualización; la lista guardada sigue disponible.
  String? error;

  bool get _demo => AppState.instance.profile == null;
  SupabaseClient get _client => Supabase.instance.client;

  List<AppUser> get users => _demo ? Mock.users : [for (final p in _profiles) AppUser.fromProfile(p)];

  /// Supervisores o técnicos a los que hoy se les puede asignar trabajo.
  List<AppUser> assignable(UserRole role) => users.where((u) => u.role == role && u.assignable).toList();

  /// Lee la lista guardada y la actualiza en segundo plano.
  Future<void> start() async {
    final cached = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if (cached != null) {
      _profiles = [
        for (final j in jsonDecode(cached) as List) Profile.fromJson(j as Map<String, dynamic>),
      ];
      notifyListeners();
    }
    unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_demo) return;
    loading = true;
    notifyListeners();
    try {
      final rows = await _client
          .from('perfil')
          .select(_columns)
          .isFilter('eliminado_en', null)
          .order('nombre')
          .timeout(_timeout);
      _profiles = [for (final r in rows) Profile.fromJson(r)];
      error = null;
      await _save();
    } catch (e) {
      error = _message(e);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Crea la cuenta con la Edge Function `crear-usuario` (solo superadmin).
  Future<AppUser> create({
    required String email,
    required String password,
    required String name,
    required String role,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    try {
      final res = await _client.functions.invoke(
        'crear-usuario',
        headers: await _authHeader(),
        body: {
          'email': email.trim().toLowerCase(),
          'password': password,
          'nombre': name.trim(),
          'rol': role,
          'inicio_vigencia': _date(startsOn),
          'fin_vigencia': _date(endsOn),
        },
      ).timeout(_timeout);
      final profile = Profile.fromJson((res.data as Map<String, dynamic>)['perfil'] as Map<String, dynamic>);
      _profiles = [..._profiles, profile]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      await _save();
      notifyListeners();
      return AppUser.fromProfile(profile);
    } catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  /// Cambia rol, estado o vigencia de una cuenta (solo superadmin, lo
  /// revisa la política `perfil_update`).
  Future<void> update(
    AppUser user, {
    required String role,
    required bool active,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final id = user.profile?.id;
    if (id == null) return;
    try {
      final row = await _client
          .from('perfil')
          .update({
            'rol': role,
            'activo': active,
            'inicio_vigencia': _date(startsOn),
            'fin_vigencia': _date(endsOn),
          })
          .eq('id', id)
          .select(_columns)
          .maybeSingle()
          .timeout(_timeout);
      if (row == null) throw const AuthFailure('Solo el superadmin puede modificar cuentas.');
      final updated = Profile.fromJson(row);
      _profiles = [for (final p in _profiles) p.id == id ? updated : p];
      await _save();
      notifyListeners();
    } catch (e) {
      throw AuthFailure(_message(e));
    }
  }

  /// Al cerrar sesión: la lista es de la cuenta anterior.
  Future<void> clear() async {
    _profiles = const [];
    error = null;
    await (await SharedPreferences.getInstance()).remove(_cacheKey);
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_cacheKey, jsonEncode([for (final p in _profiles) p.toJson()]));
  }

  /// La sesión puede haber vencido si el teléfono estuvo sin conexión.
  Future<Map<String, String>> _authHeader() async {
    var session = _client.auth.currentSession;
    if (session == null) throw const AuthFailure('Tu sesión terminó. Vuelve a iniciar sesión.');
    if (session.isExpired) session = (await _client.auth.refreshSession()).session ?? session;
    return {'Authorization': 'Bearer ${session.accessToken}'};
  }

  static String _message(Object e) => switch (e) {
        AuthFailure(:final message) => message,
        FunctionException(:final details, :final status) => _functionMessage(details, status),
        PostgrestException(:final message) => message,
        AuthRetryableFetchException() || SocketException() || ClientException() || TimeoutException() => _offline,
        AuthException(:final message) => message,
        _ => '$e',
      };

  /// La función responde `{error, detalles?}`.
  static String _functionMessage(dynamic details, int status) {
    if (details is Map && details['error'] is String) {
      final extra = details['detalles'];
      return extra is List && extra.isNotEmpty ? '${details['error']}: ${extra.join(', ')}.' : '${details['error']}.';
    }
    return 'Error del servidor ($status).';
  }

  static String _date(DateTime d) => d.toIso8601String().substring(0, 10);
}
