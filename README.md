# VideoFrameX Desktop

Professional cross-platform Flutter desktop application for extracting full-resolution frames from local video files with native FFmpeg.

## Features

- Local-only processing with `ffmpeg` and `ffprobe`
- Drag-and-drop and browse-based video import
- MP4, MOV, AVI, MKV, WEBM, and M4V validation with a 5 GB limit
- Automatic metadata inspection for duration, resolution, FPS, bitrate, codec, and format
- FPS presets plus decimal custom FPS
- PNG, JPG, and WEBP frame output
- Optional `HH:MM:SS` start/end extraction range
- Output folder persistence
- Frame count and disk usage estimation
- Live progress, elapsed/remaining time, frame count, output size, and processing speed
- Pause, resume, and cancel controls where supported by the host OS
- Lazy frame gallery with preview, save, and delete actions
- ZIP export for generated frames
- Batch queue status view
- Local extraction history
- Settings for default FPS, format, output folder, theme, thumbnail size, and concurrent task preference
- Light, dark, and system theme modes

## Runtime Prerequisite

Install FFmpeg so both commands are available in `PATH`:

```sh
ffmpeg -version
ffprobe -version
```

On this macOS machine they are available at:

```sh
/opt/homebrew/bin/ffmpeg
/opt/homebrew/bin/ffprobe
```

## Development

```sh
flutter pub get
flutter run -d macos
```

## Verification

```sh
flutter analyze
flutter test
flutter build macos
```

The latest verified macOS artifact is:

```text
build/macos/Build/Products/Release/VideoFrameX Desktop.app
```

## Cross-Platform Builds

Run the build command on each target OS:

```sh
flutter build macos
flutter build windows
flutter build linux
```

Packaging into `.dmg` or `.AppImage` should be done with the platform packaging tool of choice after the Flutter release build is generated.
