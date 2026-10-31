import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' show ClientException;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/auth_service.dart';

/// Mensaje para el usuario a partir de un error de Supabase o de la red.
String remoteErrorMessage(Object e, {String offline = 'Sin conexión. Inténtalo cuando tengas internet.'}) =>
    switch (e) {
      AuthFailure(:final message) => message,
      FunctionsFetchException() => offline,
      FunctionException(:final details, :final status) => _functionMessage(details, status),
      PostgrestException(:final message) => message,
      AuthRetryableFetchException() || SocketException() || ClientException() || TimeoutException() => offline,
      AuthException(:final message) => message,
      _ => '$e',
    };

/// Las Edge Functions responden `{error, detalles?}`.
String _functionMessage(dynamic details, int status) {
  if (details is Map && details['error'] is String) {
    final extra = details['detalles'];
    return extra is List && extra.isNotEmpty ? '${details['error']}: ${extra.join(', ')}.' : '${details['error']}.';
  }
  return 'Error del servidor ($status).';
}
