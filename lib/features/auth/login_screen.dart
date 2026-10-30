import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/brand.dart';
import '../../core/widgets/ui.dart';
import '../../data/auth/auth_service.dart';
import '../../data/mock_data.dart';
import '../../data/models.dart';
import '../shell/home_shell.dart';
import '../../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.message});

  /// Aviso al abrir, p. ej. cuando la sesión guardada ya venció.
  final String? message;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  UserRole _demoRole = UserRole.tecnico;
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
  late String? _error = widget.message;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _enter() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Escribe tu correo y tu contraseña.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await AuthService.instance.signIn(email, password, remember: _remember);
      AppState.instance.signIn(profile);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(appRoute(const HomeShell()));
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _enterDemo() {
    AppState.instance.setRole(_demoRole);
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
                      AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const FieldLabel('Correo corporativo'),
                            TextField(
                              controller: _email,
                              enabled: !_loading,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              style: T.body,
                              decoration: const InputDecoration(
                                hintText: 'nombre@solaris.mx',
                                prefixIcon: Icon(Icons.alternate_email_rounded, size: 19),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const FieldLabel('Contraseña'),
                            TextField(
                              controller: _password,
                              enabled: !_loading,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _enter(),
                              style: T.body,
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
                    ),
                    const SizedBox(height: 20),
                    _fade(
                      4,
                      Row(
                        children: [
                          SizedBox(
                            height: 24,
                            width: 24,
                            child: Checkbox(
                              value: _remember,
                              onChanged: _loading ? null : (v) => setState(() => _remember = v ?? false),
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
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
                            const SizedBox(width: 10),
                            Expanded(child: Text(_error!, style: T.small)),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 26),
                    _fade(
                      5,
                      _loading
                          ? const Center(
                              child: SizedBox(height: 48, child: Center(child: CircularProgressIndicator())),
                            )
                          : AppButton('Iniciar sesión', icon: Icons.arrow_forward_rounded, expand: true, onPressed: _enter),
                    ),
                    const SizedBox(height: 14),
                    _fade(
                      6,
                      Center(
                        child: TextButton(
                          onPressed: () => showAppSnack(context, 'Pide al superadmin que te asigne una contraseña nueva'),
                          child: const Text('¿Olvidaste tu contraseña?',
                              style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                        ),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 18),
                      _fade(7, _demo()),
                    ],
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
                      child: Text('Versión 1.0.0', style: T.tiny),
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

  /// Solo en desarrollo: entrar con un rol de ejemplo, sin cuenta, para
  /// revisar pantallas. No existe en la app compilada para producción.
  Widget _demo() {
    return GlassCard(
      color: AppColors.surface.withValues(alpha: 0.6),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FieldLabel('Modo demo', hint: 'Solo en desarrollo'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserRole.values.map((r) {
              final sel = r == _demoRole;
              return GestureDetector(
                onTap: () => setState(() => _demoRole = r),
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
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _loading ? null : _enterDemo,
              icon: const Icon(Icons.science_outlined, size: 16),
              label: Text('Entrar como ${_demoRole.short} de ejemplo'),
            ),
          ),
        ],
      ),
    );
  }
}
