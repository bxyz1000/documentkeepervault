import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/pin_screen.dart';
import 'screens/home_screen.dart';
import 'screens/biometric_screen.dart';
import 'screens/auth_screen.dart';
import 'services/google_auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VaultXApp());
}

class VaultXApp extends StatelessWidget {
  const VaultXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VaultX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF6C63FF),
          secondary: const Color(0xFF03DAC6),
          surface: const Color(0xFF1E1E2E),
        ),
        scaffoldBackgroundColor: const Color(0xFF12121F),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _storage = const FlutterSecureStorage();
  bool _loading = true;
  bool _hasPin = false;
  bool _googleSignedIn = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // 1. Try silent Google sign-in restore
    final account = await GoogleAuthService.signInSilently();
    final googleIn = account != null;

    // 2. Check PIN
    final pin = await _storage.read(key: 'vault_pin');
    final hasPin = pin != null;

    setState(() {
      _googleSignedIn = googleIn;
      _hasPin = hasPin;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Not signed in with Google → show onboarding
    if (!_googleSignedIn) {
      return const AuthScreen();
    }

    // Google signed in → check PIN
    if (!_hasPin) {
      return const PinScreen(isSetup: true);
    }

    // Everything ready → biometric/PIN gate
    return const BiometricScreen();
  }
}
EOF
echo "main.dart done"