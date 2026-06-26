import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/storage_service.dart';
import '../services/drive_storage_service.dart';
import '../services/google_auth_service.dart';

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

  // Content mode selection
  String _contentMode = ''; // '' = not chosen, 'card', 'document'
  String _pageSize = 'A4';
  double? _customWidth;
  double? _customHeight;
  bool _modeChosen = false;

  final List<String> _pageSizes = ['A4', 'Letter', 'A5', 'Custom'];

  Future<void> _pickImage(bool isFront) async {
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
            const Text('Choose Source',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: _SourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF6C63FF),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _SourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  color: const Color(0xFF03DAC6),
                  onTap: () =>
                      Navigator.pop(context, ImageSource.gallery),
                ),
              ),
            ]),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
    if (source == null) return;
    final picked =
        await _picker.pickImage(source: source, imageQuality: 85);
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
      _snack('Please enter a document name');
      return;
    }
    if (_frontImage == null) {
      _snack('Please add the front image');
      return;
    }
    setState(() => _isSaving = true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;

    if (GoogleAuthService.isSignedIn) {
      // Upload to Drive
      final frontId = await DriveStorageService.uploadImage(
          _frontImage!, 'front_$timestamp.jpg');
      String? backId;
      if (_backImage != null) {
        backId = await DriveStorageService.uploadImage(
            _backImage!, 'back_$timestamp.jpg');
      }
      if (frontId == null) {
        setState(() => _isSaving = false);
        _snack('Upload failed — check your connection');
        return;
      }
      await DriveStorageService.saveDocument(
        name: _nameController.text.trim(),
        category: widget.category,
        frontDriveId: frontId,
        backDriveId: backId,
        contentMode: _contentMode,
        pageSize: _pageSize,
        customWidth: _customWidth,
        customHeight: _customHeight,
      );
    } else {
      // Fallback: local storage
      final frontPath = await StorageService.saveImage(
          _frontImage!, 'front_$timestamp.jpg');
      String? backPath;
      if (_backImage != null) {
        backPath = await StorageService.saveImage(
            _backImage!, 'back_$timestamp.jpg');
      }
      await StorageService.saveDocument(
        name: _nameController.text.trim(),
        category: widget.category,
        frontPath: frontPath,
        backPath: backPath,
      );
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context, true);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // Step 1: choose Card or Document
  Widget _buildModePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose content type',
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 6),
        const Text(
          'Card: ID cards, photos (flip animation). Document: PDFs, papers (A4/Letter, enhance).',
          style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _ModeCard(
                icon: Icons.credit_card_rounded,
                title: 'Card',
                subtitle: 'Flip, zoom, toss',
                color: const Color(0xFF6C63FF),
                selected: _contentMode == 'card',
                onTap: () =>
                    setState(() => _contentMode = 'card'),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _ModeCard(
                icon: Icons.article_rounded,
                title: 'Document',
                subtitle: 'A4/Letter, enhance',
                color: const Color(0xFF03DAC6),
                selected: _contentMode == 'document',
                onTap: () =>
                    setState(() => _contentMode = 'document'),
              ),
            ),
          ],
        ),
        if (_contentMode == 'document') ...[
          const SizedBox(height: 24),
          const Text('Page Size',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: _pageSizes.map((size) {
              final selected = _pageSize == size;
              return ChoiceChip(
                label: Text(size),
                selected: selected,
                selectedColor: const Color(0xFF03DAC6).withOpacity(0.25),
                onSelected: (_) =>
                    setState(() => _pageSize = size),
                labelStyle: TextStyle(
                  color: selected
                      ? const Color(0xFF03DAC6)
                      : Colors.grey,
                ),
                side: BorderSide(
                  color: selected
                      ? const Color(0xFF03DAC6)
                      : Colors.grey.shade800,
                ),
                backgroundColor: const Color(0xFF1E1E2E),
              );
            }).toList(),
          ),
          if (_pageSize == 'Custom') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _NumField(
                    label: 'Width (pt)',
                    onChanged: (v) =>
                        _customWidth = double.tryParse(v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _NumField(
                    label: 'Height (pt)',
                    onChanged: (v) =>
                        _customHeight = double.tryParse(v),
                  ),
                ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _contentMode.isEmpty
                ? null
                : () => setState(() => _modeChosen = true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _contentMode == 'document'
                  ? const Color(0xFF03DAC6)
                  : const Color(0xFF6C63FF),
              disabledBackgroundColor: Colors.grey.shade800,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Continue',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Text('Add to ${widget.category}'),
        leading: _modeChosen
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    setState(() => _modeChosen = false),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: !_modeChosen
            ? _buildModePicker()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Content mode badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (_contentMode == 'document'
                                  ? const Color(0xFF03DAC6)
                                  : const Color(0xFF6C63FF))
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _contentMode == 'document'
                              ? 'Document • $_pageSize'
                              : 'Card Mode',
                          style: TextStyle(
                            color: _contentMode == 'document'
                                ? const Color(0xFF03DAC6)
                                : const Color(0xFF6C63FF),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
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
                  Text(
                    _contentMode == 'document' ? 'Page 1 (Front)' : 'Front Side',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _ImageBox(
                    image: _frontImage,
                    label: 'Tap to add front',
                    onTap: () => _pickImage(true),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _contentMode == 'document'
                        ? 'Page 2 / Back (Optional)'
                        : 'Back Side (Optional)',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  _ImageBox(
                    image: _backImage,
                    label: 'Tap to add back',
                    onTap: _hasFront ? () => _pickImage(false) : null,
                    disabled: !_hasFront,
                  ),
                  const SizedBox(height: 40),
                  if (GoogleAuthService.isSignedIn)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(Icons.cloud_upload_rounded,
                              color: Color(0xFF03DAC6), size: 16),
                          SizedBox(width: 8),
                          Text('Will be saved to your Google Drive',
                              style: TextStyle(
                                  color: Color(0xFF03DAC6), fontSize: 12)),
                        ],
                      ),
                    ),
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
                          ? const CircularProgressIndicator(
                              color: Colors.white)
                          : const Text('Save Document',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool selected;
  final VoidCallback onTap;
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? color.withOpacity(0.12)
              : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.grey.shade800,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? color : Colors.grey, size: 36),
            const SizedBox(height: 10),
            Text(title,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: selected ? color : Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle,
                style:
                    const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SourceButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color, width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 36),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final ValueChanged<String> onChanged;
  const _NumField({required this.label, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      keyboardType: TextInputType.number,
      style: const TextStyle(color: Colors.white),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.grey),
        filled: true,
        fillColor: const Color(0xFF1E1E2E),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
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
            color: disabled
                ? Colors.grey.shade800
                : const Color(0xFF6C63FF),
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
                      color: disabled
                          ? Colors.grey.shade700
                          : Colors.grey,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
EOF
echo "add_document_screen done"