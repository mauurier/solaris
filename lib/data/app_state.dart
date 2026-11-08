import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth/profile.dart';
import 'models.dart';

/// Estado global de la app: la sesión, el rol y los ajustes del teléfono.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  UserRole role = UserRole.tecnico;

  /// Id de `perfil` del usuario con sesión.
  String userId = '';
  String userName = '';
  String userInitials = '';

  /// Perfil de Supabase; nulo sin sesión.
  Profile? profile;
  /// "Pausar sincronización": no se sube ni se baja nada.
  bool offlineMode = false;

  /// Fotos, videos y documentos sólo se suben y bajan con Wi-Fi.
  bool syncOnWifiOnly = true;
  static const _wifiOnlyKey = 'ajustes.solo_wifi';

  /// Sincroniza sola al volver la conexión, tras cada cambio y cada rato.
  bool autoSync = true;
  static const _autoSyncKey = 'ajustes.sync_auto';

  /// La cámara pide un comentario después de cada foto.
  bool commentPerPhoto = false;
  static const _commentKey = 'ajustes.comentario_por_foto';

  void signIn(Profile p) {
    profile = p;
    role = p.uiRole;
    userId = p.id;
    userName = p.name;
    userInitials = p.initials;
    notifyListeners();
  }

  /// Al cerrar sesión.
  void signOut() {
    profile = null;
    role = UserRole.tecnico;
    userId = '';
    userName = '';
    userInitials = '';
    notifyListeners();
  }

  /// Lee los ajustes guardados en el teléfono.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    syncOnWifiOnly = prefs.getBool(_wifiOnlyKey) ?? true;
    autoSync = prefs.getBool(_autoSyncKey) ?? true;
    commentPerPhoto = prefs.getBool(_commentKey) ?? false;
  }

  Future<void> setCommentPerPhoto(bool v) async {
    commentPerPhoto = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_commentKey, v);
  }

  Future<void> setAutoSync(bool v) async {
    autoSync = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_autoSyncKey, v);
  }

  Future<void> setSyncOnWifiOnly(bool v) async {
    syncOnWifiOnly = v;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_wifiOnlyKey, v);
  }

  void toggleOffline() {
    offlineMode = !offlineMode;
    notifyListeners();
  }

  void update() => notifyListeners();
}
