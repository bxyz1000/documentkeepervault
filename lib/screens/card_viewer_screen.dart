import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class CardViewerScreen extends StatefulWidget {
  final Map<String, dynamic> document;
  const CardViewerScreen({super.key, required this.document});

  @override
  State<CardViewerScreen> createState() => _CardViewerScreenState();
}

class _CardViewerScreenState extends State<CardViewerScreen>
    with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _floatController;
  late AnimationController _tossController;

  late Animation<double> _flipAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _tossAnimation;

  bool _isFrontVisible = true;
  bool _isAnimating = false;
  double _dragVelocity = 0;
  Offset _cardOffset = Offset.zero;
  double _cardRotation = 0;

  bool get _hasBack => widget.document['back_path'] != null;

  String get _currentImagePath => _isFrontVisible
      ? widget.document['front_path'] as String
      : widget.document['back_path'] as String;

  @override
  void initState() {
    super.initState();

    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _tossController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _tossAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _tossController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _flipController.dispose();
    _floatController.dispose();
    _tossController.dispose();
    super.dispose();
  }

  void _flipCard() {
    if (_isAnimating) return;
    if (!_hasBack) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No back side added for this document'),
          backgroundColor: Color(0xFF1E1E2E),
        ),
      );
      return;
    }
    setState(() => _isAnimating = true);
    if (_isFrontVisible) {
      _flipController.forward().then((_) {
        setState(() {
          _isFrontVisible = false;
          _isAnimating = false;
        });
        _flipController.reset();
      });
    } else {
      _flipController.forward().then((_) {
        setState(() {
          _isFrontVisible = true;
          _isAnimating = false;
        });
        _flipController.reset();
      });
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return;
    setState(() {
      _cardOffset += details.delta;
      _cardRotation = _cardOffset.dx * 0.001;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    _dragVelocity = details.velocity.pixelsPerSecond.dx.abs();
    if (_dragVelocity > 800) {
      _triggerToss();
    } else {
      _snapBack();
    }
  }

  void _triggerToss() {
    if (_isAnimating) return;
    setState(() => _isAnimating = true);
    _tossController.forward().then((_) {
      _tossController.reset();
      if (_hasBack) {
        setState(() {
          _isFrontVisible = !_isFrontVisible;
          _cardOffset = Offset.zero;
          _cardRotation = 0;
          _isAnimating = false;
        });
      } else {
        setState(() {
          _cardOffset = Offset.zero;
          _cardRotation = 0;
          _isAnimating = false;
        });
      }
    });
  }

  void _snapBack() {
    final startOffset = _cardOffset;
    final startRotation = _cardRotation;
    final snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final snapAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: snapController, curve: Curves.elasticOut),
    );
    snapAnim.addListener(() {
      setState(() {
        _cardOffset = Offset.lerp(startOffset, Offset.zero, snapAnim.value)!;
        _cardRotation = lerpDouble(startRotation, 0, snapAnim.value)!;
      });
    });
    snapController.forward().then((_) => snapController.dispose());
  }

  double? lerpDouble(double a, double b, double t) => a + (b - a) * t;

  // SHARE current side image
  Future<void> _shareImage() async {
    try {
      final file = XFile(_currentImagePath);
      await Share.shareXFiles(
        [file],
        text: widget.document['name'] ?? 'Document',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Share failed: $e')),
        );
      }
    }
  }

  // DOWNLOAD — copies image to Downloads folder
  Future<void> _downloadImage() async {
    try {
      final sourcePath = _currentImagePath;
      final docName = (widget.document['name'] ?? 'document')
          .toString()
          .replaceAll(' ', '_');
      final side = _isFrontVisible ? 'front' : 'back';
      final fileName = '${docName}_$side.jpg';

      // Save to app's external storage (visible in Files app)
      final dir = await getExternalStorageDirectory();
      if (dir == null) throw Exception('Storage not available');

      // Go up to root external storage and use Downloads
      final downloadsPath = dir.path.split('Android')[0] + 'Download';
      final downloadsDir = Directory(downloadsPath);
      if (!await downloadsDir.exists()) await downloadsDir.create(recursive: true);

      final destPath = '$downloadsPath/$fileName';
      await File(sourcePath).copy(destPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads/$fileName'),
            backgroundColor: const Color(0xFF1E1E2E),
            action: SnackBarAction(
              label: 'OK',
              textColor: const Color(0xFFFFBE0B),
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
    }
  }

  void _showShareOptions() {
    showModalBottomSheet(
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
            Text(
              '${_isFrontVisible ? "Front" : "Back"} Side',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _shareImage();
                    },
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
                          Icon(Icons.share_rounded,
                              color: Color(0xFF6C63FF), size: 36),
                          SizedBox(height: 8),
                          Text('Share',
                              style:
                                  TextStyle(color: Color(0xFF6C63FF))),
                          SizedBox(height: 4),
                          Text('WhatsApp, Gmail...',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      _downloadImage();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFBE0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: const Color(0xFFFFBE0B), width: 1),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.download_rounded,
                              color: Color(0xFFFFBE0B), size: 36),
                          SizedBox(height: 8),
                          Text('Download',
                              style:
                                  TextStyle(color: Color(0xFFFFBE0B))),
                          SizedBox(height: 4),
                          Text('Save to Downloads',
                              style: TextStyle(
                                  color: Colors.grey, fontSize: 11)),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A15),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.document['name'] ?? '',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.ios_share_rounded,
                color: Color(0xFF6C63FF)),
            onPressed: _showShareOptions,
            tooltip: 'Share / Download',
          ),
          if (_hasBack)
            TextButton.icon(
              onPressed: _flipCard,
              icon: const Icon(Icons.flip, color: Color(0xFF6C63FF)),
              label: const Text('Flip',
                  style: TextStyle(color: Color(0xFF6C63FF))),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge(
                    [_flipAnimation, _floatAnimation, _tossAnimation]),
                builder: (context, child) {
                  final floatY = _floatAnimation.value;
                  final tossRotation = _tossAnimation.value * pi * 2;

                  return Transform.translate(
                    offset: Offset(
                      _cardOffset.dx,
                      _cardOffset.dy + floatY,
                    ),
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(_isAnimating && _tossController.isAnimating
                            ? tossRotation
                            : _flipAnimation.value * pi)
                        ..rotateZ(_cardRotation),
                      child: GestureDetector(
                        onTap: _flipCard,
                        onPanUpdate: _onPanUpdate,
                        onPanEnd: _onPanEnd,
                        child: _buildCard(),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          _buildBottomHints(),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final frontPath = widget.document['front_path'] as String?;
    final backPath = widget.document['back_path'] as String?;
    final showFront = _isFrontVisible;
    final imagePath = showFront ? frontPath : backPath;

    return Stack(
      children: [
        Container(
          width: 320,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 5,
                offset: const Offset(0, 20),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.6),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: imagePath != null
                ? Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    width: 320,
                    height: 200,
                  )
                : Container(
                    color: const Color(0xFF1E1E2E),
                    child: const Center(
                      child: Icon(Icons.image_not_supported_rounded,
                          color: Colors.grey, size: 48),
                    ),
                  ),
          ),
        ),
        Container(
          width: 320,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
                Colors.transparent,
                Colors.white.withOpacity(0.08),
              ],
              stops: const [0.0, 0.3, 0.6, 1.0],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
        ),
        Positioned(
          top: 12,
          left: 20,
          right: 80,
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 12,
          right: 16,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.white.withOpacity(0.2), width: 1),
            ),
            child: Text(
              showFront ? 'FRONT' : 'BACK',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomHints() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 40),
      child: Column(
        children: [
          if (_hasBack)
            const Text(
              'Toss or tap to flip card',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            )
          else
            const Text(
              'No back side for this document',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _HintChip(icon: Icons.swipe, label: 'Swipe to toss'),
              const SizedBox(width: 12),
              _HintChip(icon: Icons.touch_app, label: 'Tap to flip'),
              const SizedBox(width: 12),
              _HintChip(
                  icon: Icons.ios_share_rounded, label: 'Share / Save'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _HintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6C63FF)),
          const SizedBox(width: 6),
          Text(label,
              style:
                  const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}