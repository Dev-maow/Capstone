// lib/screens/ar_screen.dart
//
// Production AR Smile Previewer
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// REAL architecture:
//   1. Flutter camera package feeds frames to native Android via MethodChannel
//   2. Native MediaPipe FaceLandmarker detects 478 face landmarks per frame
//   3. Native extracts tooth-region landmark coordinates and sends via EventChannel
//   4. Flutter receives normalized coordinates and paints overlays anchored
//      to the ACTUAL detected tooth positions â€” not fixed screen positions
//
// Requirements:
//   â€¢ Download face_landmarker.task from MediaPipe and place in assets/models/
//   â€¢ URL: https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/1/face_landmarker.task
//   â€¢ AndroidManifest.xml must have CAMERA permission (see android/app/src/main/AndroidManifest.xml)

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/mediapipe_service.dart';
import '../services/tooth_scan_service.dart';
import '../utils/app_data.dart';
import '../utils/theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class ArScreen extends StatefulWidget {
  const ArScreen({super.key});
  @override
  State<ArScreen> createState() => _ArScreenState();
}

class _ArScreenState extends State<ArScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {

  // â”€â”€ Camera â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  CameraController? _cam;
  List<CameraDescription> _cameras = [];
  bool _camActive   = false;
  bool _isFront     = true;
  bool _initializing = false;
  String? _camError;

  // â”€â”€ MediaPipe â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  final MediaPipeService _mp = MediaPipeService();
  ToothLandmarkData _landmarks = ToothLandmarkData.noFace();
  ToothLandmarkData _smoothedLandmarks = ToothLandmarkData.noFace();
  bool _mpReady = false;

  // â”€â”€ AR state â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  // We keep a repaint key around the full camera + overlay stack
  final GlobalKey _repaintKey = GlobalKey();
  Uint8List? _beforeBytes;
  Uint8List? _afterBytes;

  final ToothScanService _toothScan = ToothScanService();
  bool _streamingFrames = false;
  bool _sendingFrame = false;
  bool _runningRealScan = false;
  int _frameCount = 0;
  DateTime? _lastBackendToothScan;

