// lib/services/mediapipe_service.dart
//
// Bridges the native Android FaceLandmarkDetector to Flutter.
// Connects to the MethodChannel to init/dispose the native detector,
// and subscribes to the EventChannel to receive landmark data per frame.

import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import '../models/models.dart';
import 'package:flutter/widgets.dart';

// â”€â”€ Landmark data model â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class ToothLandmarkData {
  /// True when a face was detected in the frame
  final bool faceDetected;

  /// Normalized [0..1] coordinates of the bounding box around the visible tooth region
  final double toothBboxX;
  final double toothBboxY;
  final double toothBboxW;
  final double toothBboxH;

  /// Lip corner positions (normalized)
  final double lipLeftX;
  final double lipLeftY;
  final double lipRightX;
  final double lipRightY;

  /// Top of upper lip (normalized Y)
  final double upperLipTopY;

  /// Bottom of lower lip (normalized Y)
  final double lowerLipBottomY;

  /// Upper tooth polygon: parallel lists of normalized X/Y/Z coordinates
  final List<double> upperToothX;
  final List<double> upperToothY;
  final List<double> upperToothZ;

  /// Lower tooth polygon: parallel lists of normalized X/Y/Z coordinates
  final List<double> lowerToothX;
  final List<double> lowerToothY;
  final List<double> lowerToothZ;

  /// Outer lip contours used for mouth opening and occlusion
  final List<double> upperLipOuterX;
  final List<double> upperLipOuterY;
  final List<double> lowerLipOuterX;
  final List<double> lowerLipOuterY;

  /// Optional: on-device per-tooth detections/count (Android native)
  final ToothScanResult? onDeviceToothScan;

  /// Actual frame size (pixels) MediaPipe processed for these landmarks.
  final int frameWidth;
  final int frameHeight;

  const ToothLandmarkData({
    required this.faceDetected,
    this.toothBboxX    = 0,
    this.toothBboxY    = 0,
    this.toothBboxW    = 0,
    this.toothBboxH    = 0,
    this.lipLeftX      = 0,
    this.lipLeftY      = 0,
    this.lipRightX     = 0,
    this.lipRightY     = 0,
    this.upperLipTopY  = 0,
    this.lowerLipBottomY = 0,
    this.upperToothX   = const [],
    this.upperToothY   = const [],
    this.upperToothZ   = const [],
    this.lowerToothX   = const [],
    this.lowerToothY   = const [],
    this.lowerToothZ   = const [],
    this.upperLipOuterX = const [],
    this.upperLipOuterY = const [],
    this.lowerLipOuterX = const [],
    this.lowerLipOuterY = const [],
    this.onDeviceToothScan,
    this.frameWidth = 0,
    this.frameHeight = 0,
  });

  static ToothLandmarkData noFace() =>
      const ToothLandmarkData(faceDetected: false);

  factory ToothLandmarkData.fromMap(Map<dynamic, dynamic> m) {
    if (m['faceDetected'] != true) return ToothLandmarkData.noFace();

    List<double> toDoubleList(dynamic raw) {
      if (raw == null) return [];
      return (raw as List).map((v) => (v as num).toDouble()).toList();
    }

    ToothScanResult? parseToothScan(dynamic raw) {
      if (raw is Map) {
        try {
          return ToothScanResult.fromMap(raw);
        } catch (_) {
          return null;
        }
      }
      return null;
    }

    return ToothLandmarkData(
      faceDetected:      true,
      toothBboxX:        (m['toothBboxX'] as num?)?.toDouble() ?? 0,
      toothBboxY:        (m['toothBboxY'] as num?)?.toDouble() ?? 0,
      toothBboxW:        (m['toothBboxW'] as num?)?.toDouble() ?? 0,
      toothBboxH:        (m['toothBboxH'] as num?)?.toDouble() ?? 0,
      lipLeftX:          (m['lipLeftX']   as num?)?.toDouble() ?? 0,
      lipLeftY:          (m['lipLeftY']   as num?)?.toDouble() ?? 0,
      lipRightX:         (m['lipRightX']  as num?)?.toDouble() ?? 0,
      lipRightY:         (m['lipRightY']  as num?)?.toDouble() ?? 0,
      upperLipTopY:      (m['upperLipTopY']     as num?)?.toDouble() ?? 0,
      lowerLipBottomY:   (m['lowerLipBottomY']  as num?)?.toDouble() ?? 0,
      upperToothX:       toDoubleList(m['upperToothX']),
      upperToothY:       toDoubleList(m['upperToothY']),
      upperToothZ:       toDoubleList(m['upperToothZ']),
      lowerToothX:       toDoubleList(m['lowerToothX']),
      lowerToothY:       toDoubleList(m['lowerToothY']),
      lowerToothZ:       toDoubleList(m['lowerToothZ']),
      upperLipOuterX:    toDoubleList(m['upperLipOuterX']),
      upperLipOuterY:    toDoubleList(m['upperLipOuterY']),
      lowerLipOuterX:    toDoubleList(m['lowerLipOuterX']),
      lowerLipOuterY:    toDoubleList(m['lowerLipOuterY']),
      onDeviceToothScan: parseToothScan(m['onDeviceToothScan']),
      frameWidth:        (m['frameWidth'] as num?)?.toInt() ?? 0,
      frameHeight:       (m['frameHeight'] as num?)?.toInt() ?? 0,
    );
  }

  /// Pixel coordinates of the tooth bounding box given screen dimensions
  Rect toPixelRect(double screenW, double screenH) {
    return Rect.fromLTWH(
      toothBboxX * screenW,
      toothBboxY * screenH,
      toothBboxW * screenW,
      toothBboxH * screenH,
    );
  }

  /// Convert upper tooth polygon to pixel Offset list
  List<Offset> upperToothPixels(double w, double h) {
    final pts = <Offset>[];
    for (int i = 0; i < upperToothX.length && i < upperToothY.length; i++) {
      pts.add(Offset(upperToothX[i] * w, upperToothY[i] * h));
    }
    return pts;
  }

  /// Convert lower tooth polygon to pixel Offset list
  List<Offset> lowerToothPixels(double w, double h) {
    final pts = <Offset>[];
    for (int i = 0; i < lowerToothX.length && i < lowerToothY.length; i++) {
      pts.add(Offset(lowerToothX[i] * w, lowerToothY[i] * h));
    }
    return pts;
  }

  List<double> get upperToothDepths => upperToothZ;
  List<double> get lowerToothDepths => lowerToothZ;

  List<Offset> upperLipOuterPixels(double w, double h) {
    final pts = <Offset>[];
    for (int i = 0; i < upperLipOuterX.length && i < upperLipOuterY.length; i++) {
      pts.add(Offset(upperLipOuterX[i] * w, upperLipOuterY[i] * h));
    }
    return pts;
  }

  List<Offset> lowerLipOuterPixels(double w, double h) {
    final pts = <Offset>[];
    for (int i = 0; i < lowerLipOuterX.length && i < lowerLipOuterY.length; i++) {
      pts.add(Offset(lowerLipOuterX[i] * w, lowerLipOuterY[i] * h));
    }
    return pts;
  }

  /// Convert normalized points to pixels using BoxFit.cover mapping.
  /// This matches how camera preview is typically scaled to fill the screen.
  List<Offset> _pointsCoverFit(List<double> xs, List<double> ys, Size viewSize, Size imageSize) {
    final pts = <Offset>[];
    if (xs.isEmpty || ys.isEmpty) return pts;
    final fitted = applyBoxFit(BoxFit.cover, imageSize, viewSize);
    final scaleX = fitted.destination.width / fitted.source.width;
    final scaleY = fitted.destination.height / fitted.source.height;
    final dstW = imageSize.width * scaleX;
    final dstH = imageSize.height * scaleY;
    final dx = (viewSize.width - dstW) / 2.0;
    final dy = (viewSize.height - dstH) / 2.0;

    for (int i = 0; i < xs.length && i < ys.length; i++) {
      final px = dx + xs[i] * dstW;
      final py = dy + ys[i] * dstH;
      pts.add(Offset(px, py));
    }
    return pts;
  }

  List<Offset> upperToothPixelsCoverFit(Size viewSize, Size imageSize) =>
      _pointsCoverFit(upperToothX, upperToothY, viewSize, imageSize);

  List<Offset> lowerToothPixelsCoverFit(Size viewSize, Size imageSize) =>
      _pointsCoverFit(lowerToothX, lowerToothY, viewSize, imageSize);

  List<Offset> upperLipOuterPixelsCoverFit(Size viewSize, Size imageSize) =>
      _pointsCoverFit(upperLipOuterX, upperLipOuterY, viewSize, imageSize);

  List<Offset> lowerLipOuterPixelsCoverFit(Size viewSize, Size imageSize) =>
      _pointsCoverFit(lowerLipOuterX, lowerLipOuterY, viewSize, imageSize);
}

