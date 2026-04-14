// lib/models/models.dart

import 'package:flutter/material.dart';

// ─────────────────────────────────────────────
// PATIENT MODEL
// ─────────────────────────────────────────────
class Patient {
  final String id;
  String name;
  int age;
  String contact;
  String procedure;
  String lastVisit;
  String nextVisit;
  int arSessions;
  String lastArMode;
  List<TreatmentRecord> history;
  Color avatarColor;
  Color avatarBg;

  Patient({
    required this.id,
    required this.name,
    required this.age,
    required this.contact,
    required this.procedure,
    required this.lastVisit,
    required this.nextVisit,
    this.arSessions = 0,
    this.lastArMode = 'None',
    required this.history,
    required this.avatarColor,
    required this.avatarBg,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.substring(0, 2).toUpperCase();
  }
}

class TreatmentRecord {
  final String date;
  final String description;
  final String? arMode;

  TreatmentRecord({
    required this.date,
    required this.description,
    this.arMode,
  });
}

// ─────────────────────────────────────────────
// INVENTORY MODEL
// ─────────────────────────────────────────────
enum InventoryCategory {
  anesthetic,
  restorative,
  impression,
  sterilization,
  orthodontic,
  other,
}

extension InventoryCategoryExt on InventoryCategory {
  String get label {
    switch (this) {
      case InventoryCategory.anesthetic: return 'Anesthetic';
      case InventoryCategory.restorative: return 'Restorative';
      case InventoryCategory.impression: return 'Impression';
      case InventoryCategory.sterilization: return 'Sterilization';
      case InventoryCategory.orthodontic: return 'Orthodontic';
      case InventoryCategory.other: return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case InventoryCategory.anesthetic: return Icons.vaccines_rounded;
      case InventoryCategory.restorative: return Icons.healing_rounded;
      case InventoryCategory.impression: return Icons.water_drop_rounded;
      case InventoryCategory.sterilization: return Icons.sanitizer_rounded;
      case InventoryCategory.orthodontic: return Icons.face_retouching_natural;
      case InventoryCategory.other: return Icons.inventory_2_rounded;
    }
  }

  Color get color {
    switch (this) {
      case InventoryCategory.anesthetic: return const Color(0xFFE91E63);
      case InventoryCategory.restorative: return const Color(0xFF1565C0);
      case InventoryCategory.impression: return const Color(0xFF6750A4);
      case InventoryCategory.sterilization: return const Color(0xFF2E7D32);
      case InventoryCategory.orthodontic: return const Color(0xFF4527A0);
      case InventoryCategory.other: return const Color(0xFF455A64);
    }
  }

  Color get bgColor {
    switch (this) {
      case InventoryCategory.anesthetic: return const Color(0xFFFCE4EC);
      case InventoryCategory.restorative: return const Color(0xFFE3F2FD);
      case InventoryCategory.impression: return const Color(0xFFEDE7F6);
      case InventoryCategory.sterilization: return const Color(0xFFE8F5E9);
      case InventoryCategory.orthodontic: return const Color(0xFFEDE7F6);
      case InventoryCategory.other: return const Color(0xFFECEFF1);
    }
  }
}

enum ExpiryStatus { ok, warning, expired }

class InventoryItem {
  final String id;
  String name;
  InventoryCategory category;
  String batchNumber;
  int quantity;
  DateTime expiryDate;

  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.batchNumber,
    required this.quantity,
    required this.expiryDate,
  });

  int get daysUntilExpiry {
    return expiryDate.difference(DateTime.now()).inDays;
  }

  ExpiryStatus get status {
    final d = daysUntilExpiry;
    if (d < 0) return ExpiryStatus.expired;
    if (d <= 30) return ExpiryStatus.warning;
    return ExpiryStatus.ok;
  }

  String get expiryLabel {
    final d = daysUntilExpiry;
    if (d < 0) return 'Expired ${d.abs()} day${d.abs() != 1 ? 's' : ''} ago';
    if (d == 0) return 'Expires today';
    return '$d day${d != 1 ? 's' : ''} left';
  }

  Color get statusColor {
    switch (status) {
      case ExpiryStatus.ok: return const Color(0xFF2E7D32);
      case ExpiryStatus.warning: return const Color(0xFFE65100);
      case ExpiryStatus.expired: return const Color(0xFFB71C1C);
    }
  }

  Color get statusBgColor {
    switch (status) {
      case ExpiryStatus.ok: return const Color(0xFFE8F5E9);
      case ExpiryStatus.warning: return const Color(0xFFFBE9E7);
      case ExpiryStatus.expired: return const Color(0xFFFFEBEE);
    }
  }
}

