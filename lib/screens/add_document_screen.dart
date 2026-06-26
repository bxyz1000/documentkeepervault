import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';

class AddDocumentScreen extends StatefulWidget {
  final String category;
  const AddDocumentScreen({super.key, required this.category});

  @override
  State<AddDocumentScreen> createState() => _AddDocumentScreenState();
}

class _AddDocumentScreenState extends State<AddDocumentScreen> {
  final _picker = ImagePicker();
  final _nameController = TextEditingController();
  File? _frontImage;
  File? _backImage;
  bool _hasFront = false;
  bool _isSaving = false;

  Future<void> _pickImage(bool isFront) async {
    // Show bottom sheet to choose camera or gallery
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Source',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, ImageSource.camera),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6C63FF).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF6C63FF), width: 1),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: Color(0xFF6C63FF), size: 36),
                          SizedBox(height: 8),
                          Text('Camera',
                              style: TextStyle(color: Color(0xFF6C63FF))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, ImageSource.gallery),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF03DAC6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFF03DAC6), width: 1),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.photo_library_rounded,
                              color: Color(0xFF03DAC6), size: 36),
                          SizedBox(height: 8),
                          Text('Gallery',
                              style: TextStyle(color: Color(0xFF03DAC6))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      if (isFront) {
        _frontImage = File(picked.path);
        _hasFront = true;
      } else {
        _backImage = File(picked.path);
      }
    });
  }

  Future<void> _saveDocument() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a document name')),
      );
      return;
    }
    if (_frontImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please scan the front of document')),
      );
      return;
    }

    setState(() => _isSaving = true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final frontPath = await StorageService.saveImage(
      _frontImage!,
      'front_$timestamp.jpg',
    );

    String? backPath;
    if (_backImage != null) {
      backPath = await StorageService.saveImage(
        _backImage!,
        'back_$timestamp.jpg',
      );
    }

    await StorageService.saveDocument(
      name: _nameController.text.trim(),
      category: widget.category,
      frontPath: frontPath,
      backPath: backPath,
    );

    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text('Add to ${widget.category}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Document Name',
                labelStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF1E1E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 28),
            const Text('Front Side',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _ImageBox(
              image: _frontImage,
              label: 'Tap to add front',
              onTap: () => _pickImage(true),
            ),
            const SizedBox(height: 24),
            const Text('Back Side (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _ImageBox(
              image: _backImage,
              label: 'Tap to add back',
              onTap: _hasFront ? () => _pickImage(false) : null,
              disabled: !_hasFront,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Save Document',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageBox extends StatelessWidget {
  final File? image;
  final String label;
  final VoidCallback? onTap;
  final bool disabled;

  const _ImageBox({
    required this.image,
    required this.label,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: double.infinity,
        height: 180,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: disabled ? Colors.grey.shade800 : const Color(0xFF6C63FF),
            width: 1.5,
          ),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(image!, fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_rounded,
                    size: 40,
                    color: disabled
                        ? Colors.grey.shade700
                        : const Color(0xFF6C63FF),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    label,
                    style: TextStyle(
                      color: disabled ? Colors.grey.shade700 : Colors.grey,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}