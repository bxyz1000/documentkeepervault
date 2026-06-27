import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PasswordVaultScreen extends StatefulWidget {
  const PasswordVaultScreen({super.key});

  @override
  State<PasswordVaultScreen> createState() => _PasswordVaultScreenState();
}

class _PasswordVaultScreenState extends State<PasswordVaultScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, String>> _passwords = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPasswords();
  }

  Future<void> _loadPasswords() async {
    final raw = await _storage.read(key: 'vault_passwords');
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      setState(() {
        _passwords = decoded.map((e) => Map<String, String>.from(e)).toList();
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _savePasswords() async {
    await _storage.write(
      key: 'vault_passwords',
      value: jsonEncode(_passwords),
    );
  }

  void _openAddDialog({int? editIndex}) {
    final nameController = TextEditingController(
      text: editIndex != null ? _passwords[editIndex]['name'] : '',
    );
    final usernameController = TextEditingController(
      text: editIndex != null ? _passwords[editIndex]['username'] : '',
    );
    final passwordController = TextEditingController(
      text: editIndex != null ? _passwords[editIndex]['password'] : '',
    );
    bool obscure = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  editIndex != null ? 'Edit Password' : 'Add Password',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                _buildField(nameController, 'App / Website Name', Icons.apps),
                const SizedBox(height: 14),
                _buildField(
                    usernameController, 'Username / Email', Icons.person),
                const SizedBox(height: 14),
                TextField(
                  controller: passwordController,
                  obscureText: obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    labelStyle: const TextStyle(color: Colors.grey),
                    prefixIcon:
                        const Icon(Icons.lock, color: Color(0xFFFFBE0B)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscure ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () => setModalState(() => obscure = !obscure),
                    ),
                    filled: true,
                    fillColor: const Color(0xFF12121F),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (nameController.text.trim().isEmpty ||
                          passwordController.text.trim().isEmpty) {
                        return;
                      }
                      final entry = {
                        'name': nameController.text.trim(),
                        'username': usernameController.text.trim(),
                        'password': passwordController.text.trim(),
                      };
                      setState(() {
                        if (editIndex != null) {
                          _passwords[editIndex] = entry;
                        } else {
                          _passwords.add(entry);
                        }
                      });
                      await _savePasswords();
                      if (mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFBE0B),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      editIndex != null ? 'Save Changes' : 'Add Password',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _deletePassword(int index) async {
    setState(() => _passwords.removeAt(index));
    await _savePasswords();
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        backgroundColor: const Color(0xFF1E1E2E),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Password Vault',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFFBE0B),
        foregroundColor: Colors.black,
        onPressed: () => _openAddDialog(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _passwords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.key_rounded,
                          size: 64, color: Colors.grey.shade700),
                      const SizedBox(height: 16),
                      const Text('No passwords saved',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Tap + to add your first password',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _passwords.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final entry = _passwords[index];
                    return _PasswordCard(
                      entry: entry,
                      onEdit: () => _openAddDialog(editIndex: index),
                      onDelete: () => _deletePassword(index),
                      onCopyUsername: () =>
                          _copyToClipboard(entry['username'] ?? '', 'Username'),
                      onCopyPassword: () =>
                          _copyToClipboard(entry['password'] ?? '', 'Password'),
                    );
                  },
                ),
    );
  }

  Widget _buildField(
      TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: const Color(0xFFFFBE0B)),
        filled: true,
        fillColor: const Color(0xFF12121F),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PasswordCard extends StatefulWidget {
  final Map<String, String> entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onCopyUsername;
  final VoidCallback onCopyPassword;

  const _PasswordCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
    required this.onCopyUsername,
    required this.onCopyPassword,
  });

  @override
  State<_PasswordCard> createState() => _PasswordCardState();
}

class _PasswordCardState extends State<_PasswordCard> {
  bool _showPassword = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFBE0B).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFBE0B).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.key_rounded,
                    color: Color(0xFFFFBE0B), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.entry['name'] ?? '',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.grey, size: 20),
                onPressed: widget.onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent, size: 20),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1E1E2E),
                      title: const Text('Delete Password?'),
                      content:
                          Text('Remove "${widget.entry['name']}" from vault?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onDelete();
                          },
                          child: const Text('Delete',
                              style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          if ((widget.entry['username'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.entry['username'] ?? '',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ),
                GestureDetector(
                  onTap: widget.onCopyUsername,
                  child: const Icon(Icons.copy, size: 16, color: Colors.grey),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 16, color: Colors.grey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _showPassword
                      ? (widget.entry['password'] ?? '')
                      : '••••••••••',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _showPassword = !_showPassword),
                child: Icon(
                  _showPassword ? Icons.visibility_off : Icons.visibility,
                  size: 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: widget.onCopyPassword,
                child: const Icon(Icons.copy, size: 16, color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
