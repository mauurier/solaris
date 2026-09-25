import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/theme/app_theme.dart';
import 'data/survey_store.dart';
import 'features/auth/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const SolarisApp());
}

class SolarisApp extends StatelessWidget {
  const SolarisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Solaris · Levantamientos',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      themeMode: ThemeMode.dark,
      home: const _Startup(),
      builder: (context, child) => MediaQuery.withNoTextScaling(child: child!),
    );
  }
}

/// Transición de página estándar del prototipo.
Route<R> appRoute<R>(Widget page, {bool fullscreenDialog = false}) {
  return PageRouteBuilder<R>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (_, _, _) => page,
    transitionsBuilder: (_, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: Offset(0, fullscreenDialog ? 0.06 : 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

Future<R?> push<R>(BuildContext context, Widget page, {bool fullscreenDialog = false}) {
  return Navigator.of(context).push<R>(appRoute<R>(page, fullscreenDialog: fullscreenDialog));
}

/// Abre la base local mientras muestra un indicador. Si falla, enseña el
/// error en pantalla en lugar de dejar la app en blanco.
class _Startup extends StatefulWidget {
  const _Startup();

  @override
  State<_Startup> createState() => _StartupState();
}

class _StartupState extends State<_Startup> {
  late Future<void> _init = _open();

  Future<void> _open() async {
    if (!SurveyStore.isReady) await SurveyStore.initDefault();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _init,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent),
                    const SizedBox(height: 12),
                    const Text('No se pudo abrir la base de datos local', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    SelectableText('${snap.error}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: () => setState(() => _init = _open()), child: const Text('Reintentar')),
                  ],
                ),
              ),
            ),
          );
        }
        return const LoginScreen();
      },
    );
  }
}
