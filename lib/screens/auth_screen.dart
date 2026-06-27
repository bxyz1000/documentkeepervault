import 'package:flutter/material.dart';
import '../services/google_auth_service.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _handleSignIn() async {
  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final account = await GoogleAuthService.signIn();

    if (!mounted) return;

    if (account != null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _loading = false;
        _error = "Google Sign-In returned null.";
      });
    }
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _loading = false;
      _error = "ERROR: $e";
    });
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // Logo / icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF6C63FF).withOpacity(0.15),
                  border: Border.all(
                      color: const Color(0xFF6C63FF), width: 2),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  size: 52,
                  color: Color(0xFF6C63FF),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'VaultX',
                style: TextStyle(
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your secure document vault.\nAll data stored privately in your Google Drive.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 15,
                  height: 1.6,
                ),
              ),
              const Spacer(flex: 2),
              // Feature bullets
              ...[
                (Icons.cloud_done_rounded,
                    'Data syncs across all your devices'),
                (Icons.lock_rounded, 'Encrypted with your Google account'),
                (Icons.folder_rounded,
                    'Stored in your private Google Drive'),
                (Icons.block_rounded, 'No Anthropic/third-party servers'),
              ].map((item) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(item.$1,
                            color: const Color(0xFF6C63FF), size: 20),
                        const SizedBox(width: 14),
                        Text(
                          item.$2,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  )),
              const Spacer(flex: 2),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                        color: Colors.redAccent, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _handleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.black54),
                        )
                      : const Icon(Icons.login_rounded, size: 22),
                  label: Text(
                    _loading ? 'Signing in...' : 'Continue with Google',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'By continuing you agree to use VaultX. Your data never leaves your Google Drive.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
