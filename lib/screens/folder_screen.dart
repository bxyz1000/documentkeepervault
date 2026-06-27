import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/storage_service.dart';
import '../services/drive_storage_service.dart';
import '../services/google_auth_service.dart';
import 'add_document_screen.dart';
import 'card_viewer_screen.dart';
import 'document_mode_screen.dart';

class FolderScreen extends StatefulWidget {
  final String category;
  final Color color;
  const FolderScreen({
    super.key,
    required this.category,
    required this.color,
  });

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  final _storage = const FlutterSecureStorage();
  List<Map<String, dynamic>> _documents = [];
  bool _selectMode = false;
  Set<int> _selectedIds = {};
  bool _loading = false;
  String? _storageMode;

  bool get _useDrive =>
      _storageMode == 'drive' && GoogleAuthService.isSignedIn;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _loading = true);
    List<Map<String, dynamic>> docs;
    final storageMode = await _storage.read(key: 'storage_mode');
    final useDrive = storageMode == 'drive' && GoogleAuthService.isSignedIn;
    if (useDrive) {
      docs = await DriveStorageService.getDocumentsByCategory(
          widget.category);
      // Pre-cache images locally
      for (final doc in docs) {
        final fid = doc['front_drive_id'] as String?;
        if (fid != null && doc['front_path'] == null) {
          final localPath =
              await DriveStorageService.downloadImage(fid, 'front_${doc['id']}.jpg');
          doc['front_path'] = localPath;
        }
      }
    } else {
      docs = await StorageService.getDocumentsByCategory(widget.category);
    }
    setState(() {
      _documents = docs;
      _storageMode = storageMode;
      _loading = false;
    });
  }

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      _selectedIds.clear();
    });
  }

  void _toggleSelect(int id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E2E),
        title: const Text('Delete Documents?'),
        content: Text(
            'Delete ${_selectedIds.length} selected document${_selectedIds.length > 1 ? 's' : ''}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;

    for (final id in _selectedIds) {
      if (_useDrive) {
        await DriveStorageService.deleteDocument(id);
      } else {
        await StorageService.deleteDocument(id);
      }
    }

    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
    _loadDocuments();
  }

  void _openDocument(Map<String, dynamic> doc) {
    final mode = doc['content_mode'] as String? ?? 'card';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => mode == 'document'
            ? DocumentModeScreen(document: doc)
            : CardViewerScreen(document: doc),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(
            _selectMode ? '${_selectedIds.length} selected' : widget.category),
        actions: [
          if (_selectMode) ...[
            if (_selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                onPressed: _deleteSelected,
              ),
            TextButton(
              onPressed: _toggleSelectMode,
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
          ] else
            IconButton(
              icon: const Icon(Icons.checklist_rounded),
              onPressed: _toggleSelectMode,
            ),
        ],
      ),
      floatingActionButton: _selectMode
          ? null
          : FloatingActionButton(
              backgroundColor: widget.color,
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddDocumentScreen(category: widget.category),
                  ),
                );
                if (result == true) _loadDocuments();
              },
              child: const Icon(Icons.add),
            ),
      body: _loading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF6C63FF)),
                  SizedBox(height: 16),
                  Text('Loading from Drive...',
                      style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : _documents.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open_rounded,
                          size: 64, color: Colors.grey.shade700),
                      const SizedBox(height: 16),
                      const Text('No documents yet',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      const Text('Tap + to add your first document',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _documents.length,
                  itemBuilder: (context, index) {
                    final doc = _documents[index];
                    final id = doc['id'] as int;
                    final isSelected = _selectedIds.contains(id);
                    final mode =
                        doc['content_mode'] as String? ?? 'card';

                    return GestureDetector(
                      onTap: () {
                        if (_selectMode) {
                          _toggleSelect(id);
                        } else {
                          _openDocument(doc);
                        }
                      },
                      onLongPress: () {
                        if (!_selectMode) _toggleSelectMode();
                        _toggleSelect(id);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E2E),
                          borderRadius: BorderRadius.circular(16),
                          border: isSelected
                              ? Border.all(
                                  color: Colors.redAccent, width: 2)
                              : null,
                        ),
                        child: Stack(
                          children: [
                            Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius:
                                        const BorderRadius.vertical(
                                            top: Radius.circular(16)),
                                    child: doc['front_path'] != null
                                        ? Image.file(
                                            File(doc['front_path']),
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                          )
                                        : Container(
                                            color: Colors.grey.shade800,
                                            child: Center(
                                              child: Icon(
                                                mode == 'document'
                                                    ? Icons.article_rounded
                                                    : Icons.credit_card_rounded,
                                                color: Colors.grey.shade600,
                                                size: 36,
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        doc['name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            mode == 'document'
                                                ? Icons.article_rounded
                                                : Icons.credit_card_rounded,
                                            size: 11,
                                            color: mode == 'document'
                                                ? const Color(0xFF03DAC6)
                                                : const Color(0xFF6C63FF),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            mode == 'document'
                                                ? 'Doc • ${doc['page_size'] ?? 'A4'}'
                                                : 'Card',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: mode == 'document'
                                                  ? const Color(0xFF03DAC6)
                                                  : const Color(0xFF6C63FF),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Colors.redAccent,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                            // Drive badge
                            if (_useDrive)
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.black.withOpacity(0.5),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.cloud_done_rounded,
                                    size: 12,
                                    color: Color(0xFF03DAC6),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
