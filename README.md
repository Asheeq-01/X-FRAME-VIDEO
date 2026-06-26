# 🎬 VideoFrameX Desktop

> A professional cross-platform desktop application built with **Flutter** and **FFmpeg** for extracting high-quality image frames from videos while preserving the original resolution.

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Windows%20%7C%20Linux-success)
![License](https://img.shields.io/badge/License-MIT-green)

---

## 📖 Overview

VideoFrameX Desktop is a native desktop application that converts videos into image frames using the power of **FFmpeg**.

Unlike browser-based tools, VideoFrameX runs entirely on your computer, allowing you to process large video files quickly while maintaining the original image quality.

Perfect for:

* 🎥 Video Editors
* 📸 Photographers
* 🎬 Content Creators
* 🎮 Game Developers
* 🎓 Researchers
* 🧠 AI / Machine Learning Dataset Generation

---

# ✨ Features

### 📁 Video Upload

* Drag & Drop support
* File Picker support
* Supports:

  * MP4
  * MOV
  * AVI
  * MKV
  * WEBM
  * M4V

---

### 📊 Video Metadata

Automatically displays:

* File Name
* File Size
* Duration
* Resolution
* Frame Rate (FPS)
* Codec
* Format
* Bitrate

---

### ⚙️ Extraction Settings

Choose:

* 1 FPS
* 2 FPS
* 5 FPS
* 10 FPS
* 15 FPS
* 30 FPS
* 60 FPS
* Custom FPS

Output formats:

* PNG
* JPG
* WEBP

---

### 🎯 Time Range Extraction

Extract frames from:

* Entire video
* Selected time range

Example:

00:01:00 → 00:02:30

---

### 🖼 Original Resolution Preservation

Frames are extracted without resizing.

Example:

Video

3840 × 2160

↓

Output

3840 × 2160

---

### 📈 Live Progress Tracking

Displays:

* Progress Bar
* Percentage
* Frames Extracted
* Processing Speed
* Elapsed Time
* Remaining Time

---

### 🖼 Frame Gallery

* Thumbnail Preview
* Responsive Grid
* Full Image Preview
* Zoom & Pan
* Individual Download

---

### 📦 ZIP Export

Export all extracted frames into:

frames.zip

---

### 🌙 Dark Mode

Supports:

* Light Theme
* Dark Theme

Preference is saved automatically.

---

### 📜 Extraction History

Keeps a local history of:

* Video Name
* Extraction Date
* FPS
* Output Folder
* Frame Count

---

# 🚀 Tech Stack

| Technology         | Purpose              |
| ------------------ | -------------------- |
| Flutter            | Desktop UI           |
| Dart               | Programming Language |
| FFmpeg             | Video Processing     |
| FFprobe            | Video Metadata       |
| Riverpod           | State Management     |
| File Picker        | File Selection       |
| Archive            | ZIP Generation       |
| Photo View         | Image Preview        |
| Shared Preferences | Local Settings       |

---

# 📂 Project Structure

```text
lib/
│
├── core/
├── models/
├── services/
├── state/
├── ui/
├── widgets/
├── utils/
└── main.dart
```

---

# 🖥 Supported Platforms

* ✅ macOS
* ✅ Windows
* ✅ Linux

---

# ⚡ Installation

## Clone Repository

```bash
git clone https://github.com/yourusername/videoframex-desktop.git
```

Go into the project:

```bash
cd videoframex-desktop
```

Install dependencies:

```bash
flutter pub get
```

Run:

```bash
flutter run -d macos
```

---

# 📦 Build

macOS

```bash
flutter build macos --release
```

Windows

```bash
flutter build windows --release
```

Linux

```bash
flutter build linux --release
```

---

# 🔧 Requirements

* Flutter 3.x
* Dart SDK
* FFmpeg
* FFprobe

Verify installation:

```bash
ffmpeg -version
```

```bash
ffprobe -version
```

---

# 🎯 Workflow

```text
Upload Video
      │
      ▼
Read Metadata
      │
      ▼
Choose FPS
      │
      ▼
Select Output Folder
      │
      ▼
Extract Frames
      │
      ▼
Preview Images
      │
      ▼
Export ZIP
```

---

# 📸 Example

Input

```
wedding_video.mp4
```

Settings

```
FPS: 2
Format: PNG
```

Output

```
frame_000001.png
frame_000002.png
frame_000003.png
...
```

---

# 📈 Performance

Designed to process:

* Large video files
* 4K videos
* Thousands of frames

Uses:

* Native FFmpeg
* Background Processing
* Lazy Loading
* Efficient Memory Management

---

# 📌 Future Improvements

* Batch Video Processing
* Scene Detection
* Contact Sheet Generator
* GIF Creator
* Video Compression
* Hardware Acceleration
* GPU Encoding Support
* AI-Based Frame Selection

---

# 🤝 Contributing

Contributions are welcome.

1. Fork the repository
2. Create a new branch
3. Commit your changes
4. Open a Pull Request

---

# 📄 License

This project is licensed under the MIT License.

---

# 👨‍💻 Author

**Asheeq Abdul**

Flutter Developer | Python Full Stack Developer

---

⭐ If you found this project useful, consider giving it a star on GitHub.