// ─────────────────────────────────────────────
// AR MODE
// ─────────────────────────────────────────────
enum ArMode { none, whitening, braces, veneer }

extension ArModeExt on ArMode {
  String get label {
    switch (this) {
      case ArMode.none: return 'Live View';
      case ArMode.whitening: return 'Whitening';
      case ArMode.braces: return 'Braces';
      case ArMode.veneer: return 'Veneers';
    }
  }

  String get emoji {
    switch (this) {
      case ArMode.none: return '👁️';
      case ArMode.whitening: return '🦷';
      case ArMode.braces: return '😁';
      case ArMode.veneer: return '💎';
    }
  }

  String get description {
    switch (this) {
      case ArMode.none: return 'No overlay';
      case ArMode.whitening: return 'Shade overlay';
      case ArMode.braces: return 'Ortho preview';
      case ArMode.veneer: return 'Shape & shade';
    }
  }
}

// Real tooth scan models used by the backend-driven segmentation pipeline.
enum ToothJaw { upper, lower }

class ToothVertex {
  final double x;
  final double y;

  const ToothVertex({required this.x, required this.y});

  factory ToothVertex.fromMap(Map<dynamic, dynamic> map) {
    return ToothVertex(
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
    );
  }

  Offset toPixel(Size size) => Offset(x * size.width, y * size.height);

  Offset toPixelCoverFit(Size viewSize, Size imageSize) {
    final fitted = applyBoxFit(BoxFit.cover, imageSize, viewSize);
    final scaleX = fitted.destination.width / fitted.source.width;
    final scaleY = fitted.destination.height / fitted.source.height;
    final dstW = imageSize.width * scaleX;
    final dstH = imageSize.height * scaleY;
    final dx = (viewSize.width - dstW) / 2.0;
    final dy = (viewSize.height - dstH) / 2.0;
    return Offset(dx + x * dstW, dy + y * dstH);
  }
}

/// Maps `/scan/teeth` normalized coords (relative to decoded camera frame W×H) into the
/// **same** letterboxed preview space as MediaPipe landmarks.
///
/// Camera **preview** size and **image stream** size often differ; landmarks use stream
/// [landmarkImageSize]. Backend reports [scanW]×[scanH] for the same NV21 pipeline.
/// When those sizes differ, we rescale normalized coords before `BoxFit.cover` mapping.
abstract final class ToothOverlayMapper {
  static Offset vertexToView(
    ToothVertex v,
    Size viewSize,
    Size landmarkImageSize,
    int scanW,
    int scanH,
  ) {
    final sw = scanW.toDouble();
    final sh = scanH.toDouble();
    if (sw <= 0 || sh <= 0) {
      return v.toPixelCoverFit(viewSize, landmarkImageSize);
    }
    final lw = landmarkImageSize.width;
    final lh = landmarkImageSize.height;
    if ((sw - lw).abs() <= 2.0 && (sh - lh).abs() <= 2.0) {
      return v.toPixelCoverFit(viewSize, landmarkImageSize);
    }
    final px = v.x * sw;
    final py = v.y * sh;
    final lx = px * (lw / sw);
    final ly = py * (lh / sh);
    final remapped = ToothVertex(
      x: (lx / lw).clamp(0.0, 1.0),
      y: (ly / lh).clamp(0.0, 1.0),
    );
    return remapped.toPixelCoverFit(viewSize, landmarkImageSize);
  }
}

class ToothDetection {
  final String id;
  final ToothJaw jaw;
  final double confidence;
  final List<ToothVertex> polygon;

  const ToothDetection({
    required this.id,
    required this.jaw,
    required this.confidence,
    required this.polygon,
  });

  factory ToothDetection.fromMap(Map<dynamic, dynamic> map) {
    final jawRaw = (map['jaw'] ?? 'upper').toString().toLowerCase();
    final rawPolygon = (map['polygon'] ?? map['points'] ?? const []) as List;
    return ToothDetection(
      id: (map['id'] ?? '').toString(),
      jaw: jawRaw == 'lower' ? ToothJaw.lower : ToothJaw.upper,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      polygon: rawPolygon
          .whereType<Map>()
          .map(ToothVertex.fromMap)
          .toList(),
    );
  }

