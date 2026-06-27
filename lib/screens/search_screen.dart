import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/storage_service.dart';
import 'password_vault_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _storage = const FlutterSecureStorage();
  final _searchController = TextEditingController();

  List<Map<String, dynamic>> _allDocuments = [];
  List<Map<String, String>> _allPasswords = [];
  List<Map<String, dynamic>> _results = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    // Load documents from all categories
    final categories = ['Aadhaar Card', 'PAN Card', 'Documents'];
    List<Map<String, dynamic>> docs = [];

    for (final cat in categories) {
      final items = await StorageService.getDocumentsByCategory(cat);
      for (final item in items) {
        docs.add({...item, 'category': cat, 'type': 'document'});
      }
    }

    // Load passwords
    final raw = await _storage.read(key: 'vault_passwords');
    List<Map<String, String>> passwords = [];
    if (raw != null) {
      final List decoded = jsonDecode(raw);
      passwords = decoded.map((e) => Map<String, String>.from(e)).toList();
    }

    setState(() {
      _allDocuments = docs;
      _allPasswords = passwords;
      _loading = false;
    });
  }

  void _search(String query) {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }

    final q = query.toLowerCase();
    List<Map<String, dynamic>> results = [];

    // Search documents
    for (final doc in _allDocuments) {
      final name = (doc['name'] ?? '').toString().toLowerCase();
      final category = (doc['category'] ?? '').toString().toLowerCase();
      if (name.contains(q) || category.contains(q)) {
        results.add(doc);
      }
    }

    // Search passwords
    for (final pass in _allPasswords) {
      final name = (pass['name'] ?? '').toLowerCase();
      final username = (pass['username'] ?? '').toLowerCase();
      if (name.contains(q) || username.contains(q)) {
        results.add({
          'name': pass['name'],
          'username': pass['username'],
          'type': 'password',
        });
      }
    }

    setState(() => _results = results);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Search documents, passwords...',
            hintStyle: TextStyle(color: Colors.grey),
            border: InputBorder.none,
          ),
          onChanged: _search,
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _searchController.text.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Search your vault',
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : _results.isEmpty
                  ? const Center(
                      child: Text('No results found',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        final isPassword = item['type'] == 'password';

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E1E2E),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (isPassword
                                          ? const Color(0xFFFFBE0B)
                                          : const Color(0xFF6C63FF))
                                      .withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isPassword
                                      ? Icons.key_rounded
                                      : Icons.description_outlined,
                                  color: isPassword
                                      ? const Color(0xFFFFBE0B)
                                      : const Color(0xFF6C63FF),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isPassword
                                          ? (item['username'] ?? '')
                                          : (item['category'] ?? ''),
                                      style: const TextStyle(
                                          color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}
