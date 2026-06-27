import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/storage_selection_screen.dart';

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
  String? _storageMode;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final storageMode = await _storage.read(key: 'storage_mode');

    setState(() {
      _storageMode = storageMode;
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

    if (_storageMode == null) {
      return const StorageSelectionScreen();
    }

    if (_storageMode == 'local') {
      return const HomeScreen();
    }

    return const AuthScreen();
  }
}
