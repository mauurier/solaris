import 'package:flutter/material.dart';

/// Tokens de color del sistema de diseño (dark-first).
class AppColors {
  AppColors._();

  // Fondos
  static const bg = Color(0xFF080A0E);
  static const bgElevated = Color(0xFF0E1117);
  static const surface = Color(0xFF12161E);
  static const surfaceAlt = Color(0xFF171C26);
  static const surfaceHigh = Color(0xFF1E2430);

  // Bordes y separadores
  static const border = Color(0xFF232A36);
  static const borderSoft = Color(0xFF1A202B);

  // Texto
  static const textPrimary = Color(0xFFECEFF4);
  static const textSecondary = Color(0xFF98A2B3);
  static const textMuted = Color(0xFF667085);

  // Acentos
  static const accent = Color(0xFFFFB84D); // solar
  static const accentDeep = Color(0xFFF59E0B);
  static const accentSoft = Color(0x33FFB84D);
  static const blue = Color(0xFF5B9DF9);
  static const violet = Color(0xFF9B8CFF);
  static const teal = Color(0xFF2DD4BF);

  // Semánticos
  static const success = Color(0xFF3DD68C);
  static const warning = Color(0xFFFFC24B);
  static const danger = Color(0xFFF87171);
  static const critical = Color(0xFFE0405C);
  static const info = Color(0xFF5B9DF9);

  // Severidades de hallazgos
  static const sevBaja = Color(0xFF64748B);
  static const sevMedia = Color(0xFFFFC24B);
  static const sevAlta = Color(0xFFFB923C);
  static const sevCritica = Color(0xFFE0405C);

  static const glassStroke = Color(0x14FFFFFF);

  static const solarGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFC978), Color(0xFFF59E0B)],
  );

  static const nightGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF141A24), Color(0xFF0D1117)],
  );
}
