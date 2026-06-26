import 'dart:io';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'add_document_screen.dart';
import 'card_viewer_screen.dart';

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
  List<Map<String, dynamic>> _documents = [];
  bool _selectMode = false;
  Set<int> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final docs = await StorageService.getDocumentsByCategory(widget.category);
    setState(() => _documents = docs);
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
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    for (final id in _selectedIds) {
      await StorageService.deleteDocument(id);
    }

    setState(() {
      _selectMode = false;
      _selectedIds.clear();
    });
    _loadDocuments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text(_selectMode
            ? '${_selectedIds.length} selected'
            : widget.category),
        actions: [
          if (_selectMode) ...[
            if (_selectedIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
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
              tooltip: 'Select to delete',
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
      body: _documents.isEmpty
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
                      style:
                          TextStyle(color: Colors.grey, fontSize: 12)),
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

                return GestureDetector(
                  onTap: () {
                    if (_selectMode) {
                      _toggleSelect(id);
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CardViewerScreen(document: doc),
                        ),
                      );
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
                          crossAxisAlignment: CrossAxisAlignment.start,
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
                                        color: Colors.grey.shade800),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                doc['name'] ?? '',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}