  List<Offset> pixelPolygon(Size size) => polygon.map((p) => p.toPixel(size)).toList();

  List<Offset> pixelPolygonCoverFit(Size viewSize, Size imageSize) =>
      polygon.map((p) => p.toPixelCoverFit(viewSize, imageSize)).toList();

  Offset centroid(Size size) {
    final pts = pixelPolygon(size);
    if (pts.isEmpty) return Offset.zero;
    var sx = 0.0;
    var sy = 0.0;
    for (final pt in pts) {
      sx += pt.dx;
      sy += pt.dy;
    }
    return Offset(sx / pts.length, sy / pts.length);
  }

  Offset centroidCoverFit(Size viewSize, Size imageSize) {
    final pts = pixelPolygonCoverFit(viewSize, imageSize);
    if (pts.isEmpty) return Offset.zero;
    var sx = 0.0;
    var sy = 0.0;
    for (final pt in pts) {
      sx += pt.dx;
      sy += pt.dy;
    }
    return Offset(sx / pts.length, sy / pts.length);
  }

  /// Project backend tooth polygon into preview space aligned with MediaPipe.
  List<Offset> overlayPolygon(Size viewSize, Size landmarkImageSize, ToothScanResult scan) {
    return polygon
        .map(
          (p) => ToothOverlayMapper.vertexToView(
                p,
                viewSize,
                landmarkImageSize,
                scan.imageWidth,
                scan.imageHeight,
              ),
        )
        .toList();
  }

  Offset overlayCentroid(Size viewSize, Size landmarkImageSize, ToothScanResult scan) {
    final pts = overlayPolygon(viewSize, landmarkImageSize, scan);
    if (pts.isEmpty) return Offset.zero;
    var sx = 0.0;
    var sy = 0.0;
    for (final pt in pts) {
      sx += pt.dx;
      sy += pt.dy;
    }
    return Offset(sx / pts.length, sy / pts.length);
  }
}

class ToothScanResult {
  final int imageWidth;
  final int imageHeight;
  final List<ToothDetection> teeth;
  final double? confidence;

  const ToothScanResult({
    required this.imageWidth,
    required this.imageHeight,
    required this.teeth,
    this.confidence,
  });

  bool get hasDetections => teeth.isNotEmpty;

  List<ToothDetection> teethForJaw(ToothJaw jaw, Size size) {
    final filtered = teeth.where((t) => t.jaw == jaw).toList();
    filtered.sort((a, b) => a.centroid(size).dx.compareTo(b.centroid(size).dx));
    return filtered;
  }

  List<ToothDetection> teethForJawCoverFit(ToothJaw jaw, Size viewSize, Size imageSize) {
    final filtered = teeth.where((t) => t.jaw == jaw).toList();
    filtered.sort((a, b) =>
        a.centroidCoverFit(viewSize, imageSize).dx.compareTo(b.centroidCoverFit(viewSize, imageSize).dx));
    return filtered;
  }

  /// Same as [teethForJawCoverFit] but sort keys use [ToothOverlayMapper] (MediaPipe frame size).
  List<ToothDetection> teethForJawForOverlay(ToothJaw jaw, Size viewSize, Size landmarkImageSize) {
    final filtered = teeth.where((t) => t.jaw == jaw).toList();
    filtered.sort(
      (a, b) => a
          .overlayCentroid(viewSize, landmarkImageSize, this)
          .dx
          .compareTo(b.overlayCentroid(viewSize, landmarkImageSize, this).dx),
    );
    return filtered;
  }

  factory ToothScanResult.fromMap(Map<dynamic, dynamic> map) {
    final rawTeeth = (map['teeth'] ?? const []) as List;
    return ToothScanResult(
      imageWidth: (map['imageWidth'] as num?)?.toInt() ?? 0,
      imageHeight: (map['imageHeight'] as num?)?.toInt() ?? 0,
      confidence: (map['confidence'] as num?)?.toDouble(),
      teeth: rawTeeth
          .whereType<Map>()
          .map(ToothDetection.fromMap)
          .toList(),
    );
  }
}