// â”€â”€ MediaPipe Service â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class MediaPipeService {
  static const MethodChannel _method =
      MethodChannel('com.dentalogic/ar_control');
  static const EventChannel _events =
      EventChannel('com.dentalogic/ar_landmarks');

  StreamSubscription? _subscription;
  final StreamController<ToothLandmarkData> _controller =
      StreamController<ToothLandmarkData>.broadcast();

  Stream<ToothLandmarkData> get landmarkStream => _controller.stream;

  bool _initialized = false;
  bool get isInitialized => _initialized;

  /// Initialize the native MediaPipe detector.
  /// Returns true if the model loaded successfully.
  /// Returns false if the .task model file is not yet in assets/models/.
  Future<bool> initialize() async {
    try {
      final result = await _method.invokeMethod<bool>('initialize');
      _initialized = result == true;
      if (_initialized) _startListening();
      return _initialized;
    } on PlatformException catch (e) {
      _initialized = false;
      return false;
    }
  }

  void _startListening() {
    _subscription?.cancel();
    _subscription = _events.receiveBroadcastStream().listen(
      (data) {
        if (data is Map) {
          _controller.add(ToothLandmarkData.fromMap(data));
        }
      },
      onError: (err) {
        _controller.addError(err);
      },
    );
  }

  Future<void> processCameraImage(
    CameraImage image, {
    required int rotationDegrees,
    required bool isFrontCamera,
  }) async {
    if (!_initialized) return;

    final bytes = _cameraImageToNv21(image);
    if (bytes == null) return;

    try {
      await _method.invokeMethod('processFrame', {
        'bytes': bytes,
        'width': image.width,
        'height': image.height,
        'rotation': rotationDegrees,
        'isFrontCamera': isFrontCamera,
      });
    } catch (_) {}
  }

  Uint8List? _cameraImageToNv21(CameraImage image) {
    if (image.planes.length != 3) return null;

    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final out = Uint8List(width * height + (width * height ~/ 2));

    var offset = 0;

    for (var row = 0; row < height; row++) {
      final rowStart = row * yPlane.bytesPerRow;
      out.setRange(offset, offset + width, yPlane.bytes, rowStart);
      offset += width;
    }

    final uvWidth = width ~/ 2;
    final uvHeight = height ~/ 2;
    final uPixelStride = uPlane.bytesPerPixel ?? 1;
    final vPixelStride = vPlane.bytesPerPixel ?? 1;

    for (var row = 0; row < uvHeight; row++) {
      final uRowStart = row * uPlane.bytesPerRow;
      final vRowStart = row * vPlane.bytesPerRow;
      for (var col = 0; col < uvWidth; col++) {
        out[offset++] = vPlane.bytes[vRowStart + col * vPixelStride];
        out[offset++] = uPlane.bytes[uRowStart + col * uPixelStride];
      }
    }

    return out;
  }

  Future<void> dispose() async {
    _subscription?.cancel();
    _subscription = null;
    try {
      await _method.invokeMethod('dispose');
    } catch (_) {}
    _initialized = false;
  }

  void close() {
    _controller.close();
  }
}