  // â”€â”€ Animation for "scanning" effect â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  late AnimationController _scanCtrl;
  late Animation<double>   _scanAnim;
  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _scanCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
    _scanAnim = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);

    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _initMediaPipe();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _cam?.dispose();
    _mp.dispose();
    _mp.close();
    _toothScan.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) _cam?.dispose();
    else if (state == AppLifecycleState.resumed && _camActive) _startCamera();
  }

  // â”€â”€ MediaPipe init â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _initMediaPipe() async {
    final ready = await _mp.initialize();
    if (mounted) setState(() => _mpReady = ready);
    if (ready) {
      _mp.landmarkStream.listen((data) {
        if (!mounted) return;
        final smoothed = _smoothLandmarks(_smoothedLandmarks, data);
        setState(() {
          _landmarks = data;
          _smoothedLandmarks = smoothed;
        });
      });
    }
  }

  ToothLandmarkData _smoothLandmarks(ToothLandmarkData prev, ToothLandmarkData next) {
    // If no face, reset immediately.
    if (!next.faceDetected) return ToothLandmarkData.noFace();
    if (!prev.faceDetected) return next;

    // Higher alpha = follows faster; lower alpha = smoother/less jitter.
    const alpha = 0.35;

    double lerp(double a, double b) => a + (b - a) * alpha;
    List<double> lerpList(List<double> a, List<double> b) {
      final n = math.min(a.length, b.length);
      if (n == 0) return b;
      return List<double>.generate(n, (i) => lerp(a[i], b[i]));
    }

    return ToothLandmarkData(
      faceDetected: true,
      toothBboxX: lerp(prev.toothBboxX, next.toothBboxX),
      toothBboxY: lerp(prev.toothBboxY, next.toothBboxY),
      toothBboxW: lerp(prev.toothBboxW, next.toothBboxW),
      toothBboxH: lerp(prev.toothBboxH, next.toothBboxH),
      lipLeftX: lerp(prev.lipLeftX, next.lipLeftX),
      lipLeftY: lerp(prev.lipLeftY, next.lipLeftY),
      lipRightX: lerp(prev.lipRightX, next.lipRightX),
      lipRightY: lerp(prev.lipRightY, next.lipRightY),
      upperLipTopY: lerp(prev.upperLipTopY, next.upperLipTopY),
      lowerLipBottomY: lerp(prev.lowerLipBottomY, next.lowerLipBottomY),
      upperToothX: lerpList(prev.upperToothX, next.upperToothX),
      upperToothY: lerpList(prev.upperToothY, next.upperToothY),
      upperToothZ: lerpList(prev.upperToothZ, next.upperToothZ),
      lowerToothX: lerpList(prev.lowerToothX, next.lowerToothX),
      lowerToothY: lerpList(prev.lowerToothY, next.lowerToothY),
      lowerToothZ: lerpList(prev.lowerToothZ, next.lowerToothZ),
      upperLipOuterX: lerpList(prev.upperLipOuterX, next.upperLipOuterX),
      upperLipOuterY: lerpList(prev.upperLipOuterY, next.upperLipOuterY),
      lowerLipOuterX: lerpList(prev.lowerLipOuterX, next.lowerLipOuterX),
      lowerLipOuterY: lerpList(prev.lowerLipOuterY, next.lowerLipOuterY),
      // Keep latest scan result (no smoothing here)
      onDeviceToothScan: next.onDeviceToothScan,
      frameWidth: next.frameWidth,
      frameHeight: next.frameHeight,
    );
  }

  // â”€â”€ Camera â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _startCamera() async {
    setState(() { _initializing = true; _camError = null; });

    final status = await Permission.camera.request();
    if (!status.isGranted) {
      setState(() {
        _camError = 'Camera permission denied.\n\nGo to Settings â†’ Apps â†’ DentaLogic â†’ Permissions â†’ Camera.';
        _initializing = false;
      });
      return;
    }

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() { _camError = 'No cameras found.'; _initializing = false; });
        return;
      }

      final cam = _cameras.firstWhere(
        (c) => _isFront
            ? c.lensDirection == CameraLensDirection.front
            : c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      final ctrl = CameraController(
        cam,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await ctrl.initialize();
      await _startFrameStreaming(ctrl);

      if (!mounted) return;
      setState(() {
        _cam        = ctrl;
        _camActive  = true;
        _initializing = false;
        _camError   = null;
      });
    } catch (e) {
      setState(() {
        _camError = 'Camera error: $e';
        _initializing = false;
      });
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.length < 2) return;
    setState(() { _isFront = !_isFront; });
    if (_cam != null && _cam!.value.isStreamingImages) {
      try {
        await _cam!.stopImageStream();
      } catch (_) {}
    }
    await _cam?.dispose();
    _cam = null;
    _streamingFrames = false;
    _sendingFrame = false;
    await _startCamera();
  }

    Future<void> _stopCamera() async {
    if (_cam != null && _cam!.value.isStreamingImages) {
      try {
        await _cam!.stopImageStream();
      } catch (_) {}
    }
    await _cam?.dispose();
    _streamingFrames = false;
    _sendingFrame = false;
    _runningRealScan = false;
    if (mounted) {
      context.read<AppData>().clearLiveToothScan();
    }
    setState(() {
      _cam = null;
      _camActive = false;
      _camError = null;
      _landmarks = ToothLandmarkData.noFace();
    });
  }

  Future<void> _startFrameStreaming(CameraController controller) async {
    if (!_mpReady || _streamingFrames || controller.value.isStreamingImages) return;

    await controller.startImageStream((image) async {
      if (!_camActive || _sendingFrame) return;
      _frameCount++;
      if (_frameCount.isOdd) return;

      _sendingFrame = true;
      try {
        final rotationDegrees = _computeImageRotationDegrees(controller, isFront: _isFront);
        await _mp.processCameraImage(
          image,
          rotationDegrees: rotationDegrees,
          isFrontCamera: _isFront,
        );

        if (!mounted) return;
        final appData = context.read<AppData>();
        if (appData.realToothScanConfigured) {
          final now = DateTime.now();
          final due = _lastBackendToothScan == null ||
              now.difference(_lastBackendToothScan!) >= const Duration(milliseconds: 2800);
          if (due && !_runningRealScan) {
            final nv21 = _cameraImageToNv21(image);
            if (nv21 != null) {
              final copy = Uint8List(nv21.length)..setRange(0, nv21.length, nv21);
              _lastBackendToothScan = now;
              unawaited(_runBackendToothScanWithNv21(
                copy,
                image.width,
                image.height,
                rotationDegrees,
                appData,
              ));
            }
          }
        }
      } finally {
        _sendingFrame = false;
      }
    });

    _streamingFrames = true;
  }

  int _computeImageRotationDegrees(CameraController controller, {required bool isFront}) {
    // Camera plugin frames are in sensor orientation; we must rotate them into the same
    // upright orientation as the preview. Using sensorOrientation alone is wrong and
    // causes drifting/misalignment (especially on front cam).
    final sensor = controller.description.sensorOrientation;
    final device = controller.value.deviceOrientation;
    int deviceDeg = 0;
    // Avoid enum switch incompatibilities across Flutter/camera versions.
    final d = device.toString();
    if (d.contains('landscapeLeft')) {
      deviceDeg = 90;
    } else if (d.contains('portraitDown')) {
      deviceDeg = 180;
    } else if (d.contains('landscapeRight')) {
      deviceDeg = 270;
    } else {
      deviceDeg = 0; // portraitUp/unknown
    }
    // We are NOT mirroring front camera frames, so use the same rotation logic
    // for both cameras to keep preview + MediaPipe in the same coordinate space.
    return (sensor - deviceDeg + 360) % 360;
  }

  /// Runs [bytes] (NV21 copy) through your PC backend; must not reference [CameraImage] after async gap.
  Future<void> _runBackendToothScanWithNv21(
    Uint8List bytes,
    int width,
    int height,
    int rotationDegrees,
    AppData data,
  ) async {
    if (_runningRealScan) return;
    _runningRealScan = true;
    try {
      data.setToothScanStatus('Scanning teeth from backend...');
      final result = await _toothScan.scanNv21Frame(
        endpoint: data.toothScanEndpoint,
        bytes: bytes,
        width: width,
        height: height,
        rotation: rotationDegrees,
        isFrontCamera: _isFront,
        toothBboxX: _landmarks.toothBboxX,
        toothBboxY: _landmarks.toothBboxY,
        toothBboxW: _landmarks.toothBboxW,
        toothBboxH: _landmarks.toothBboxH,
        lipLeftX: _landmarks.lipLeftX,
        lipRightX: _landmarks.lipRightX,
        upperLipTopY: _landmarks.upperLipTopY,
        lowerLipBottomY: _landmarks.lowerLipBottomY,
      );
      if (!mounted) return;
      if (result == null || result.teeth.length < 4) {
        data.clearLiveToothScan();
        data.setToothScanStatus('Need a clearer smile for real scan');
      } else {
        data.setLiveToothScan(result);
      }
    } catch (_) {
      if (mounted) data.setToothScanStatus('Backend scan unavailable');
    } finally {
      _runningRealScan = false;
    }
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

  // â”€â”€ Snapshot â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _capture({required bool isBefore}) async {
    try {
      final boundary = _repaintKey.currentContext
          ?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final img   = await boundary.toImage(pixelRatio: 2.0);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;

      setState(() {
        if (isBefore) _beforeBytes = bytes.buffer.asUint8List();
        else          _afterBytes  = bytes.buffer.asUint8List();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isBefore ? 'ðŸ“· Before captured' : 'âœ¨ After captured'),
          backgroundColor: const Color(0xFF1A1A2A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      debugPrint('Snapshot error: $e');
    }
  }

  int? _displayedToothCount(AppData data) {
    final scan = data.liveToothScan;
    if (scan == null || !scan.hasDetections) return null;
    return scan.teeth.length;
  }

  // â”€â”€ Build â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final isActive = _camActive && _cam != null && _cam!.value.isInitialized;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF08090E),
      body: Stack(
        fit: StackFit.expand,
        children: [

          // â”€â”€ CAMERA + OVERLAY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          RepaintBoundary(
            key: _repaintKey,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview
                if (isActive)
                  _CameraWithOverlay(
                    controller: _cam!,
                    isFront: _isFront,
                    rotationDegrees: _computeImageRotationDegrees(_cam!, isFront: _isFront),
                    overlayBuilder: (previewSize) => GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onPanDown: (details) {
                        if (data.currentArMode != ArMode.whitening) return;
                        if (!data.whiteningCompareEnabled) return;
                        data.setWhiteningCompareSplit(details.localPosition.dx / previewSize.width);
                      },
                      onPanUpdate: (details) {
                        if (data.currentArMode != ArMode.whitening) return;
                        if (!data.whiteningCompareEnabled) return;
                        data.setWhiteningCompareSplit(details.localPosition.dx / previewSize.width);
                      },
                      child: CustomPaint(
                        size: previewSize,
                        painter: _TeethOverlayPainter(
                          data: data,
                          landmarks: _smoothedLandmarks,
                          scanResult: data.liveToothScan,
                          scanAnim: _scanAnim,
                          imageSize: (_landmarks.frameWidth > 0 && _landmarks.frameHeight > 0)
                              ? Size(_landmarks.frameWidth.toDouble(), _landmarks.frameHeight.toDouble())
                              : previewSize,
                        ),
                      ),
                    ),
                  )
                else
                  _IdleView(
                    error: _camError,
                    loading: _initializing,
                    mpReady: _mpReady,
                    onStart: _startCamera,
                  ),

              ],
            ),
          ),

          // â”€â”€ TOP HUD â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            top: 0, left: 0, right: 0,
            child: _TopHud(
              isActive:  isActive,
              isFront:   _isFront,
              mpReady:   _mpReady,
              faceFound: _landmarks.faceDetected,
              mode:      data.currentArMode,
              pulseAnim: _pulseAnim,
              onDeviceToothCount: _displayedToothCount(data),
              hasMultiCam: _cameras.length > 1,
              onFlip:    _flipCamera,
              onCaptureBefore: () => _capture(isBefore: true),
              onCaptureAfter:  () => _capture(isBefore: false),
            ),
          ),

          // â”€â”€ BOTTOM CONTROL PANEL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _BottomPanel(
              data:         data,
              isActive:     isActive,
              loading:      _initializing,
              beforeBytes:  _beforeBytes,
              afterBytes:   _afterBytes,
              onStart:      _startCamera,
              onStop:       _stopCamera,
              onSave: () {
                data.saveArSession();
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('âœ… Saved to ${data.selectedPatient.name}\'s record'),
                  backgroundColor: const Color(0xFF1A1A2A),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
              onPatientChange: () => _showPatientPicker(context, data),
            ),
          ),
        ],
      ),
    );
  }

  void _showPatientPicker(BuildContext context, AppData data) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF12131C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
              child: Row(children: [
                Text('Select Patient',
                    style: GoogleFonts.dmSans(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white)),
              ]),
            ),
            ...data.patients.asMap().entries.map((e) => ListTile(
              leading: PatientAvatar(patient: e.value, size: 40),
              title: Text(e.value.name,
                  style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600, color: Colors.white)),
              subtitle: Text(e.value.procedure,
                  style: GoogleFonts.dmSans(color: Colors.white54)),
              trailing: e.key == data.selectedPatientIndex
                  ? const Icon(Icons.check_circle_rounded,
                      color: AppTheme.secondary)
                  : null,
              onTap: () {
                data.setSelectedPatient(e.key);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TEETH OVERLAY PAINTER
// Paints AR overlays anchored to the MediaPipe landmark data.
// When faceDetected == false, shows nothing.
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TeethOverlayPainter extends CustomPainter {
  final AppData data;
  final ToothLandmarkData landmarks;
  final ToothScanResult? scanResult;
  final Animation<double> scanAnim;
  final Size imageSize;

  const _TeethOverlayPainter({
    required this.data,
    required this.landmarks,
    required this.scanResult,
    required this.scanAnim,
    required this.imageSize,
  }) : super(repaint: scanAnim);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.currentArMode == ArMode.none || !landmarks.faceDetected) return;

    final upperPts = landmarks.upperToothPixelsCoverFit(size, imageSize);
    final lowerPts = landmarks.lowerToothPixelsCoverFit(size, imageSize);
    if (upperPts.length < 4 && lowerPts.length < 4) return;

    switch (data.currentArMode) {
      case ArMode.whitening:
        if (data.whiteningCompareEnabled) {
          _paintWhiteningCompare(canvas, size, upperPts, lowerPts);
        } else {
          _paintFittedWhitening(canvas, size, upperPts, lowerPts);
        }
        break;
      case ArMode.braces:
        _paintBraces(canvas, size, upperPts, landmarks.upperToothDepths, scanResult);
        break;
      case ArMode.veneer:
        _paintVeneers(canvas, size, upperPts, lowerPts, scanResult);
        break;
      default:
        break;
    }
  }

  void _paintBraces(
    Canvas canvas,
    Size size,
    List<Offset> upperPts,
    List<double> upperDepths,
    ToothScanResult? scanResult,
  ) {
    // Prefer per-tooth detections if present (aligns to real teeth).
    if (scanResult != null && scanResult.teeth.isNotEmpty) {
      final teeth = _validatedTeethForJaw(
        ToothJaw.upper,
        jawPts: upperPts,
        size: size,
      );
      if (teeth.length >= 3) {
        final mouthPath = _mouthWindowPath(size);
        final toothPath = _toothMaskPath(size) ?? _closedPath(upperPts);
        canvas.save();
        if (mouthPath != null) canvas.clipPath(mouthPath);
        canvas.clipPath(toothPath);

        final centers = teeth
            .map((t) => t.overlayCentroid(size, imageSize, scanResult!))
            .toList();
        final wirePath = _smoothPath(centers);
        final wireBounds = _bounds(centers);

        // Wire shadow
        canvas.drawPath(
          wirePath,
          Paint()
            ..color = Colors.black.withOpacity(0.16)
            ..strokeWidth = 7
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        // Wire
        canvas.drawPath(
          wirePath,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF718096).withOpacity(0.96),
                const Color(0xFFF8FBFF).withOpacity(0.98),
                const Color(0xFF72839B).withOpacity(0.94),
              ],
            ).createShader(wireBounds.inflate(12))
            ..strokeWidth = 3.0
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );

        for (int i = 0; i < teeth.length; i++) {
          final t = teeth[i];
          final center = centers[i];

          final pts = t.overlayPolygon(size, imageSize, scanResult!);
          if (pts.length < 3) continue;
          final b = _bounds(pts);
          final width = (b.width * 0.48).clamp(10.0, 20.0);
          final height = (b.height * 0.26).clamp(8.0, 16.0);

          final angle = _blendBraceTangent(i, centers, pts);

          final zHint = 1.0 - ((i / math.max(1, teeth.length - 1)) - 0.5).abs() * 1.25;
          final scale = (0.92 + zHint.clamp(0.0, 1.0) * 0.18);
          final ao = 0.08 + (1.0 - zHint.clamp(0.0, 1.0)) * 0.10;
          final spec = 0.16 + zHint.clamp(0.0, 1.0) * 0.22;

          canvas.save();
          canvas.translate(center.dx, center.dy);
          canvas.rotate(angle);
          canvas.scale(scale, scale);
          canvas.save();
          canvas.clipPath(
            Path()
              ..addPolygon(
                pts.map((p) => Offset(p.dx - center.dx, p.dy - center.dy)).toList(),
                true,
              ),
          );

          final frontRect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
          final sideRect = Rect.fromLTWH(
            width * 0.26,
            -height * 0.46,
            width * 0.18,
            height * 0.92,
          );

          canvas.drawShadow(
            Path()..addRRect(RRect.fromRectAndRadius(frontRect, Radius.circular(width * 0.18))),
            Colors.black.withOpacity(0.20),
            2.4,
            false,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(frontRect.inflate(0.6), Radius.circular(width * 0.20)),
            Paint()
              ..color = Colors.black.withOpacity(ao)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
          );
          canvas.drawPath(
            Path()
              ..moveTo(frontRect.right, frontRect.top)
              ..lineTo(sideRect.right, sideRect.top + height * 0.08)
              ..lineTo(sideRect.right, sideRect.bottom - height * 0.08)
              ..lineTo(frontRect.right, frontRect.bottom)
              ..close(),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF8E9CAF).withOpacity(0.92),
                  const Color(0xFF677587).withOpacity(0.98),
                ],
              ).createShader(sideRect),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(frontRect, Radius.circular(width * 0.18)),
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.98),
                  const Color(0xFFDDE6EF).withOpacity(0.98),
                  const Color(0xFF90A0B2).withOpacity(0.96),
                ],
              ).createShader(frontRect),
          );

          final slotRect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: width * 0.78, height: height * 0.18),
            const Radius.circular(2.2),
          );
          canvas.drawRRect(slotRect, Paint()..color = const Color(0xFF4E5D70).withOpacity(0.96));
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(-width * 0.34, 0),
                width: width * 0.16,
                height: height * 0.62,
              ),
              Radius.circular(width * 0.08),
            ),
            Paint()..color = const Color(0xFFDCE4EC).withOpacity(0.92),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(width * 0.34, 0),
                width: width * 0.16,
                height: height * 0.62,
              ),
              Radius.circular(width * 0.08),
            ),
            Paint()..color = const Color(0xFFDCE4EC).withOpacity(0.92),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(-width * 0.42, -height * 0.44, width * 0.84, height * 0.40),
              Radius.circular(width * 0.18),
            ),
            Paint()
              ..blendMode = BlendMode.screen
              ..shader = LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(spec),
                  Colors.white.withOpacity(0.0),
                ],
              ).createShader(frontRect),
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(frontRect, Radius.circular(width * 0.18)),
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8
              ..color = const Color(0xFF59697B).withOpacity(0.56),
          );
          canvas.restore();
          canvas.restore();
        }

        canvas.restore();
        _paintLipOcclusion(canvas, size);
        return;
      }
    }

    // Fallback: old landmark-only fit
    _paintFittedBraces(canvas, size, upperPts, upperDepths);
  }

  void _paintVeneers(
    Canvas canvas,
    Size size,
    List<Offset> upperPts,
    List<Offset> lowerPts,
    ToothScanResult? scanResult,
  ) {
    // Prefer per-tooth detections for alignment.
    if (scanResult != null && scanResult.teeth.isNotEmpty) {
      final opacity = data.overlayOpacity;
      final mouthPath = _mouthWindowPath(size);

      void paintJaw(ToothJaw jaw, List<Offset> jawPts) {
        final teeth = _validatedTeethForJaw(jaw, jawPts: jawPts, size: size);
        if (teeth.length < 2 || jawPts.length < 4) return;
        final clip = _closedPath(jawPts);
        canvas.save();
        if (mouthPath != null) canvas.clipPath(mouthPath);
        canvas.clipPath(clip);

        final centersJaw =
            teeth.map((t) => t.overlayCentroid(size, imageSize, scanResult!)).toList();
        for (int i = 0; i < teeth.length; i++) {
          final t = teeth[i];
          final pts = t.overlayPolygon(size, imageSize, scanResult!);
          if (pts.length < 3) continue;
          final b = _bounds(pts);
          final center = centersJaw[i];
          final angle = _blendBraceTangent(i, centersJaw, pts);

          final w = (b.width * 0.62).clamp(12.0, 22.0);
          final h = (b.height * 0.70).clamp(14.0, 28.0);

          canvas.save();
          canvas.translate(center.dx, center.dy + h * 0.10);
          canvas.rotate(angle);
          canvas.save();
          canvas.clipPath(
            Path()
              ..addPolygon(
                pts.map((p) => Offset(p.dx - center.dx, p.dy - (center.dy + h * 0.10))).toList(),
                true,
              ),
          );

          final rect = Rect.fromCenter(center: Offset.zero, width: w * 1.06, height: h * 1.20);
          final rr = RRect.fromRectAndRadius(rect, Radius.circular(w * 0.24));
          canvas.drawShadow(Path()..addRRect(rr), Colors.black.withOpacity(0.10), 2.0, false);
          canvas.drawRRect(
            rr,
            Paint()
              ..shader = LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFFFFEFC).withOpacity(opacity * 0.78),
                  const Color(0xFFF6F4EE).withOpacity(opacity * 0.86),
                  const Color(0xFFE9DDC9).withOpacity(opacity * 0.54),
                ],
              ).createShader(rect),
          );
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset(0, -h * 0.22),
              width: w * 0.60,
              height: h * 0.16,
            ),
            Paint()..color = Colors.white.withOpacity(opacity * 0.22),
          );
          canvas.restore();
          canvas.restore();
        }
        canvas.restore();
      }

      paintJaw(ToothJaw.upper, upperPts);
      paintJaw(ToothJaw.lower, lowerPts);
      _paintLipOcclusion(canvas, size);
      return;
    }

    // Fallback: old landmark-only fit
    _paintFittedVeneers(canvas, size, upperPts, lowerPts);
  }

  void _paintWhiteningCompare(
    Canvas canvas,
    Size size,
    List<Offset> upperPts,
    List<Offset> lowerPts,
  ) {
    final opacity = data.overlayOpacity;
    final splitX = size.width * data.whiteningCompareSplit;
    final beforeIntensity = data.whiteningCompareFreezeBefore
        ? data.whiteningCompareBeforeIntensity
        : 0.0;
    final afterIntensity = data.whiteningIntensity;

    final toothPath = _toothMaskPath(size) ?? _combinedToothPath(upperPts, lowerPts);
    if (toothPath == null) return;
    final bounds = toothPath.getBounds();

    // BEFORE side
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, splitX, size.height));
    _paintWhiteningLayer(
      canvas,
      size,
      upperPts: upperPts,
      lowerPts: lowerPts,
      toothPath: toothPath,
      bounds: bounds,
      intensity: beforeIntensity,
      opacity: opacity,
    );
    canvas.restore();

    // AFTER side
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(splitX, 0, size.width - splitX, size.height));
    _paintWhiteningLayer(
      canvas,
      size,
      upperPts: upperPts,
      lowerPts: lowerPts,
      toothPath: toothPath,
      bounds: bounds,
      intensity: afterIntensity,
      opacity: opacity,
    );
    canvas.restore();

    // Divider handle
    final handlePaint = Paint()
      ..color = Colors.white.withOpacity(0.70)
      ..strokeWidth = 1.6;
    canvas.drawLine(Offset(splitX, 0), Offset(splitX, size.height), handlePaint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(splitX, size.height * 0.52), width: 22, height: 56),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.black.withOpacity(0.35),
    );
    canvas.drawLine(
      Offset(splitX, size.height * 0.52 - 10),
      Offset(splitX, size.height * 0.52 + 10),
      Paint()
        ..color = Colors.white.withOpacity(0.80)
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintFittedWhitening(
    Canvas canvas,
    Size size,
    List<Offset> upperPts,
    List<Offset> lowerPts,
  ) {
    final opacity = data.overlayOpacity;
    final toothPath = _toothMaskPath(size) ?? _fallbackVisibleToothPath(size, upperPts, lowerPts);
    if (toothPath == null) return;

    final bounds = toothPath.getBounds();
    _paintWhiteningLayer(
      canvas,
      size,
      upperPts: upperPts,
      lowerPts: lowerPts,
      toothPath: toothPath,
      bounds: bounds,
      intensity: data.whiteningIntensity,
      opacity: opacity,
    );
  }

  Path? _toothMaskPath(Size size) {
    if (scanResult == null || scanResult!.teeth.isEmpty) return null;
    final path = Path();
    final upperTeeth = _validatedTeethForJaw(
      ToothJaw.upper,
      jawPts: landmarks.upperToothPixelsCoverFit(size, imageSize),
      size: size,
    );
    final lowerTeeth = _validatedTeethForJaw(
      ToothJaw.lower,
      jawPts: landmarks.lowerToothPixelsCoverFit(size, imageSize),
      size: size,
    );
    for (final tooth in [...upperTeeth, ...lowerTeeth]) {
      final toothPath = _toothPathForDetection(tooth, size);
      if (toothPath != null) {
        path.addPath(toothPath, Offset.zero);
      }
    }
    return path.getBounds().isEmpty ? null : path;
  }

  List<ToothDetection> _validatedTeethForJaw(
    ToothJaw jaw, {
    required List<Offset> jawPts,
    required Size size,
  }) {
    if (scanResult == null || scanResult!.teeth.isEmpty || jawPts.length < 4) {
      return const [];
    }
    final jawPath = _closedPath(jawPts);
    final jawBounds = jawPath.getBounds();
    final jawExpanded = jawBounds.inflate(math.max(12.0, jawBounds.height * 0.28));
    final mouthPath = _mouthWindowPath(size);
    Rect? mouthInflated;
    if (mouthPath != null) {
      mouthInflated = mouthPath.getBounds().inflate(math.max(24.0, size.shortestSide * 0.035));
    }
    final teeth = scanResult!.teethForJawForOverlay(jaw, size, imageSize);
    final strict = <ToothDetection>[];
    final loose = <ToothDetection>[];

    for (final tooth in teeth) {
      final pts = tooth.overlayPolygon(size, imageSize, scanResult!);
      if (pts.length < 3) continue;
      final centroid = tooth.overlayCentroid(size, imageSize, scanResult!);
      final bounds = _bounds(pts);
      if (_toothPathFromPoints(pts) == null) continue;

      final insideJaw = jawPath.contains(centroid);
      final insideExpanded = jawExpanded.contains(centroid);
      final vertexNearJaw = pts.any((p) => jawExpanded.contains(p));
      final overlapsJawRect = bounds.overlaps(jawExpanded);
      final jawOk = insideJaw || insideExpanded || vertexNearJaw || overlapsJawRect;

      final insideMouthCentroid = mouthPath == null || mouthPath.contains(centroid);
      final mouthOk = mouthInflated == null ||
          insideMouthCentroid ||
          mouthInflated.overlaps(bounds);

      final widthOk = bounds.width <= jawExpanded.width * 0.58;
      final heightOk = bounds.height <= jawExpanded.height * 1.05;
      final overlapOk = overlapsJawRect;

      if (jawOk && mouthOk && widthOk && heightOk && overlapOk) {
        strict.add(tooth);
      } else {
        final looseMouth = mouthInflated == null || mouthInflated.overlaps(bounds);
        final looseSize = bounds.width <= jawExpanded.width * 0.72 &&
            bounds.height <= jawExpanded.height * 1.12;
        if (overlapsJawRect && looseMouth && looseSize) {
          loose.add(tooth);
        }
      }
    }

    if (strict.length >= 3 || (jaw == ToothJaw.lower && strict.length >= 2)) {
      return strict;
    }
    if (loose.length >= 3 || (jaw == ToothJaw.lower && loose.length >= 2)) {
      return loose;
    }
    return const [];
  }

  Path? _toothPathForDetection(ToothDetection tooth, Size size) {
    if (scanResult == null) return null;
    final pts = tooth.overlayPolygon(size, imageSize, scanResult!);
    return _toothPathFromPoints(pts);
  }

  Path? _toothPathFromPoints(List<Offset> pts) {
    if (pts.length < 3) return null;
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final pt in pts.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }

  void _paintWhiteningLayer(
    Canvas canvas,
    Size size, {
    required List<Offset> upperPts,
    required List<Offset> lowerPts,
    required Path toothPath,
    required Rect bounds,
    required double intensity,
    required double opacity,
  }) {
    final filterStrength = (0.28 + intensity * 0.42) * opacity;
    final highlightStrength = (0.06 + intensity * 0.10) * opacity;
    final enamelTint = const Color(0xFFF6F7F2);
    final coolTint = const Color(0xFFE7F1FF);

    canvas.save();
    canvas.clipPath(toothPath);
    canvas.saveLayer(bounds.inflate(bounds.height * 0.18), Paint());
    canvas.drawPath(
      toothPath,
      Paint()
        ..blendMode = BlendMode.softLight
        ..color = enamelTint.withOpacity(filterStrength),
    );
    canvas.drawPath(
      toothPath,
      Paint()
        ..blendMode = BlendMode.screen
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(highlightStrength * 0.40),
            enamelTint.withOpacity(highlightStrength),
            coolTint.withOpacity(highlightStrength * 0.45),
          ],
          stops: const [0.0, 0.42, 1.0],
        ).createShader(bounds),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bounds.center.dx, bounds.center.dy - bounds.height * 0.08),
        width: bounds.width * 1.08,
        height: bounds.height * 0.82,
      ),
      Paint()
        ..blendMode = BlendMode.screen
        ..color = Colors.white.withOpacity(0.05 + intensity * 0.05)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, bounds.height * 0.12),
    );

    _paintSeparatorHints(canvas, upperPts, Colors.white.withOpacity(opacity * 0.10));
    _paintSeparatorHints(canvas, lowerPts, Colors.white.withOpacity(opacity * 0.08));
    canvas.restore();
    canvas.restore();

    _paintLipOcclusion(canvas, size);
  }

  void _paintFittedBraces(
    Canvas canvas,
    Size size,
    List<Offset> upperPts,
    List<double> upperDepths,
  ) {
    final samples = _fallbackUpperSamples(size, upperPts, upperDepths);
    if (samples.length < 4) return;
    final toothPath = _bandPathFromSamples(
      samples,
      widthScale: 0.72,
      heightScale: 0.92,
      yOffset: 0.0,
    );
    final mouthPath = _mouthWindowPath(size);

    final centers = samples.map((s) => s.center).toList();
    final wirePath = _smoothPath(centers);
    final wireBounds = _bounds(centers);
    final depthNorm = _normalizeDepths(upperDepths);

    canvas.save();
    if (mouthPath != null) canvas.clipPath(mouthPath);
    canvas.clipPath(toothPath);

    canvas.drawPath(
      wirePath,
      Paint()
        ..color = Colors.black.withOpacity(0.16)
        ..strokeWidth = 4.2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      wirePath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF718096).withOpacity(0.96),
            const Color(0xFFF8FBFF).withOpacity(0.98),
            const Color(0xFF72839B).withOpacity(0.94),
          ],
        ).createShader(wireBounds.inflate(12))
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (int i = 0; i < samples.length; i++) {
      final sample = samples[i];
      final z = depthNorm.isEmpty ? (1 - (i / (samples.length - 1) - 0.5).abs() * 1.25).clamp(0.0, 1.0) : depthNorm[(i / (samples.length - 1) * (depthNorm.length - 1)).round()];
      final scale = 0.92 + z * 0.18;
      final ao = 0.08 + (1.0 - z) * 0.10;
      final spec = 0.16 + z * 0.22;

      canvas.save();
      canvas.translate(sample.center.dx, sample.center.dy);
      canvas.rotate(sample.angle);
      canvas.scale(scale, scale);

      final frontRect = Rect.fromCenter(
        center: const Offset(0, 0),
        width: sample.width * 0.76,
        height: sample.height * 0.58,
      );
      final sideRect = Rect.fromLTWH(
        frontRect.width * 0.42,
        -frontRect.height * 0.46,
        frontRect.width * 0.16,
        frontRect.height * 0.92,
      );

      canvas.drawShadow(
        Path()..addRRect(RRect.fromRectAndRadius(frontRect, Radius.circular(sample.width * 0.18))),
        Colors.black.withOpacity(0.20),
        2.4,
        false,
      );

      // Ambient occlusion (subtle edge darkening) to add depth.
      canvas.drawRRect(
        RRect.fromRectAndRadius(frontRect.inflate(0.6), Radius.circular(sample.width * 0.20)),
        Paint()
          ..color = Colors.black.withOpacity(ao)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0),
      );

      canvas.drawPath(
        Path()
          ..moveTo(frontRect.right, frontRect.top)
          ..lineTo(sideRect.right, sideRect.top + sample.height * 0.08)
          ..lineTo(sideRect.right, sideRect.bottom - sample.height * 0.08)
          ..lineTo(frontRect.right, frontRect.bottom)
          ..close(),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF8E9CAF).withOpacity(0.92),
              const Color(0xFF677587).withOpacity(0.98),
            ],
          ).createShader(sideRect),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(frontRect, Radius.circular(sample.width * 0.18)),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.98),
              const Color(0xFFDDE6EF).withOpacity(0.98),
              const Color(0xFF90A0B2).withOpacity(0.96),
            ],
          ).createShader(frontRect),
      );

      final slotRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: const Offset(0, 0),
          width: frontRect.width * 0.72,
          height: frontRect.height * 0.18,
        ),
        const Radius.circular(2.2),
      );
      canvas.drawRRect(
        slotRect,
        Paint()..color = const Color(0xFF4E5D70).withOpacity(0.96),
      );

      // Specular highlight sweep (stronger on \"nearer\" teeth).
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -sample.width * 0.42,
            -sample.height * 0.44,
            sample.width * 0.84,
            sample.height * 0.40,
          ),
          Radius.circular(sample.width * 0.18),
        ),
        Paint()
          ..blendMode = BlendMode.screen
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(spec),
              Colors.white.withOpacity(0.0),
            ],
          ).createShader(frontRect),
      );

      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(-frontRect.width * 0.04, -frontRect.height * 0.18),
          width: frontRect.width * 0.46,
          height: frontRect.height * 0.24,
        ),
        Paint()..color = Colors.white.withOpacity(0.28),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(-frontRect.width * 0.42, 0),
            width: frontRect.width * 0.18,
            height: frontRect.height * 0.54,
          ),
          Radius.circular(frontRect.width * 0.08),
        ),
        Paint()..color = const Color(0xFFD9E1EA).withOpacity(0.94),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(frontRect.width * 0.42, 0),
            width: frontRect.width * 0.18,
            height: frontRect.height * 0.54,
          ),
          Radius.circular(frontRect.width * 0.08),
        ),
        Paint()..color = const Color(0xFFD9E1EA).withOpacity(0.94),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(frontRect, Radius.circular(sample.width * 0.18)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = const Color(0xFF59697B).withOpacity(0.56),
      );
      canvas.restore();
    }
    canvas.restore();

    _paintLipOcclusion(canvas, size);
  }

  void _paintFittedVeneers(
    Canvas canvas,
    Size size,
    List<Offset> upperPts,
    List<Offset> lowerPts,
  ) {
    final opacity = data.overlayOpacity;
    final upperSamples = _fallbackUpperSamples(size, upperPts, landmarks.upperToothDepths, maxSamples: 8);
    final lowerSamples = _fallbackLowerSamples(size, lowerPts, landmarks.lowerToothDepths, maxSamples: 6);

    void paintShells(List<_ArchSample> samples, List<Offset> jawPts) {
      if (samples.isEmpty || jawPts.length < 4) return;
      final clip = _bandPathFromSamples(
        samples,
        widthScale: 0.88,
        heightScale: 0.96,
        yOffset: 0.02,
      );
      canvas.save();
      canvas.clipPath(clip);
      for (final sample in samples) {
        canvas.save();
        canvas.translate(sample.center.dx, sample.center.dy + sample.height * 0.04);
        canvas.rotate(sample.angle);
        final rect = Rect.fromCenter(
          center: const Offset(0, 0),
          width: sample.width * 0.82,
          height: sample.height * 0.82,
        );
        final rr = RRect.fromRectAndRadius(rect, Radius.circular(sample.width * 0.24));
        canvas.drawShadow(Path()..addRRect(rr), Colors.black.withOpacity(0.10), 2.0, false);
        canvas.drawRRect(
          rr,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFFFFFEFC).withOpacity(opacity * 0.78),
                const Color(0xFFF6F4EE).withOpacity(opacity * 0.86),
                const Color(0xFFE9DDC9).withOpacity(opacity * 0.54),
              ],
            ).createShader(rect),
        );
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(0, -sample.height * 0.30),
            width: sample.width * 0.60,
            height: sample.height * 0.16,
          ),
          Paint()..color = Colors.white.withOpacity(opacity * 0.22),
        );
        canvas.restore();
      }
      canvas.restore();
    }

    paintShells(upperSamples, upperPts);
    if (lowerSamples.length >= 3) {
      paintShells(
        lowerSamples
            .map(
              (s) => s.copyWith(
                width: s.width * 0.90,
                height: s.height * 0.86,
                center: Offset(s.center.dx, s.center.dy - s.height * 0.06),
              ),
            )
            .toList(),
        lowerPts,
      );
    }
    _paintLipOcclusion(canvas, size);
  }

  void _paintSeparatorHints(Canvas canvas, List<Offset> jawPts, Color color) {
    final samples = _buildArchSamples(jawPts, const [], maxSamples: 8);
    if (samples.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.9;
    for (final sample in samples.skip(1).take(samples.length - 2)) {
      canvas.drawLine(
        Offset(sample.center.dx, sample.center.dy - sample.height * 0.44),
        Offset(sample.center.dx, sample.center.dy + sample.height * 0.44),
        paint,
      );
    }
  }

  void _paintLipOcclusion(Canvas canvas, Size size) {
    final mouthPath = _mouthWindowPath(size);
    if (mouthPath == null) return;
    final lipShade = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..color = Colors.black.withOpacity(0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    canvas.drawPath(mouthPath, lipShade);

    final upperLip = landmarks.upperLipOuterPixelsCoverFit(size, imageSize);
    if (upperLip.length >= 3) {
      final path = Path()..moveTo(upperLip.first.dx, upperLip.first.dy);
      for (final pt in upperLip.skip(1)) {
        path.lineTo(pt.dx, pt.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..color = Colors.black.withOpacity(0.06)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
      );
    }
  }

  Path? _combinedToothPath(List<Offset> upperPts, List<Offset> lowerPts) {
    final parts = <Path>[];
    if (upperPts.length >= 4) parts.add(_closedPath(upperPts));
    if (lowerPts.length >= 4) parts.add(_closedPath(lowerPts));
    if (parts.isEmpty) return null;
    final path = Path();
    for (final part in parts) {
      path.addPath(part, Offset.zero);
    }
    return path;
  }

  Path? _fallbackVisibleToothPath(Size size, List<Offset> upperPts, List<Offset> lowerPts) {
    final parts = <Path>[];
    final upperSamples = _fallbackUpperSamples(size, upperPts, landmarks.upperToothDepths, maxSamples: 8);
    if (upperSamples.isNotEmpty) {
      parts.add(_bandPathFromSamples(
        upperSamples,
        widthScale: 0.90,
        heightScale: 0.90,
        yOffset: 0.0,
      ));
    }
    final lowerSamples = _fallbackLowerSamples(size, lowerPts, landmarks.lowerToothDepths, maxSamples: 8);
    if (lowerSamples.length >= 3) {
      parts.add(_bandPathFromSamples(
        lowerSamples
            .map(
              (s) => s.copyWith(
                width: s.width * 0.92,
                height: s.height * 0.88,
                center: Offset(s.center.dx, s.center.dy - s.height * 0.06),
              ),
            )
            .toList(),
        widthScale: 0.90,
        heightScale: 0.88,
        yOffset: 0.0,
      ));
    }
    if (parts.isEmpty) return _combinedToothPath(upperPts, lowerPts);
    final path = Path();
    for (final part in parts) {
      path.addPath(part, Offset.zero);
    }
    return path;
  }

  List<_ArchSample> _fallbackUpperSamples(
    Size size,
    List<Offset> upperPts,
    List<double> depths, {
    int? maxSamples,
  }) {
    final metrics = _mouthMetrics(size);
    if (metrics == null) return _buildArchSamples(upperPts, depths, maxSamples: maxSamples);
    return _buildSamplesFromMouthBand(
      center: Offset(
        metrics.center.dx,
        metrics.center.dy - metrics.height * 0.18,
      ),
      bandWidth: metrics.width * 0.92,
      bandHeight: metrics.height * 0.34,
      angle: metrics.angle,
      depths: depths,
      maxSamples: maxSamples ?? 8,
    );
  }

  List<_ArchSample> _fallbackLowerSamples(
    Size size,
    List<Offset> lowerPts,
    List<double> depths, {
    int? maxSamples,
  }) {
    if (!_shouldRenderLowerRow()) return const [];
    final metrics = _mouthMetrics(size);
    if (metrics == null) return _buildArchSamples(lowerPts, depths, maxSamples: maxSamples);
    if (metrics.height < metrics.width * 0.12) return const [];
    return _buildSamplesFromMouthBand(
      center: Offset(
        metrics.center.dx,
        metrics.center.dy + metrics.height * 0.16,
      ),
      bandWidth: metrics.width * 0.84,
      bandHeight: metrics.height * 0.24,
      angle: metrics.angle,
      depths: depths,
      maxSamples: maxSamples ?? 5,
    );
  }

  bool _shouldRenderLowerRow() {
    final opening = (landmarks.lowerLipBottomY - landmarks.upperLipTopY).clamp(0.0, 1.0);
    final lowerDepths = landmarks.lowerToothDepths;
    final depthSpread = lowerDepths.isEmpty
        ? 0.0
        : (lowerDepths.reduce(math.max) - lowerDepths.reduce(math.min)).abs();
    return opening >= 0.085 && depthSpread >= 0.003;
  }

  Rect? _visibleToothRect(Size size) {
    final mouth = _mouthWindowPath(size)?.getBounds();
    final bbox = _toothBboxRectCoverFit(size);
    Rect? rect = bbox;
    if (mouth != null) {
      rect = rect == null ? mouth : rect.intersect(mouth);
    }
    if (rect == null || rect.width <= 0 || rect.height <= 0) return null;
    return Rect.fromLTWH(
      rect.left,
      rect.top + rect.height * 0.08,
      rect.width,
      rect.height * 0.72,
    );
  }

  _MouthMetrics? _mouthMetrics(Size size) {
    final bbox = _toothBboxRectCoverFit(size);
    if (bbox == null || bbox.width <= 0 || bbox.height <= 0) return null;
    final left = _coverFitPoint(size, landmarks.lipLeftX, landmarks.lipLeftY);
    final right = _coverFitPoint(size, landmarks.lipRightX, landmarks.lipRightY);
    final angle = math.atan2(right.dy - left.dy, right.dx - left.dx);
    final lipWidth = (right - left).distance;
    final center = Offset(
      bbox.center.dx,
      bbox.top + bbox.height * 0.46,
    );
    return _MouthMetrics(
      center: center,
      width: math.max(bbox.width * 0.88, lipWidth * 0.88),
      height: bbox.height * 0.70,
      angle: angle,
    );
  }

  Rect? _toothBboxRectCoverFit(Size viewSize) {
    if (landmarks.toothBboxW <= 0 || landmarks.toothBboxH <= 0) return null;
    final fitted = applyBoxFit(BoxFit.cover, imageSize, viewSize);
    final scaleX = fitted.destination.width / fitted.source.width;
    final scaleY = fitted.destination.height / fitted.source.height;
    final dstW = imageSize.width * scaleX;
    final dstH = imageSize.height * scaleY;
    final dx = (viewSize.width - dstW) / 2.0;
    final dy = (viewSize.height - dstH) / 2.0;
    return Rect.fromLTWH(
      dx + landmarks.toothBboxX * dstW,
      dy + landmarks.toothBboxY * dstH,
      landmarks.toothBboxW * dstW,
      landmarks.toothBboxH * dstH,
    );
  }

  Offset _coverFitPoint(Size viewSize, double x, double y) {
    final fitted = applyBoxFit(BoxFit.cover, imageSize, viewSize);
    final scaleX = fitted.destination.width / fitted.source.width;
    final scaleY = fitted.destination.height / fitted.source.height;
    final dstW = imageSize.width * scaleX;
    final dstH = imageSize.height * scaleY;
    final dx = (viewSize.width - dstW) / 2.0;
    final dy = (viewSize.height - dstH) / 2.0;
    return Offset(dx + x * dstW, dy + y * dstH);
  }

  List<_ArchSample> _buildSamplesFromRect(
    Rect rect,
    List<double> depths, {
    required int maxSamples,
  }) {
    if (rect.width <= 0 || rect.height <= 0) return const [];
    final count = maxSamples.clamp(5, 8).toInt();
    final normalizedDepths = _normalizeDepths(depths);
    final angle = _mouthAngle(size: null);
    final samples = <_ArchSample>[];
    for (int i = 0; i < count; i++) {
      final t = (i + 0.5) / count;
      final depth = normalizedDepths.isEmpty
          ? (1 - (t - 0.5).abs() * 1.2).clamp(0.0, 1.0)
          : normalizedDepths[(t * (normalizedDepths.length - 1)).round()];
      final x = ui.lerpDouble(rect.left + rect.width * 0.04, rect.right - rect.width * 0.04, t)!;
      final baseCenter = Offset(x, rect.center.dy - rect.height * 0.02 - depth * rect.height * 0.03);
      final center = _rotatePoint(baseCenter, rect.center, angle);
      samples.add(
        _ArchSample(
          center: center,
          width: (rect.width / count * (0.82 + depth * 0.10)).clamp(rect.width * 0.09, rect.width * 0.24),
          height: (rect.height * (0.84 + depth * 0.10)).clamp(rect.height * 0.52, rect.height * 0.96),
          angle: angle,
        ),
      );
    }
    return samples;
  }

  List<_ArchSample> _buildSamplesFromMouthBand({
    required Offset center,
    required double bandWidth,
    required double bandHeight,
    required double angle,
    required List<double> depths,
    required int maxSamples,
  }) {
    if (bandWidth <= 0 || bandHeight <= 0) return const [];
    final count = maxSamples.clamp(5, 8).toInt();
    final normalizedDepths = _normalizeDepths(depths);
    final samples = <_ArchSample>[];
    final xAxis = Offset(math.cos(angle), math.sin(angle));
    final yAxis = Offset(-math.sin(angle), math.cos(angle));

    for (int i = 0; i < count; i++) {
      final t = (i + 0.5) / count;
      final depth = normalizedDepths.isEmpty
          ? (1 - (t - 0.5).abs() * 1.2).clamp(0.0, 1.0)
          : normalizedDepths[(t * (normalizedDepths.length - 1)).round()];
      final along = ((t - 0.5) * bandWidth * 0.92);
      final across = -bandHeight * 0.03 - depth * bandHeight * 0.02;
      final sampleCenter = Offset(
        center.dx + xAxis.dx * along + yAxis.dx * across,
        center.dy + xAxis.dy * along + yAxis.dy * across,
      );
      samples.add(
        _ArchSample(
          center: sampleCenter,
          width: (bandWidth / count * (0.84 + depth * 0.10)).clamp(bandWidth * 0.09, bandWidth * 0.24),
          height: (bandHeight * (0.92 + depth * 0.08)).clamp(bandHeight * 0.62, bandHeight * 1.04),
          angle: angle,
        ),
      );
    }
    return samples;
  }

  Path _bandPathFromSamples(
    List<_ArchSample> samples, {
    required double widthScale,
    required double heightScale,
    required double yOffset,
  }) {
    final path = Path();
    for (final sample in samples) {
      final w = sample.width * widthScale;
      final h = sample.height * heightScale;
      final center = Offset(sample.center.dx, sample.center.dy + sample.height * yOffset);
      final rectPath = Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: center, width: w, height: h),
            Radius.circular(w * 0.24),
          ),
        );
      final matrix = Matrix4.identity()
        ..translate(center.dx, center.dy)
        ..rotateZ(sample.angle)
        ..translate(-center.dx, -center.dy);
      path.addPath(rectPath.transform(matrix.storage), Offset.zero);
    }
    return path;
  }

  double _mouthAngle({Size? size}) {
    final left = Offset(landmarks.lipLeftX, landmarks.lipLeftY);
    final right = Offset(landmarks.lipRightX, landmarks.lipRightY);
    return math.atan2(right.dy - left.dy, right.dx - left.dx);
  }

  Offset _rotatePoint(Offset point, Offset pivot, double angle) {
    final dx = point.dx - pivot.dx;
    final dy = point.dy - pivot.dy;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);
    return Offset(
      pivot.dx + dx * cosA - dy * sinA,
      pivot.dy + dx * sinA + dy * cosA,
    );
  }

  Path _closedPath(List<Offset> points) {
    final ordered = _orderPolygon(points);
    final path = Path()..moveTo(ordered.first.dx, ordered.first.dy);
    for (final pt in ordered.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }

  Path? _mouthWindowPath(Size size) {
    final upper = landmarks.upperLipOuterPixelsCoverFit(size, imageSize);
    final lower = landmarks.lowerLipOuterPixelsCoverFit(size, imageSize);
    if (upper.length < 3 || lower.length < 3) return null;
    final up = _sortByX(upper);
    final low = _sortByX(lower);
    final path = Path()..moveTo(up.first.dx, up.first.dy);
    for (final pt in up.skip(1)) {
      path.lineTo(pt.dx, pt.dy);
    }
    for (final pt in low.reversed) {
      path.lineTo(pt.dx, pt.dy);
    }
    path.close();
    return path;
  }

  List<_ArchSample> _buildArchSamples(List<Offset> jawPts, List<double> depths, {int? maxSamples}) {
    if (jawPts.length < 4) return const [];
    final rect = _bounds(jawPts);
    final count = maxSamples ?? ((rect.width / 30).round().clamp(6, 8));
    final topEdge = _sortByX(jawPts.where((p) => p.dy <= rect.center.dy).toList());
    final bottomEdge = _sortByX(jawPts.where((p) => p.dy > rect.center.dy).toList());
    if (topEdge.length < 2 || bottomEdge.length < 2) return const [];

    final normalizedDepths = _normalizeDepths(depths);
    final samples = <_ArchSample>[];
    final left = rect.left + rect.width * 0.06;
    final right = rect.right - rect.width * 0.06;

    for (int i = 0; i < count; i++) {
      final t = (i + 0.5) / count;
      final x = ui.lerpDouble(left, right, t)!;
      final topY = _interpolateEdgeY(topEdge, x, rect.top + rect.height * 0.16);
      final bottomY = _interpolateEdgeY(bottomEdge, x, rect.bottom - rect.height * 0.12);
      final span = math.max(8.0, bottomY - topY);
      final depth = normalizedDepths.isEmpty
          ? (1 - (t - 0.5).abs() * 1.25).clamp(0.0, 1.0)
          : normalizedDepths[(t * (normalizedDepths.length - 1)).round()];
      final baseWidth = (rect.width / count) * (0.74 + depth * 0.14);
      final baseHeight = span * (0.52 + depth * 0.10);
      samples.add(
        _ArchSample(
          center: Offset(x, ui.lerpDouble(topY, bottomY, 0.46)! - span * 0.02 - depth * 1.2),
          width: baseWidth.clamp(rect.width * 0.08, rect.width * 0.24),
          height: baseHeight.clamp(rect.height * 0.18, rect.height * 0.62),
          angle: 0,
        ),
      );
    }

    for (int i = 0; i < samples.length; i++) {
      final prev = samples[math.max(0, i - 1)].center;
      final next = samples[math.min(samples.length - 1, i + 1)].center;
      final angle = math.atan2(next.dy - prev.dy, next.dx - prev.dx);
      samples[i] = samples[i].copyWith(angle: angle);
    }
    return samples;
  }

  List<double> _normalizeDepths(List<double> depths) {
    if (depths.isEmpty) return const [];
    final minV = depths.reduce(math.min);
    final maxV = depths.reduce(math.max);
    final span = maxV - minV;
    if (span.abs() < 0.00001) {
      return List<double>.filled(depths.length, 0.5);
    }
    return depths.map((d) => ((d - minV) / span).clamp(0.0, 1.0)).toList();
  }

  double _interpolateEdgeY(List<Offset> edge, double x, double fallback) {
    if (edge.isEmpty) return fallback;
    if (x <= edge.first.dx) return edge.first.dy;
    if (x >= edge.last.dx) return edge.last.dy;
    for (int i = 1; i < edge.length; i++) {
      final a = edge[i - 1];
      final b = edge[i];
      if (x <= b.dx) {
        final span = (b.dx - a.dx).abs();
        if (span < 0.0001) return (a.dy + b.dy) * 0.5;
        final t = (x - a.dx) / (b.dx - a.dx);
        return ui.lerpDouble(a.dy, b.dy, t)!;
      }
    }
    return fallback;
  }

  List<Offset> _sortByX(List<Offset> points) {
    final sorted = [...points];
    sorted.sort((a, b) => a.dx.compareTo(b.dx));
    return sorted;
  }

  List<Offset> _orderPolygon(List<Offset> points) {
    final center = _bounds(points).center;
    final ordered = [...points];
    ordered.sort((a, b) {
      final aa = math.atan2(a.dy - center.dy, a.dx - center.dx);
      final bb = math.atan2(b.dy - center.dy, b.dx - center.dx);
      return aa.compareTo(bb);
    });
    return ordered;
  }

  Rect _bounds(List<Offset> points) {
    var minX = points.first.dx;
    var minY = points.first.dy;
    var maxX = points.first.dx;
    var maxY = points.first.dy;
    for (final pt in points) {
      minX = math.min(minX, pt.dx);
      minY = math.min(minY, pt.dy);
      maxX = math.max(maxX, pt.dx);
      maxY = math.max(maxY, pt.dy);
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  /// Smile tangent from tooth polygon extrema (follows head roll better than centroid chords).
  double _polygonSmileTangentAngle(List<Offset> pts) {
    if (pts.length < 2) return 0;
    final left = pts.reduce((a, b) => a.dx < b.dx ? a : b);
    final right = pts.reduce((a, b) => a.dx > b.dx ? a : b);
    final dx = right.dx - left.dx;
    final dy = right.dy - left.dy;
    if (dx.abs() < 0.5 && dy.abs() < 0.5) return 0;
    return math.atan2(dy, dx);
  }

  double _blendBraceTangent(int i, List<Offset> centers, List<Offset> pts) {
    final poly = _polygonSmileTangentAngle(pts);
    if (centers.length < 2) return poly;
    final prev = centers[math.max(0, i - 1)];
    final next = centers[math.min(centers.length - 1, i + 1)];
    final chord = math.atan2(next.dy - prev.dy, next.dx - prev.dx);
    const blend = 0.62;
    return poly * blend + chord * (1.0 - blend);
  }

  Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  bool shouldRepaint(_TeethOverlayPainter old) =>
      old.landmarks != landmarks ||
      old.data.currentArMode != data.currentArMode ||
      old.data.whiteningIntensity != data.whiteningIntensity ||
      old.data.overlayOpacity != data.overlayOpacity ||
      old.scanResult != scanResult;
}

class _ArchSample {
  final Offset center;
  final double width;
  final double height;
  final double angle;

  const _ArchSample({
    required this.center,
    required this.width,
    required this.height,
    required this.angle,
  });

  _ArchSample copyWith({Offset? center, double? width, double? height, double? angle}) {
    return _ArchSample(
      center: center ?? this.center,
      width: width ?? this.width,
      height: height ?? this.height,
      angle: angle ?? this.angle,
    );
  }
}

class _MouthMetrics {
  final Offset center;
  final double width;
  final double height;
  final double angle;

  const _MouthMetrics({
    required this.center,
    required this.width,
    required this.height,
    required this.angle,
  });
}
class _MirroredCamera extends StatelessWidget {
  final CameraController controller;
  final bool isFront;
  const _MirroredCamera({required this.controller, required this.isFront});

  @override
  Widget build(BuildContext context) {
    // Show camera preview without mirroring so front camera isn't reversed.
    // We keep the native MediaPipe frame non-mirrored too for 1:1 alignment.
    return CameraPreview(controller);
  }
}

class _CameraWithOverlay extends StatelessWidget {
  final CameraController controller;
  final bool isFront;
  final int rotationDegrees;
  final Widget Function(Size previewSize) overlayBuilder;

  const _CameraWithOverlay({
    required this.controller,
    required this.isFront,
    required this.rotationDegrees,
    required this.overlayBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final raw = controller.value.previewSize;
    // Use the same orientation as the bitmap sent to MediaPipe (we rotate by rotationDegrees).
    final base = raw ?? const Size(720, 1280);
    final rot = rotationDegrees % 360;
    final previewSize = (rot == 90 || rot == 270) ? Size(base.height, base.width) : base;

    Widget inner = SizedBox(
      width: previewSize.width,
      height: previewSize.height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _MirroredCamera(controller: controller, isFront: isFront),
          overlayBuilder(previewSize),
        ],
      ),
    );

    // Some devices mirror the front camera preview automatically.
    // To ensure the front-cam filter is NOT mirrored, flip the whole stack.
    if (isFront) {
      inner = Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()..scale(-1.0, 1.0, 1.0),
        child: inner,
      );
    }

    return Center(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: inner,
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// IDLE / ERROR / LOADING STATE
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _IdleView extends StatelessWidget {
  final String? error;
  final bool loading;
  final bool mpReady;
  final VoidCallback onStart;
  const _IdleView({this.error, required this.loading,
      required this.mpReady, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF08090E),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated scan icon
              Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(Icons.face_retouching_natural_rounded,
                    size: 40, color: Colors.white30),
              ),
              const SizedBox(height: 28),

              if (loading) ...[
                const SizedBox(
                  width: 28, height: 28,
                  child: CircularProgressIndicator(
                      color: AppTheme.primary, strokeWidth: 2.5),
                ),
                const SizedBox(height: 16),
                Text('Starting cameraâ€¦',
                    style: GoogleFonts.dmSans(
                        color: Colors.white54, fontSize: 14)),
              ] else if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(error!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                          color: Colors.red[300], fontSize: 13, height: 1.5)),
                ),
                const SizedBox(height: 20),
                _PrimaryBtn(
                  label: 'Try Again',
                  icon: Icons.refresh_rounded,
                  onTap: onStart,
                ),
              ] else ...[
                Text('AR Smile Previewer',
                    style: GoogleFonts.dmSans(
                        fontSize: 24, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: -0.5)),
                const SizedBox(height: 10),
                Text(
                  'Enable camera to detect your face with\nMediaPipe and preview dental treatments\nanchored to your actual tooth positions.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.dmSans(
                      color: Colors.white38, fontSize: 13.5, height: 1.6),
                ),
                const SizedBox(height: 8),
                // MediaPipe status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: mpReady
                        ? AppTheme.secondary.withOpacity(0.15)
                        : Colors.orange.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: mpReady
                          ? AppTheme.secondary.withOpacity(0.4)
                          : Colors.orange.withOpacity(0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        mpReady
                            ? Icons.check_circle_rounded
                            : Icons.warning_amber_rounded,
                        size: 13,
                        color: mpReady
                            ? AppTheme.secondary
                            : Colors.orange,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        mpReady
                            ? 'MediaPipe FaceLandmarker ready'
                            : 'Model file missing â€” see README',
                        style: GoogleFonts.dmSans(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: mpReady
                              ? AppTheme.secondary
                              : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _PrimaryBtn(
                  label: 'Enable Camera',
                  icon: Icons.videocam_rounded,
                  onTap: onStart,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// TOP HUD
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _TopHud extends StatelessWidget {
  final bool isActive;
  final bool isFront;
  final bool mpReady;
  final bool faceFound;
  final ArMode mode;
  final Animation<double> pulseAnim;
  final int? onDeviceToothCount;
  final bool hasMultiCam;
  final VoidCallback onFlip;
  final VoidCallback onCaptureBefore;
  final VoidCallback onCaptureAfter;

  const _TopHud({
    required this.isActive,
    required this.isFront,
    required this.mpReady,
    required this.faceFound,
    required this.mode,
    required this.pulseAnim,
    required this.onDeviceToothCount,
    required this.hasMultiCam,
    required this.onFlip,
    required this.onCaptureBefore,
    required this.onCaptureAfter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Colors.transparent],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        left: 16, right: 16, bottom: 20,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicators
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isActive)
                _StatusPill(
                  label: faceFound ? 'FACE DETECTED' : 'SCANNINGâ€¦',
                  color: faceFound
                      ? const Color(0xFF4ADE80)
                      : const Color(0xFFF59E0B),
                  pulseAnim: faceFound ? null : pulseAnim,
                ),
              if (isActive && mode != ArMode.none) ...[
                const SizedBox(height: 6),
                _StatusPill(
                  label: '${mode.emoji}  ${mode.label}',
                  color: AppTheme.primary.withOpacity(0.9),
                ),
              ],
              if (isActive && faceFound) ...[
                const SizedBox(height: 6),
                _StatusPill(
                  label: '478 landmarks',
                  color: Colors.white24,
                  small: true,
                ),
                if (onDeviceToothCount != null) ...[
                  const SizedBox(height: 6),
                  _StatusPill(
                    label: 'Teeth: ${onDeviceToothCount!}',
                    color: AppTheme.secondary.withOpacity(0.9),
                    small: true,
                  ),
                ],
              ],
            ],
          ),
          const Spacer(),
          // Action buttons
          if (isActive) ...[
            if (hasMultiCam) _HudBtn(
              icon: Icons.flip_camera_ios_rounded,
              onTap: onFlip,
            ),
            const SizedBox(width: 8),
            _HudBtn(
              icon: Icons.camera_alt_outlined,
              label: 'Before',
              onTap: onCaptureBefore,
            ),
            const SizedBox(width: 8),
            _HudBtn(
              icon: Icons.auto_fix_high_rounded,
              label: 'After',
              onTap: onCaptureAfter,
              accent: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Animation<double>? pulseAnim;
  final bool small;
  const _StatusPill({required this.label, required this.color,
      this.pulseAnim, this.small = false});

  @override
  Widget build(BuildContext context) {
    Widget inner = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: small ? 5 : 6,
          height: small ? 5 : 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.dmSans(
                fontSize: small ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.3)),
      ],
    );

    if (pulseAnim != null) {
      inner = AnimatedBuilder(
        animation: pulseAnim!,
        builder: (_, child) => Opacity(opacity: pulseAnim!.value, child: child),
        child: inner,
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 10, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: inner,
    );
  }
}

class _HudBtn extends StatelessWidget {
  final IconData icon;
  final String? label;
  final VoidCallback onTap;
  final bool accent;
  const _HudBtn({required this.icon, this.label,
      required this.onTap, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: label != null ? 12 : 10,
            vertical: 8),
        decoration: BoxDecoration(
          color: accent
              ? AppTheme.primary.withOpacity(0.85)
              : Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: accent
                  ? AppTheme.primary
                  : Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            if (label != null) ...[
              const SizedBox(width: 5),
              Text(label!,
                  style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ],
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// BOTTOM PANEL
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _BottomPanel extends StatefulWidget {
  final AppData data;
  final bool isActive;
  final bool loading;
  final Uint8List? beforeBytes;
  final Uint8List? afterBytes;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onSave;
  final VoidCallback onPatientChange;

  const _BottomPanel({
    required this.data,
    required this.isActive,
    required this.loading,
    this.beforeBytes,
    this.afterBytes,
    required this.onStart,
    required this.onStop,
    required this.onSave,
    required this.onPatientChange,
  });

  @override
  State<_BottomPanel> createState() => _BottomPanelState();
}

class _BottomPanelState extends State<_BottomPanel> {
  bool _showSettings = false;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.of(context).padding.bottom;
    final data = widget.data;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, pad + 12),
      child: AppTheme.glass(
        radius: BorderRadius.circular(26),
        tint: isDark ? const Color(0xFF0F1B2D) : Colors.white,
        blur: 18,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

          // â”€â”€ Before/After strip â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (widget.beforeBytes != null || widget.afterBytes != null) ...[
            _BeforeAfterStrip(
              before: widget.beforeBytes,
              after:  widget.afterBytes,
            ),
            const SizedBox(height: 14),
          ],

          // â”€â”€ Settings panel â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (_showSettings && widget.isActive) ...[
            _SettingsPanel(data: data),
            const SizedBox(height: 12),
          ],

          // â”€â”€ Mode chips â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (widget.isActive) ...[
            _ModeChipRow(data: data),
            const SizedBox(height: 12),
          ],

          // â”€â”€ Action row â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Row(
            children: [
              if (!widget.isActive) ...[
                Expanded(child: _PrimaryBtn(
                  label: 'Enable Camera',
                  icon: Icons.videocam_rounded,
                  onTap: widget.loading ? null : widget.onStart,
                  loading: widget.loading,
                )),
              ] else ...[
                // Stop button
                _CircleBtn(
                  icon: Icons.stop_rounded,
                  color: Colors.red.withOpacity(0.85),
                  onTap: widget.onStop,
                ),
                const SizedBox(width: 12),

                // Tune/settings toggle
                Expanded(
                  child: _OutlineBtn(
                    label: _showSettings ? 'Hide Settings' : 'Adjustments',
                    icon: _showSettings
                        ? Icons.keyboard_arrow_down_rounded
                        : Icons.tune_rounded,
                    onTap: () =>
                        setState(() => _showSettings = !_showSettings),
                  ),
                ),
                const SizedBox(width: 12),

                // Patient + Save
                _CircleBtn(
                  icon: Icons.save_rounded,
                  color: AppTheme.secondary,
                  onTap: widget.onSave,
                ),
              ],
            ],
          ),

          // â”€â”€ Patient info â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (widget.isActive) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: widget.onPatientChange,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(0.10)),
                ),
                child: Row(
                  children: [
                    PatientAvatar(
                        patient: data.selectedPatient, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data.selectedPatient.name,
                              style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white)),
                          Text(data.selectedPatient.procedure,
                              style: GoogleFonts.dmSans(
                                  fontSize: 11, color: Colors.white38)),
                        ],
                      ),
                    ),
                    Text('Change',
                        style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.lightBlueAccent,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
          ],
        ),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// MODE CHIP ROW
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _ModeChipRow extends StatelessWidget {
  final AppData data;
  const _ModeChipRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: ArMode.values.map((mode) {
          final sel = data.currentArMode == mode;
          return GestureDetector(
            onTap: () => data.setArMode(mode),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: sel
                    ? AppTheme.primary
                    : Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: sel
                      ? AppTheme.primary
                      : Colors.white.withOpacity(0.2),
                  width: sel ? 1.5 : 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mode.emoji,
                      style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 7),
                  Text(mode.label,
                      style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SETTINGS PANEL
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

Future<void> showToothScanBackendUrlDialog(BuildContext context, AppData data) async {
  final controller = TextEditingController(text: data.toothScanEndpoint);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: const Color(0xFF161923),
      title: Text(
        'Tooth scan backend (your PC)',
        style: GoogleFonts.dmSans(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Same Wi‑Fi as this phone. Use your PC IPv4, no trailing slash.',
              style: GoogleFonts.dmSans(fontSize: 12, color: Colors.white60, height: 1.35),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              style: GoogleFonts.dmSans(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'http://192.168.1.152:8000',
                hintStyle: GoogleFonts.dmSans(color: Colors.white38),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.secondary),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancel', style: GoogleFonts.dmSans(color: Colors.white70)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Save', style: GoogleFonts.dmSans(color: AppTheme.secondary, fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    data.setToothScanEndpoint(controller.text.trim());
  }
}

class _SettingsPanel extends StatelessWidget {
  final AppData data;
  const _SettingsPanel({required this.data});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Live Mouth Fit',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Switch.adaptive(
                value: data.realToothScanEnabled,
                onChanged: data.setRealToothScanEnabled,
                activeColor: AppTheme.secondary,
              ),
            ],
          ),
          Text(
            data.realToothScanConfigured
                ? 'MediaPipe + backend tooth masks (ONNX on your PC). Set URL below if needed.'
                : 'Turn on and set your PC URL to use your trained model; otherwise MediaPipe only.',
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: () => showToothScanBackendUrlDialog(context, data),
              icon: Icon(Icons.dns_rounded, color: AppTheme.secondary, size: 20),
              label: Text(
                data.toothScanEndpoint.isEmpty
                    ? 'Set PC backend URL'
                    : 'Edit: ${data.toothScanEndpoint}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.secondary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SliderRow(
            label: 'Whitening Intensity',
            value: data.whiteningIntensity,
            onChanged: data.setWhiteningIntensity,
            color: const Color(0xFFF9A825),
          ),
          if (data.currentArMode == ArMode.whitening) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Before/After slider',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: data.whiteningCompareEnabled,
                  onChanged: data.setWhiteningCompareEnabled,
                  activeColor: AppTheme.secondary,
                ),
              ],
            ),
            if (data.whiteningCompareEnabled) ...[
              const SizedBox(height: 6),
              _SliderRow(
                label: 'Split',
                value: data.whiteningCompareSplit,
                onChanged: data.setWhiteningCompareSplit,
                color: AppTheme.secondary,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Freeze before',
                      style: GoogleFonts.dmSans(
                        fontSize: 11.5,
                        color: Colors.white60,
                      ),
                    ),
                  ),
                  Switch.adaptive(
                    value: data.whiteningCompareFreezeBefore,
                    onChanged: data.setWhiteningCompareFreezeBefore,
                    activeColor: AppTheme.secondary,
                  ),
                ],
              ),
            ],
          ],
          const SizedBox(height: 10),
          _SliderRow(
            label: 'Overlay Opacity',
            value: data.overlayOpacity,
            onChanged: data.setOverlayOpacity,
            color: Colors.lightBlueAccent,
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final Color color;
  const _SliderRow({required this.label, required this.value,
      required this.onChanged, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 11.5, color: Colors.white60)),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              activeTrackColor:   color,
              inactiveTrackColor: color.withOpacity(0.2),
              thumbColor:         color,
              overlayColor:       color.withOpacity(0.12),
              trackHeight:        3,
              thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 8),
            ),
            child: Slider(value: value, onChanged: onChanged),
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ),
      ],
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// BEFORE / AFTER STRIP
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _BeforeAfterStrip extends StatelessWidget {
  final Uint8List? before;
  final Uint8List? after;
  const _BeforeAfterStrip({this.before, this.after});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _SnapCard(label: 'BEFORE', bytes: before,
            color: Colors.white24)),
        const SizedBox(width: 10),
        Expanded(child: _SnapCard(label: 'AFTER', bytes: after,
            color: AppTheme.primary.withOpacity(0.6))),
      ],
    );
  }
}

class _SnapCard extends StatelessWidget {
  final String label;
  final Uint8List? bytes;
  final Color color;
  const _SnapCard({required this.label, this.bytes, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (bytes != null)
            Image.memory(bytes!, fit: BoxFit.cover)
          else
            Center(child: Icon(
                label == 'BEFORE'
                    ? Icons.camera_alt_outlined
                    : Icons.auto_fix_high_rounded,
                color: Colors.white24, size: 22)),
          Positioned(
            bottom: 5, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(label,
                    style: GoogleFonts.dmSans(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: Colors.white70,
                        letterSpacing: 0.8)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// SHARED BUTTON WIDGETS
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  const _PrimaryBtn({required this.label, required this.icon,
      this.onTap, this.loading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppTheme.primary.withOpacity(0.4)
              : AppTheme.primary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: loading
            ? const Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(label,
                      style: GoogleFonts.dmSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ],
              ),
      ),
    );
  }
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _OutlineBtn({required this.label, required this.icon,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(width: 8),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _CircleBtn({required this.icon, required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}







