import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/google_auth_service.dart';
import 'auth_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  GoogleSignInAccount? get _user => GoogleAuthService.currentUser;

  Future<void> _revokeAndSignOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Revoke Access?'),
        content: const Text(
          'This will sign you out and revoke VaultX\'s access to your Google Drive. '
          'Your data remains in your Drive. You can re-connect anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await GoogleAuthService.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Future<void> _signOutOnly() async {
    await GoogleAuthService.signOutOnly();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (_) => false,
    );
  }

  Future<void> _reAuthenticate() async {
    await GoogleAuthService.signOutOnly();
    final account = await GoogleAuthService.signIn();
    if (!mounted) return;
    if (account != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Re-authenticated successfully')),
      );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Account card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor:
                      const Color(0xFF6C63FF).withOpacity(0.2),
                  backgroundImage: _user?.photoUrl != null
                      ? NetworkImage(_user!.photoUrl!)
                      : null,
                  child: _user?.photoUrl == null
                      ? const Icon(Icons.person_rounded,
                          color: Color(0xFF6C63FF), size: 28)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user?.displayName ?? 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _user?.email ?? '',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF03DAC6).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Connected to Google Drive',
                          style: TextStyle(
                              color: Color(0xFF03DAC6), fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),
          const Text('Google Drive Permissions',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 12),

          _SettingsTile(
            icon: Icons.cloud_done_rounded,
            iconColor: const Color(0xFF6C63FF),
            title: 'Drive App Folder Access',
            subtitle: 'VaultX reads/writes only its own folder in your Drive',
          ),
          _SettingsTile(
            icon: Icons.security_rounded,
            iconColor: const Color(0xFF03DAC6),
            title: 'Drive File Access',
            subtitle:
                'Needed to store document images alongside the vault data',
          ),

          const SizedBox(height: 28),
          const Text('Account Actions',
              style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 12),

          _ActionTile(
            icon: Icons.refresh_rounded,
            iconColor: const Color(0xFF6C63FF),
            title: 'Re-authenticate',
            subtitle: 'Sign in again with Google',
            onTap: _reAuthenticate,
          ),
          _ActionTile(
            icon: Icons.logout_rounded,
            iconColor: const Color(0xFFFFBE0B),
            title: 'Sign Out',
            subtitle: 'Stay connected but sign out of this session',
            onTap: _signOutOnly,
          ),
          _ActionTile(
            icon: Icons.link_off_rounded,
            iconColor: Colors.redAccent,
            title: 'Revoke Access',
            subtitle:
                'Remove VaultX\'s Google Drive permissions (data stays in Drive)',
            onTap: _revokeAndSignOut,
            danger: true,
          ),

          const SizedBox(height: 32),
          const Center(
            child: Text(
              'VaultX v1.1.0 • Data stored in your Google Drive',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: iconColor, size: 18),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;
  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: danger
              ? Colors.redAccent.withOpacity(0.06)
              : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(14),
          border: danger
              ? Border.all(
                  color: Colors.redAccent.withOpacity(0.3), width: 1)
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: danger ? Colors.redAccent : Colors.white)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style:
                          const TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey.shade600, size: 20),
          ],
        ),
      ),
    );
  }
}
EOF
echo "settings_screen done"