import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'folder_screen.dart';
import 'add_document_screen.dart';
import 'password_vault_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';
import '../services/storage_service.dart';
import '../services/drive_storage_service.dart';
import '../services/google_auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = const FlutterSecureStorage();

  final List<Map<String, dynamic>> folders = const [
    {'name': 'Aadhaar Card', 'icon': Icons.credit_card, 'color': Color(0xFF6C63FF)},
    {'name': 'PAN Card', 'icon': Icons.badge, 'color': Color(0xFF03DAC6)},
    {'name': 'Documents', 'icon': Icons.folder_rounded, 'color': Color(0xFFFF6584)},
    {'name': 'Passwords', 'icon': Icons.key_rounded, 'color': Color(0xFFFFBE0B)},
  ];

  Map<String, int> _counts = {
    'Aadhaar Card': 0,
    'PAN Card': 0,
    'Documents': 0,
    'Passwords': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    final categories = ['Aadhaar Card', 'PAN Card', 'Documents'];
    Map<String, int> newCounts = {};

    if (GoogleAuthService.isSignedIn) {
      for (final cat in categories) {
        final items = await DriveStorageService.getDocumentsByCategory(cat);
        newCounts[cat] = items.length;
      }
      final passwords = await DriveStorageService.getPasswords();
      newCounts['Passwords'] = passwords.length;
    } else {
      for (final cat in categories) {
        final items = await StorageService.getDocumentsByCategory(cat);
        newCounts[cat] = items.length;
      }
      final raw = await _storage.read(key: 'vault_passwords');
      if (raw != null) {
        final List decoded = jsonDecode(raw);
        newCounts['Passwords'] = decoded.length;
      } else {
        newCounts['Passwords'] = 0;
      }
    }

    if (mounted) setState(() => _counts = newCounts);
  }

  Future<void> _showCategoryPicker() async {
    final category = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add to which folder?',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ...['Aadhaar Card', 'PAN Card', 'Documents'].map(
              (cat) => ListTile(
                leading: const Icon(Icons.folder_rounded,
                    color: Color(0xFF6C63FF)),
                title: Text(cat),
                onTap: () => Navigator.pop(context, cat),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (category == null || !mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => AddDocumentScreen(category: category)),
    );
    _loadCounts();
  }

  @override
  Widget build(BuildContext context) {
    final user = GoogleAuthService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('VaultX',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 26),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
              _loadCounts();
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, size: 28),
            onPressed: _showCategoryPicker,
          ),
          // Settings / account button
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 12, left: 4),
              child: CircleAvatar(
                radius: 16,
                backgroundColor:
                    const Color(0xFF6C63FF).withOpacity(0.2),
                backgroundImage: user?.photoUrl != null
                    ? NetworkImage(user!.photoUrl!)
                    : null,
                child: user?.photoUrl == null
                    ? const Icon(Icons.person_rounded,
                        color: Color(0xFF6C63FF), size: 18)
                    : null,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drive sync indicator
            if (GoogleAuthService.isSignedIn)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF03DAC6).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFF03DAC6).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_done_rounded,
                        color: Color(0xFF03DAC6), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Synced to Google Drive • ${user?.email ?? ''}',
                      style: const TextStyle(
                          color: Color(0xFF03DAC6), fontSize: 12),
                    ),
                  ],
                ),
              ),
            const Text('Your Documents',
                style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: folders.length,
                itemBuilder: (context, index) {
                  final folder = folders[index];
                  final count = _counts[folder['name']] ?? 0;

                  return GestureDetector(
                    onTap: () async {
                      if (folder['name'] == 'Passwords') {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PasswordVaultScreen(),
                          ),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FolderScreen(
                              category: folder['name'] as String,
                              color: folder['color'] as Color,
                            ),
                          ),
                        );
                      }
                      _loadCounts();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (folder['color'] as Color)
                                .withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: (folder['color'] as Color)
                                  .withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(folder['icon'] as IconData,
                                color: folder['color'] as Color,
                                size: 32),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            folder['name'] as String,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          // Count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: (folder['color'] as Color)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$count ${count == 1 ? 'item' : 'items'}',
                              style: TextStyle(
                                color: folder['color'] as Color,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
EOF
echo "home_screen done"