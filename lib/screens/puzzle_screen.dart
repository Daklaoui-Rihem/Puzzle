// lib/screens/puzzle_screen.dart

import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';

import '../models/puzzle_tile.dart';
import '../widgets/tile_widget.dart';

class PuzzleScreen extends StatefulWidget {
  const PuzzleScreen({super.key});

  @override
  State<PuzzleScreen> createState() => _PuzzleScreenState();
}

class _PuzzleScreenState extends State<PuzzleScreen>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  List<PuzzleTile> _tiles = [];
  Uint8List? _originalImageBytes;
  bool _imageLoaded = false;
  bool _isSolved = false;
  bool _isAnimating = false;
  bool _isLoading = false;

  int _moveCount = 0;
  int _seconds = 180; // 3 minutes in seconds
  Timer? _timer;
  bool _timerStarted = false;

  int _gridSize = 3; // 3x3 default

  // ── Controllers ────────────────────────────────────────────────────────────
  late ConfettiController _confettiController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  late AnimationController _winAnimController;
  late AnimationController _tileAnimController;

  @override
  void initState() {
    super.initState();

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 6));

    _winAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _tileAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _winAnimController.dispose();
    _tileAnimController.dispose();
    _audioPlayer.dispose();
    _timer?.cancel();
    super.dispose();
  }

  // ── Image Loading ──────────────────────────────────────────────────────────

  Future<void> _loadAssetImage(String assetPath) async {
    setState(() => _isLoading = true);
    try {
      final data = await rootBundle.load(assetPath);
      await _processImage(data.buffer.asUint8List());
    } catch (e) {
      _showSnackBar('Could not load image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePlaceholderImage() async {
    // Create a beautiful gradient placeholder image
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const size = 300.0;

    final paint = Paint();

    // Romantic gradient background
    final gradient = ui.Gradient.linear(
      const Offset(0, 0),
      const Offset(size, size),
      [
        const Color(0xFFFF6B9D),
        const Color(0xFFFF8E53),
        const Color(0xFF9B59B6),
        const Color(0xFF667EEA),
      ],
      [0.0, 0.33, 0.66, 1.0],
    );

    paint.shader = gradient;
    canvas.drawRect(const Rect.fromLTWH(0, 0, size, size), paint);

    // Add decorative hearts
    _drawHeart(canvas, const Offset(size / 2, size / 2), 60,
        Colors.white.withValues(alpha: 0.3));
    _drawHeart(canvas, const Offset(80, 80), 30,
        Colors.white.withValues(alpha: 0.2));
    _drawHeart(canvas, const Offset(220, 220), 30,
        Colors.white.withValues(alpha: 0.2));
    _drawHeart(canvas, const Offset(220, 80), 20,
        Colors.white.withValues(alpha: 0.15));
    _drawHeart(canvas, const Offset(80, 220), 20,
        Colors.white.withValues(alpha: 0.15));

    // Add text
    final textStyle = ui.TextStyle(
      color: Colors.white,
      fontSize: 22,
      fontWeight: ui.FontWeight.bold,
    );
    final paraBuilder = ui.ParagraphBuilder(
        ui.ParagraphStyle(textAlign: TextAlign.center))
      ..pushStyle(textStyle)
      ..addText('Add Your\nPhoto');
    final para = paraBuilder.build();
    para.layout(const ui.ParagraphConstraints(width: size));
    canvas.drawParagraph(
        para, Offset((size - size) / 2, size / 2 + 30));

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (byteData != null) {
      await _processImage(byteData.buffer.asUint8List());
    }
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final x = center.dx;
    final y = center.dy;
    final s = size / 2;

    path.moveTo(x, y + s * 0.5);
    path.cubicTo(x, y, x - s, y - s * 0.5, x - s, y - s * 1.2);
    path.cubicTo(x - s, y - s * 1.8, x, y - s * 1.8, x, y - s * 1.2);
    path.cubicTo(x, y - s * 1.8, x + s, y - s * 1.8, x + s, y - s * 1.2);
    path.cubicTo(x + s, y - s * 0.5, x, y, x, y + s * 0.5);
    path.close();

    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(-pi / 2);
    canvas.translate(-x, -y - s * 0.3);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  Future<void> _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 900,
        maxHeight: 900,
        imageQuality: 90,
      );
      if (picked == null) return;

      setState(() => _isLoading = true);
      final bytes = await picked.readAsBytes();
      await _processImage(bytes);
    } catch (e) {
      _showSnackBar('Could not load image: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _processImage(Uint8List bytes) async {
    _originalImageBytes = bytes;
    await _splitAndInitPuzzle(bytes);
    setState(() {
      _imageLoaded = true;
      _isSolved = false;
      _moveCount = 0;
      _seconds = 180;
      _timerStarted = false;
    });
    _timer?.cancel();
  }

  // ── Image Splitting ────────────────────────────────────────────────────────

  Future<void> _splitAndInitPuzzle(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(imageBytes);
    final frame = await codec.getNextFrame();
    final fullImage = frame.image;

    final int w = fullImage.width;
    final int h = fullImage.height;
    final int side = min(w, h);
    // Center-crop to square
    final int ox = (w - side) ~/ 2;
    final int oy = (h - side) ~/ 2;

    final int tileSize = side ~/ _gridSize;
    final List<PuzzleTile> tiles = [];
    final int total = _gridSize * _gridSize;

    for (int i = 0; i < total; i++) {
      final int col = i % _gridSize;
      final int row = i ~/ _gridSize;
      final bool isEmptyTile = (i == total - 1);

      Uint8List? tileBytes;

      if (!isEmptyTile) {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);

        final srcRect = Rect.fromLTWH(
          (ox + col * tileSize).toDouble(),
          (oy + row * tileSize).toDouble(),
          tileSize.toDouble(),
          tileSize.toDouble(),
        );
        final dstRect = Rect.fromLTWH(0, 0, 300, 300);

        canvas.drawImageRect(fullImage, srcRect, dstRect, Paint());

        final picture = recorder.endRecording();
        final tileImage = await picture.toImage(300, 300);
        final data = await tileImage.toByteData(format: ui.ImageByteFormat.png);
        tileBytes = data?.buffer.asUint8List();
      }

      tiles.add(PuzzleTile(
        correctIndex: i,
        currentIndex: i,
        imageBytes: tileBytes,
        isEmpty: isEmptyTile,
      ));
    }

    // Shuffle ensuring solvability
    _tiles = _shuffleSolvable(tiles);
    setState(() {});
  }

  // ── Shuffle (solvability guaranteed) ──────────────────────────────────────

  List<PuzzleTile> _shuffleSolvable(List<PuzzleTile> tiles) {
    final rng = Random();
    List<PuzzleTile> shuffled = List.from(tiles);
    int emptyPos = shuffled.indexWhere((t) => t.isEmpty);

    // Perform many random valid moves to shuffle
    for (int k = 0; k < 500; k++) {
      final neighbors = _getNeighborIndices(emptyPos);
      final next = neighbors[rng.nextInt(neighbors.length)];
      // Swap in list by currentIndex
      final emptyTile = shuffled.firstWhere((t) => t.currentIndex == emptyPos);
      final swapTile = shuffled.firstWhere((t) => t.currentIndex == next);

      final emptyListIdx = shuffled.indexOf(emptyTile);
      final swapListIdx = shuffled.indexOf(swapTile);

      shuffled[emptyListIdx] = PuzzleTile(
        correctIndex: emptyTile.correctIndex,
        currentIndex: next,
        imageBytes: emptyTile.imageBytes,
        isEmpty: emptyTile.isEmpty,
      );
      shuffled[swapListIdx] = PuzzleTile(
        correctIndex: swapTile.correctIndex,
        currentIndex: emptyPos,
        imageBytes: swapTile.imageBytes,
        isEmpty: swapTile.isEmpty,
      );
      emptyPos = next;
    }

    return shuffled;
  }

  List<int> _getNeighborIndices(int pos) {
    final List<int> neighbors = [];
    final row = pos ~/ _gridSize;
    final col = pos % _gridSize;

    if (row > 0) neighbors.add(pos - _gridSize); // up
    if (row < _gridSize - 1) neighbors.add(pos + _gridSize); // down
    if (col > 0) neighbors.add(pos - 1); // left
    if (col < _gridSize - 1) neighbors.add(pos + 1); // right

    return neighbors;
  }

  // ── Movement ───────────────────────────────────────────────────────────────

  bool _canMove(PuzzleTile tile) {
    if (tile.isEmpty) return false;
    final emptyTile = _tiles.firstWhere((t) => t.isEmpty);
    final neighbors = _getNeighborIndices(emptyTile.currentIndex);
    return neighbors.contains(tile.currentIndex);
  }

  Future<void> _moveTile(PuzzleTile tile) async {
    if (_isAnimating || !_canMove(tile)) return;
    _isAnimating = true;

    if (!_timerStarted) {
      _startTimer();
      _timerStarted = true;
    }

    final emptyTile = _tiles.firstWhere((t) => t.isEmpty);
    final tileListIdx = _tiles.indexOf(tile);
    final emptyListIdx = _tiles.indexOf(emptyTile);

    final int tilePos = tile.currentIndex;
    final int emptyPos = emptyTile.currentIndex;

    setState(() {
      _tiles[tileListIdx] = PuzzleTile(
        correctIndex: tile.correctIndex,
        currentIndex: emptyPos,
        imageBytes: tile.imageBytes,
        isEmpty: tile.isEmpty,
      );
      _tiles[emptyListIdx] = PuzzleTile(
        correctIndex: emptyTile.correctIndex,
        currentIndex: tilePos,
        imageBytes: emptyTile.imageBytes,
        isEmpty: emptyTile.isEmpty,
      );
      _moveCount++;
    });

    await Future.delayed(const Duration(milliseconds: 260));
    _isAnimating = false;

    _checkWin();
  }

  // ── Win ────────────────────────────────────────────────────────────────────

  void _checkWin() {
    final solved = _tiles.every((t) => t.currentIndex == t.correctIndex);
    if (solved && !_isSolved) {
      _isSolved = true;
      _timer?.cancel();
      _confettiController.play();
      _winAnimController.forward();
      _playWinSound();
      Future.delayed(const Duration(milliseconds: 400), () {
        _showWinDialog();
      });
    }
  }

  void _playWinSound() async {
    try {
      await _audioPlayer.play(AssetSource('audio/yay.mp3'));
    } catch (e) {
      debugPrint('Error playing win sound: $e');
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 0) {
        setState(() => _seconds--);
      } else {
        timer.cancel();
        _handleTimeUp();
      }
    });
  }

  void _handleTimeUp() {
    if (_isSolved) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2D0A4E),
        title: const Text('Time\'s Up! ⏰', style: TextStyle(color: Colors.white)),
        content: const Text('Don\'t give up, try again!', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _restartPuzzle();
            },
            child: const Text('Try Again', style: TextStyle(color: Colors.pinkAccent)),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    final m = _seconds ~/ 60;
    final s = _seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  void _showWinDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _WinDialog(
        moves: _moveCount,
        time: _formattedTime,
        originalImageBytes: _originalImageBytes,
        onPlayAgain: () {
          Navigator.of(ctx).pop();
          _restartPuzzle();
        },
      ),
    );
  }

  void _showPreviewDialog() {
    if (_originalImageBytes == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Original Image',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.memory(_originalImageBytes!,
                  width: 280, height: 280, fit: BoxFit.cover),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close',
                  style: TextStyle(color: Colors.pinkAccent, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  void _restartPuzzle() {
    _timer?.cancel();
    _winAnimController.reset();
    _confettiController.stop();
    setState(() {
      _isSolved = false;
      _moveCount = 0;
      _seconds = 180;
      _timerStarted = false;
    });
    if (_originalImageBytes != null) {
      _splitAndInitPuzzle(_originalImageBytes!);
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  void _showDifficultySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2D1B3D),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _DifficultySheet(
        current: _gridSize,
        onSelect: (size) {
          Navigator.pop(context);
          setState(() {
            _gridSize = size;
            _isSolved = false;
            _moveCount = 0;
            _seconds = 180;
            _timerStarted = false;
          });
          _timer?.cancel();
          if (_originalImageBytes != null) {
            _splitAndInitPuzzle(_originalImageBytes!);
          }
        },
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0533),
              Color(0xFF3D1155),
              Color(0xFF6B2483),
              Color(0xFF9C1A5E),
              Color(0xFFB5245C),
            ],
            stops: [0.0, 0.25, 0.5, 0.75, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              _buildMainContent(),
              _buildConfetti(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfetti() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        numberOfParticles: 40,
        gravity: 0.2,
        colors: const [
          Colors.pink,
          Colors.purple,
          Colors.white,
          Colors.yellow,
          Colors.red,
          Color(0xFFFF6B9D),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildHeader(),
        _buildStatsBar(),
        const SizedBox(height: 8),
        Expanded(child: _buildPuzzleArea()),
        _buildBottomBar(),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          // Logo / Title
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Puzzle',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  )),
              Text('Love Puzzle',
                  style: TextStyle(
                    color: Colors.pink[200],
                    fontSize: 12,
                    letterSpacing: 1.5,
                  )),
            ],
          ),
          const Spacer(),
          // Difficulty
          _HeaderButton(
            icon: Icons.grid_view_rounded,
            label: '${_gridSize}×$_gridSize',
            onTap: _showDifficultySheet,
          ),
          const SizedBox(width: 8),
          // Preview
          _HeaderButton(
            icon: Icons.remove_red_eye_outlined,
            label: 'Peek',
            onTap: _imageLoaded ? _showPreviewDialog : null,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(icon: Icons.touch_app_rounded, label: '$_moveCount moves'),
          _StatChip(
            icon: Icons.timer_outlined,
            label: _formattedTime,
            color: _seconds < 30 ? Colors.redAccent : null,
          ),
        ],
      ),
    );
  }

  Widget _buildPuzzleArea() {
    return Center(
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.pinkAccent)
          : !_imageLoaded
              ? _buildStartPrompt()
              : _buildGrid(),
    );
  }

  Widget _buildStartPrompt() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B9D), Color(0xFF9B59B6)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent.withValues(alpha: 0.5),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.photo_library_outlined,
                size: 50, color: Colors.white),
          ),
          const SizedBox(height: 20),
          const Text('Choose Your Photo',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Select a photo to begin',
              style: TextStyle(color: Colors.pink[200], fontSize: 14)),
          const SizedBox(height: 24),
          
          // Image Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: 6,
              itemBuilder: (context, index) {
                final assetPath = 'assets/images/pic${index + 1}.jpeg';
                return GestureDetector(
                  onTap: () => _loadAssetImage(assetPath),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                      image: DecorationImage(
                        image: AssetImage(assetPath),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 30),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _PrimaryButton(
                label: '📷 Pick from Gallery',
                onTap: _pickFromGallery),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(builder: (ctx, constraints) {
      final available = min(constraints.maxWidth, constraints.maxHeight);
      final gridSize = available * 0.92;
      const gap = 5.0;
      final tileSize =
          (gridSize - gap * (_gridSize - 1)) / _gridSize;

      return Container(
        width: gridSize,
        height: gridSize,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.1),
              Colors.white.withValues(alpha: 0.05),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: _buildTileStack(tileSize, gap),
        ),
      );
    });
  }

  List<Widget> _buildTileStack(double tileSize, double gap) {
    return _tiles.map((tile) {
      final row = tile.currentIndex ~/ _gridSize;
      final col = tile.currentIndex % _gridSize;
      final left = col * (tileSize + gap);
      final top = row * (tileSize + gap);

      return AnimatedPositioned(
        key: ValueKey(tile.correctIndex),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        left: left,
        top: top,
        child: TileWidget(
          tile: tile,
          canMove: _canMove(tile),
          tileSize: tileSize,
          onTap: () => _moveTile(tile),
        ),
      );
    }).toList();
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _PrimaryButton(
              label: '📷 Change Photo',
              onTap: _pickFromGallery,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SecondaryButton(
              label: '🔀 Shuffle',
              onTap: _imageLoaded ? _restartPuzzle : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ──────────────────────────────────────────────────────────────

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _HeaderButton(
      {required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.pink[200]),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    color: Colors.pink[100],
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _StatChip({required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withValues(alpha: 0.1),
        border: Border.all(color: (color ?? Colors.pink).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color ?? Colors.pinkAccent),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  color: color ?? Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _PrimaryButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: onTap != null
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFF9B59B6)])
              : null,
          color: onTap == null ? Colors.grey.withValues(alpha: 0.3) : null,
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: Colors.pinkAccent.withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ]
              : null,
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SecondaryButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          color: Colors.white.withValues(alpha: 0.12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

// ── Win Dialog ───────────────────────────────────────────────────────────────

class _WinDialog extends StatefulWidget {
  final int moves;
  final String time;
  final Uint8List? originalImageBytes;
  final VoidCallback onPlayAgain;

  const _WinDialog({
    required this.moves,
    required this.time,
    required this.originalImageBytes,
    required this.onPlayAgain,
  });

  @override
  State<_WinDialog> createState() => _WinDialogState();
}

class _WinDialogState extends State<_WinDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: ScaleTransition(
          scale: _scale,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2D0A4E), Color(0xFF5C1060)],
              ),
              border: Border.all(
                  color: Colors.pinkAccent.withValues(alpha: 0.5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.pinkAccent.withValues(alpha: 0.3),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
            ),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🎉', style: TextStyle(fontSize: 52)),
                const SizedBox(height: 8),
                const Text('You Did It!',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text('You solved it with ${widget.time} remaining',
                    style: TextStyle(
                        color: Colors.pink[200],
                        fontSize: 15)),
                const SizedBox(height: 20),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _WinStat(
                        icon: '⏱️', label: 'Remaining', value: widget.time),
                    _WinStat(
                        icon: '👆',
                        label: 'Moves',
                        value: '${widget.moves}'),
                  ],
                ),
                const SizedBox(height: 20),
                // Original image preview
                if (widget.originalImageBytes != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.memory(widget.originalImageBytes!,
                        width: 200, height: 200, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 16),
                const Text(
                  'Ken 7ablek rabi mat7elhech',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: widget.onPlayAgain,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6B9D), Color(0xFF9B59B6)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.pinkAccent.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('Play Again 🔀',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WinStat extends StatelessWidget {
  final String icon;
  final String label;
  final String value;

  const _WinStat(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.1),
      ),
      child: Column(
        children: [
          Text(icon, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          Text(label,
              style: TextStyle(color: Colors.pink[200], fontSize: 12)),
        ],
      ),
    );
  }
}

// ── Difficulty Sheet ──────────────────────────────────────────────────────────

class _DifficultySheet extends StatelessWidget {
  final int current;
  final void Function(int) onSelect;

  const _DifficultySheet({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Choose Difficulty',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _DifficultyCard(
                      size: 3,
                      label: 'Easy',
                      emoji: '😊',
                      isSelected: current == 3,
                      onTap: () => onSelect(3))),
              const SizedBox(width: 12),
              Expanded(
                  child: _DifficultyCard(
                      size: 4,
                      label: 'Hard',
                      emoji: '🔥',
                      isSelected: current == 4,
                      onTap: () => onSelect(4))),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DifficultyCard extends StatelessWidget {
  final int size;
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _DifficultyCard({
    required this.size,
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFF9B59B6)])
              : null,
          color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
          border: Border.all(
            color: isSelected
                ? Colors.pinkAccent
                : Colors.white.withValues(alpha: 0.2),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(height: 6),
            Text('${size}×$size',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800)),
            Text(label,
                style:
                    TextStyle(color: Colors.pink[200], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
