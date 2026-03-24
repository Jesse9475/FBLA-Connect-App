import 'package:flutter/material.dart';

import 'services/api_service.dart';
import 'services/auth_service.dart';

/// Entry point for the FBLA Connect mobile app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ApiService.instance.init();
  runApp(const FblaConnectApp());
}

/// Root widget that decides whether to show auth or home based on token.
class FblaConnectApp extends StatelessWidget {
  const FblaConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FBLA Connect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

/// Simple gate that will eventually check for an existing token.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _authenticated = false;

  @override
  void initState() {
    super.initState();
    _checkExistingSession();
  }

  /// For now this only simulates a check; later you can call /health or /users.
  Future<void> _checkExistingSession() async {
    // TODO: read a flag or make a lightweight backend call if desired.
    setState(() {
      _checking = false;
      _authenticated = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_authenticated) {
      return const HomeScreen();
    } else {
      return const LoginScreen();
    }
  }
}

/// Very small placeholder for the main home area.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FBLA Connect Home'),
      ),
      body: const Center(
        child: Text('Home content goes here.'),
      ),
    );
  }
}

/// Simple login screen that will eventually call AuthService.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _tokenController = TextEditingController();
  bool _loading = false;
  String? _error;

  /// Call the backend /auth/session route using the entered token.
  Future<void> _handleLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final String token = _tokenController.text.trim();
    final AuthService authService = AuthService();

    try {
      await authService.createSession(token);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => const HomeScreen(),
        ),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FBLA Connect Login'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enter Supabase access token to create a session.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(
                labelText: 'Access token',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loading ? null : _handleLogin,
              child: _loading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Log in'),
            ),
          ],
        ),
      ),
    );
  }
}

