// lib/widgets/tile_widget.dart

import 'package:flutter/material.dart';
import '../models/puzzle_tile.dart';

class TileWidget extends StatefulWidget {
  final PuzzleTile tile;
  final VoidCallback? onTap;
  final bool canMove;
  final double tileSize;

  const TileWidget({
    super.key,
    required this.tile,
    this.onTap,
    required this.canMove,
    required this.tileSize,
  });

  @override
  State<TileWidget> createState() => _TileWidgetState();
}

class _TileWidgetState extends State<TileWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.93).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.canMove && !widget.tile.isEmpty) {
      setState(() => _isPressed = true);
      _scaleController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tile.isEmpty) {
      return _buildEmptyTile();
    }

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.canMove ? widget.onTap : null,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: _buildImageTile(),
      ),
    );
  }

  Widget _buildEmptyTile() {
    return Container(
      width: widget.tileSize,
      height: widget.tileSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.transparent,
      ),
    );
  }

  Widget _buildImageTile() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: widget.tileSize,
      height: widget.tileSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: _isPressed
                ? Colors.pinkAccent.withOpacity(0.6)
                : Colors.black.withOpacity(0.25),
            blurRadius: _isPressed ? 12 : 6,
            spreadRadius: _isPressed ? 2 : 0,
            offset: const Offset(0, 3),
          ),
        ],
        border: widget.canMove
            ? Border.all(
                color: Colors.white.withOpacity(0.6),
                width: 1.5,
              )
            : Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: widget.tile.imageBytes != null
            ? Image.memory(
                widget.tile.imageBytes!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              )
            : _buildPlaceholderTile(),
      ),
    );
  }

  Widget _buildPlaceholderTile() {
    final colors = [
      [const Color(0xFFFF6B9D), const Color(0xFFFF8E53)],
      [const Color(0xFF9B59B6), const Color(0xFFE91E8C)],
      [const Color(0xFF667EEA), const Color(0xFF764BA2)],
      [const Color(0xFFFF6B6B), const Color(0xFFFFE66D)],
      [const Color(0xFF4ECDC4), const Color(0xFF556270)],
      [const Color(0xFFA8EDEA), const Color(0xFFFED6E3)],
      [const Color(0xFFD299C2), const Color(0xFFFEF9D7)],
      [const Color(0xFF89F7FE), const Color(0xFF66A6FF)],
      [const Color(0xFFFDDB92), const Color(0xFFD1FDFF)],
    ];

    final idx = widget.tile.correctIndex % colors.length;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors[idx],
        ),
      ),
      child: Center(
        child: Text(
          '${widget.tile.correctIndex + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: widget.tileSize * 0.3,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
