# 💕 Love Puzzle — Flutter Photo Sliding Puzzle

A romantic sliding puzzle game built with Flutter. Rearrange shuffled tiles to reconstruct your personal photo!

---

## ✨ Features

- **3×3 & 4×4 grids** — tap the grid button to switch difficulty
- **Gallery photo picker** — select any photo from your device
- **Smooth AnimatedPositioned sliding** — 240ms easeOutCubic transitions
- **Scale animation on tap** — tiles shrink when pressed
- **Guaranteed solvable shuffle** — uses 500 random valid moves
- **Live timer & move counter**
- **Confetti celebration** on win
- **Win dialog** with stats + full image reveal + romantic quote
- **"Peek" preview** — view the original image any time
- **Romantic gradient UI** — deep purple → pink theme

---

## 📁 Project Structure

```
lib/
  main.dart                   ← App entry point
  models/
    puzzle_tile.dart          ← PuzzleTile data model
  screens/
    puzzle_screen.dart        ← Main game screen + all game logic
  widgets/
    tile_widget.dart          ← Individual tile with animations

assets/
  images/
    couple.jpg                ← ⭐ ADD YOUR PHOTO HERE
  audio/
    win.mp3                   ← Optional: victory sound
```

---

## 🚀 Setup & Run

### 1. Prerequisites
- Flutter SDK ≥ 3.0.0 installed
- Android Studio / Xcode configured
- A device or emulator running

### 2. Install dependencies
```bash
flutter pub get
```

### 3. ⭐ Add your romantic photo
Place your photo at:
```
assets/images/couple.jpg
```
The image will be auto-cropped to a square and split into tiles.
> Tip: Use a high-res square photo (at least 600×600px) for best quality.

### 4. (Optional) Add win sound
Place an MP3 at:
```
assets/audio/win.mp3
```
Royalty-free romantic music works great. The app works without it too.

### 5. Run the app
```bash
flutter run
```

---

## 🎮 How to Play

1. App opens → tap **"Use Sample Image"** or **"Pick from Gallery"**
2. Tiles shuffle automatically (guaranteed solvable!)
3. **Tap any tile** adjacent to the empty space to slide it
4. Reconstruct the original photo
5. 🎉 Confetti + win dialog appears when solved!

---

## 🛠 Dependencies

| Package | Purpose |
|---|---|
| `image_picker` | Gallery photo selection |
| `confetti` | Celebration animation |
| `audioplayers` | Win sound effect |
| `image` | Image processing |
| `path_provider` | File system access |

---

## 🔧 Configuration

### Change grid size in code
The default is 3×3. In-app you can switch between 3×3 and 4×4 via the grid button.

### Customize the win message
In `puzzle_screen.dart`, find the `_WinDialog` widget and edit the quote text:
```dart
const Text(
  '💕 Your custom message here 💕',
  ...
),
```

### Change the romantic background gradient
In `puzzle_screen.dart`, find the `BoxDecoration` in `build()`:
```dart
gradient: const LinearGradient(
  colors: [
    Color(0xFF1A0533),  // ← dark purple
    Color(0xFFB5245C),  // ← pink
  ],
),
```

---

## 📱 Platform Notes

### Android
- Permissions for gallery access are declared in `AndroidManifest.xml`
- Tested on Android 10+

### iOS  
- Photo library usage description in `Info.plist`
- Tested on iOS 14+

---

## 💡 Game Logic

### Solvability
The puzzle uses **random walk shuffling** — starting from a solved state, it performs 500 random valid moves. This guarantees the puzzle is always solvable (any state reachable by valid moves is solvable).

### Win Detection
```dart
bool isSolved = tiles.every((tile) => tile.currentIndex == tile.correctIndex);
```

### Movement Rule
A tile can move only if it is directly adjacent (up/down/left/right) to the empty tile.

---

## 🎨 Customization Ideas

- Add your partner's name to the header
- Change confetti colors to match your photo theme  
- Add a high-score / best time tracker using `shared_preferences`
- Add a "5×5 Expert" difficulty level
- Enable camera capture (not just gallery)

---

Made with 💕 — for the ones you love.
