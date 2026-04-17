/// FBLA Connect — Supabase & backend configuration.
///
/// Replace the placeholder values below with your actual project credentials.
/// NEVER commit real secrets to source control; prefer --dart-define at build time:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=eyJ...
///
/// Then read them via:
///   const String.fromEnvironment('SUPABASE_URL', defaultValue: _kSupabaseUrl)
library;

/// Public Supabase project URL (safe to expose in client).
const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: 'https://jbvrhkbeeozbtozcvsof.supabase.co',
);

/// Supabase anon key (public, row-level-security enforced).
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpidnJoa2JlZW96YnRvemN2c29mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzAwODE3NTgsImV4cCI6MjA4NTY1Nzc1OH0.9UKjQVpngBJ5uYzc-wZx5pp-rmr_P8QGd3XDoMwP5Dk',
);

/// Base URL for the Flask REST API (proxies additional business logic).
/// TODO: Replace with your deployed backend URL before submitting.
/// Example: 'https://fbla-connect-api.onrender.com/api'
const String kBackendBaseUrl = String.fromEnvironment(
  'BACKEND_URL',
  defaultValue: 'https://fblaconnect.onrender.com/api',
);
