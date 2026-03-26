// lib/models/puzzle_tile.dart

import 'dart:typed_data';

class PuzzleTile {
  final int correctIndex; // The position this tile belongs to (0-8)
  int currentIndex;       // The position this tile is currently at
  final Uint8List? imageBytes; // The cropped image bytes for this tile
  final bool isEmpty;     // True only for the blank sliding tile

  PuzzleTile({
    required this.correctIndex,
    required this.currentIndex,
    this.imageBytes,
    this.isEmpty = false,
  });

  PuzzleTile copyWith({
    int? currentIndex,
  }) {
    return PuzzleTile(
      correctIndex: correctIndex,
      currentIndex: currentIndex ?? this.currentIndex,
      imageBytes: imageBytes,
      isEmpty: isEmpty,
    );
  }

  bool get isInCorrectPosition => currentIndex == correctIndex;
}
