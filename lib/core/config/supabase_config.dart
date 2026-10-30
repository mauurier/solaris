/// Proyecto Solaris en Supabase.
///
/// La llave publishable puede ir en la app: lo que cada usuario ve lo limitan
/// las políticas RLS de la base. La llave secreta nunca va aquí; solo la usa
/// la Edge Function `crear-usuario`.
///
/// Se pueden cambiar sin tocar el código, p. ej. para otro proyecto de pruebas:
/// `flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...`
class SupabaseConfig {
  SupabaseConfig._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://gphsalcyqoxeactjbtzq.supabase.co',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_mrfMkRpn2Wrv1tV3-pQGnQ_tfQ9DoEY',
  );
}
