import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

/// Document viewer with PDF-like rendering, zoom, page-size info, and Enhance.
class DocumentModeScreen extends StatefulWidget {
  final Map<String, dynamic> document;
  const DocumentModeScreen({super.key, required this.document});

  @override
  State<DocumentModeScreen> createState() => _DocumentModeScreenState();
}

class _DocumentModeScreenState extends State<DocumentModeScreen> {
  final TransformationController _transformController =
      TransformationController();
  bool _enhanced = false;
  bool _enhancing = false;
  img.Image? _enhancedImage;
  bool _showingBack = false;

  String get _currentPath => _showingBack
      ? (widget.document['back_drive_id'] as String? ?? widget.document['front_drive_id'] as String? ?? '')
      : (widget.document['front_path'] as String? ?? '');

  bool get _hasBack => widget.document['back_drive_id'] != null ||
      widget.document['back_path'] != null;

  String get _pageSize => widget.document['page_size'] as String? ?? 'A4';

  Size get _pageDimensions {
    switch (_pageSize) {
      case 'Letter':
        return const Size(612, 792);
      case 'A5':
        return const Size(420, 595);
      case 'Custom':
        return Size(
          (widget.document['custom_width'] as double?) ?? 595,
          (widget.document['custom_height'] as double?) ?? 842,
        );
      case 'A4':
      default:
        return const Size(595, 842);
    }
  }

  Future<void> _enhanceImage() async {
    final path = _currentPath;
    if (path.isEmpty) return;
    setState(() => _enhancing = true);

    try {
      final bytes = await File(path).readAsBytes();
      var decoded = img.decodeImage(bytes);
      if (decoded == null) throw Exception('Could not decode image');

      // Simulate document enhancement:
      // 1. Increase contrast
      decoded = img.adjustColor(decoded, contrast: 1.3);
      // 2. Increase brightness slightly
      decoded = img.adjustColor(decoded, brightness: 1.1);
      // 3. Grayscale (document look)
      decoded = img.grayscale(decoded);
      // 4. Re-adjust contrast for crisp blacks/whites
      decoded = img.adjustColor(decoded, contrast: 1.4);

      setState(() {
        _enhancedImage = decoded;
        _enhanced = true;
        _enhancing = false;
      });
    } catch (e) {
      setState(() => _enhancing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Enhance failed: $e')),
        );
      }
    }
  }

  void _resetEnhance() {
    setState(() {
      _enhanced = false;
      _enhancedImage = null;
    });
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  void _showPageSizeInfo() {
    final dims = _pageDimensions;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Document Page Size',
                style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            _InfoRow(label: 'Format', value: _pageSize),
            _InfoRow(
                label: 'Width',
                value: '${dims.width.toStringAsFixed(0)} pt'),
            _InfoRow(
                label: 'Height',
                value: '${dims.height.toStringAsFixed(0)} pt'),
            const SizedBox(height: 12),
            const Text(
              'Document sizes are stored as metadata. The image is displayed at full quality within the chosen page aspect ratio.',
              style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.5),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    final path = _currentPath;

    if (_enhanced && _enhancedImage != null) {
      final pngBytes = img.encodePng(_enhancedImage!);
      return Image.memory(pngBytes, fit: BoxFit.contain);
    }

    if (path.isEmpty) {
      return const Center(
        child: Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
      );
    }

    return Image.file(File(path), fit: BoxFit.contain);
  }

  @override
  Widget build(BuildContext context) {
    final dims = _pageDimensions;
    final aspectRatio = dims.width / dims.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A15),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E2E),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.document['name'] ?? '',
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Document • $_pageSize',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 11)),
          ],
        ),
        actions: [
          // Enhance toggle
          IconButton(
            icon: Icon(
              _enhanced ? Icons.auto_fix_high : Icons.auto_fix_normal,
              color: _enhanced
                  ? const Color(0xFF03DAC6)
                  : const Color(0xFF6C63FF),
            ),
            tooltip: _enhanced ? 'Remove Enhance' : 'Enhance Document',
            onPressed: _enhancing
                ? null
                : (_enhanced ? _resetEnhance : _enhanceImage),
          ),
          // Page size info
          IconButton(
            icon: const Icon(Icons.article_outlined,
                color: Color(0xFFFFBE0B)),
            tooltip: 'Page Size Info',
            onPressed: _showPageSizeInfo,
          ),
          // Reset zoom
          IconButton(
            icon: const Icon(Icons.zoom_out_map_rounded,
                color: Colors.grey),
            tooltip: 'Reset Zoom',
            onPressed: _resetZoom,
          ),
        ],
      ),
      body: Column(
        children: [
          if (_enhancing)
            const LinearProgressIndicator(
              backgroundColor: Color(0xFF1E1E2E),
              color: Color(0xFF03DAC6),
            ),
          // Status bar
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1E1E2E),
            child: Row(
              children: [
                if (_enhanced)
                  _StatusChip(
                      label: 'Enhanced',
                      color: const Color(0xFF03DAC6),
                      icon: Icons.auto_fix_high),
                if (_enhanced) const SizedBox(width: 8),
                _StatusChip(
                    label: _pageSize,
                    color: const Color(0xFFFFBE0B),
                    icon: Icons.article_outlined),
                const Spacer(),
                const Text('Pinch to zoom',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(width: 8),
                const Icon(Icons.pinch_rounded,
                    color: Colors.grey, size: 14),
              ],
            ),
          ),
          Expanded(
            child: GestureDetector(
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.6),
                          blurRadius: 30,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: AspectRatio(
                      aspectRatio: aspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: _buildImage(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Bottom: flip if back exists
          if (_hasBack)
            Container(
              color: const Color(0xFF1E1E2E),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showingBack = !_showingBack;
                        _enhanced = false;
                        _enhancedImage = null;
                      });
                    },
                    icon: const Icon(Icons.flip_rounded,
                        color: Color(0xFF6C63FF)),
                    label: Text(
                      _showingBack ? 'View Front' : 'View Back',
                      style:
                          const TextStyle(color: Color(0xFF6C63FF)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  const _StatusChip(
      {required this.label, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(color: Colors.grey, fontSize: 14)),
          ),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
        ],
      ),
    );
  }
}
