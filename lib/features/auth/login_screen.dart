import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  UserRole _role = UserRole.tecnico;
  bool _obscure = true;
  bool _remember = true;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _enter() {
    AppState.instance.setRole(_role);
    Navigator.of(context).pushReplacement(appRoute(const HomeShell()));
  }

  Widget _fade(int index, Widget child) {
    final start = (index * 0.09).clamp(0.0, 0.8);
    final anim = CurvedAnimation(parent: _c, curve: Interval(start, (start + 0.5).clamp(0.0, 1.0), curve: Curves.easeOutCubic));
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.10), end: Offset.zero).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(26, 0, 26, 26),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 44),
                    _fade(0, const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 60))),
                    const SizedBox(height: 26),
                    _fade(1, const BrandWordmark()),
                    const SizedBox(height: 22),
                    _fade(
                      2,
                      const Text(
                        'Tu asistente digital de levantamientos:\nte recuerda qué capturar, lo organiza y lo convierte en documentación técnica.',
                        style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 34),
                    _fade(
                      3,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FieldLabel('Correo corporativo'),
                          TextField(
                            keyboardType: TextInputType.emailAddress,
                            style: T.body,
                            decoration: const InputDecoration(
                              hintText: 'nombre@solaris.mx',
                              prefixIcon: Icon(Icons.alternate_email_rounded, size: 19),
                            ),
                            controller: TextEditingController(text: 'j.perez@solaris.mx'),
                          ),
                          const SizedBox(height: 18),
                          const FieldLabel('Contraseña'),
                          TextField(
                            obscureText: _obscure,
                            style: T.body,
                            controller: TextEditingController(text: '••••••••••'),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  size: 19,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _fade(
                      4,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const FieldLabel('Entrar como', hint: 'Demo de roles'),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: UserRole.values.map((r) {
                              final sel = r == _role;
                              return GestureDetector(
                                onTap: () => setState(() => _role = r),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                                  decoration: BoxDecoration(
                                    color: sel ? r.color.withValues(alpha: 0.14) : AppColors.surfaceAlt,
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: sel ? r.color.withValues(alpha: 0.5) : AppColors.border,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(r.icon, size: 14, color: sel ? r.color : AppColors.textMuted),
                                      const SizedBox(width: 7),
                                      Text(
                                        r.short,
                                        style: TextStyle(
                                          fontSize: 12.8,
                                          fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                                          color: sel ? r.color : AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _fade(
                      5,
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _remember,
                              onChanged: (v) => setState(() => _remember = v ?? false),
                              activeColor: AppColors.accent,
                              checkColor: const Color(0xFF1B1200),
                              side: const BorderSide(color: AppColors.border, width: 1.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Mantener sesión para trabajo en campo', style: T.small),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 26),
                    _fade(6, AppButton('Iniciar sesión', icon: Icons.arrow_forward_rounded, expand: true, onPressed: _enter)),
                    const SizedBox(height: 14),
                    _fade(
                      7,
                      Center(
                        child: TextButton(
                          onPressed: () => showAppSnack(context, 'Prototipo: recuperación no implementada'),
                          child: const Text('¿Olvidaste tu contraseña?',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    _fade(
                      8,
                      GlassCard(
                        color: AppColors.surface.withValues(alpha: 0.6),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            const IconBadge(Icons.wifi_off_rounded, color: AppColors.teal, size: 34),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Modo offline disponible. Los levantamientos descargados funcionan sin conexión.',
                                style: T.tiny,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Center(
                      child: Text('Versión 1.0.0 · Prototipo UI', style: T.tiny),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
