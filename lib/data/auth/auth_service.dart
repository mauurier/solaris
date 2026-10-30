import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_config.dart';
import 'profile.dart';

/// Error que se le puede mostrar tal cual al usuario.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Inicio de sesión con Supabase Auth.
///
/// Supabase guarda la sesión en el teléfono y la renueva sola. El perfil
/// también se guarda para poder abrir la app sin conexión en campo; la
/// vigencia se vuelve a revisar contra el servidor cada vez que hay internet.
class AuthService {
  AuthService._();
  static final instance = AuthService._();

  static const _profileKey = 'auth.perfil';
  static const _rememberKey = 'auth.recordar';
  static const _timeout = Duration(seconds: 10);
  static const _offline = 'Sin conexión. Para iniciar sesión por primera vez necesitas internet.';

  static bool _initialized = false;

  SupabaseClient get _client => Supabase.instance.client;

  static Future<void> init() async {
    if (_initialized) return;
    await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.publishableKey);
    _initialized = true;
  }

  Future<Profile> signIn(String email, String password, {required bool remember}) async {
    try {
      await _client.auth
          .signInWithPassword(email: email.trim().toLowerCase(), password: password)
          .timeout(_timeout);
    } on AuthRetryableFetchException {
      throw const AuthFailure(_offline);
    } on AuthApiException catch (e) {
      throw AuthFailure(e.code == 'invalid_credentials' ? 'Correo o contraseña incorrectos.' : e.message);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } on SocketException {
      throw const AuthFailure(_offline);
    } on TimeoutException {
      throw const AuthFailure(_offline);
    }

    final Profile? profile;
    try {
      profile = await _fetchProfile();
    } catch (e) {
      await signOut();
      throw AuthFailure('No se pudo leer tu perfil. Intenta de nuevo. ($e)');
    }
    if (profile == null) {
      await signOut();
      throw const AuthFailure('Tu cuenta no tiene perfil. Pide al superadmin que la revise.');
    }
    final blocked = profile.blockedMessage(DateTime.now());
    if (blocked != null) {
      await signOut();
      throw AuthFailure(blocked);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    await prefs.setBool(_rememberKey, remember);
    return profile;
  }

  /// Sesión de la vez anterior. Nulo si hay que iniciar sesión; lanza
  /// [AuthFailure] si la cuenta ya no puede entrar (p. ej. venció).
  Future<Profile?> restore() async {
    final session = _client.auth.currentSession;
    if (session == null) return null;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_rememberKey) == false) {
      await signOut();
      return null;
    }

    Profile? profile;
    try {
      profile = await _fetchProfile();
      if (profile != null) await prefs.setString(_profileKey, jsonEncode(profile.toJson()));
    } catch (_) {
      // Sin conexión: se usa el perfil guardado la última vez.
      final cached = prefs.getString(_profileKey);
      if (cached != null) profile = Profile.fromJson(jsonDecode(cached) as Map<String, dynamic>);
    }

    if (profile == null || profile.id != session.user.id) {
      await signOut();
      return null;
    }
    final blocked = profile.blockedMessage(DateTime.now());
    if (blocked != null) {
      await signOut();
      throw AuthFailure(blocked);
    }
    return profile;
  }

  /// Cierra la sesión solo en este teléfono. Funciona sin conexión.
  Future<void> signOut() async {
    if (_initialized) {
      try {
        await _client.auth.signOut().timeout(_timeout);
      } catch (_) {
        // La sesión local ya se borró; avisar al servidor es opcional.
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileKey);
    await prefs.remove(_rememberKey);
  }

  Future<Profile?> _fetchProfile() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _client
        .from('perfil')
        .select('id, email, nombre, rol, activo, inicio_vigencia, fin_vigencia, eliminado_en')
        .eq('id', uid)
        .maybeSingle()
        .timeout(_timeout);
    return row == null ? null : Profile.fromJson(row);
  }
}
