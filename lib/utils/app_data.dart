// lib/utils/app_data.dart

import 'package:flutter/material.dart';
import '../models/models.dart';

class AppData extends ChangeNotifier {
  final List<Patient> patients = [
    Patient(
      id: 'p1',
      name: 'Maria Reyes',
      age: 28,
      contact: '0917-123-4567',
      procedure: 'Teeth Whitening',
      lastVisit: 'Jun 20, 2025',
      nextVisit: 'Jul 18, 2025',
      arSessions: 3,
      lastArMode: 'Whitening',
      avatarColor: const Color(0xFF1565C0),
      avatarBg: const Color(0xFFE3F2FD),
      history: [
        TreatmentRecord(date: 'Jun 20, 2025', description: 'AR Whitening Session', arMode: 'Whitening'),
        TreatmentRecord(date: 'May 5, 2025', description: 'Scaling & Polishing'),
        TreatmentRecord(date: 'Mar 12, 2025', description: 'Initial Consultation'),
      ],
    ),
    Patient(
      id: 'p2',
      name: 'Jake Domingo',
      age: 22,
      contact: '0928-123-4567',
      procedure: 'Braces Consultation',
      lastVisit: 'Jun 18, 2025',
      nextVisit: 'Jul 20, 2025',
      arSessions: 1,
      lastArMode: 'Braces',
      avatarColor: const Color(0xFF2E7D32),
      avatarBg: const Color(0xFFE8F5E9),
      history: [
        TreatmentRecord(date: 'Jun 18, 2025', description: 'AR Braces Preview', arMode: 'Braces'),
        TreatmentRecord(date: 'Jun 1, 2025', description: 'X-Ray & Assessment'),
      ],
    ),
    Patient(
      id: 'p3',
      name: 'Ana Cruz',
      age: 35,
      contact: '0939-123-4567',
      procedure: 'Dental Cleaning',
      lastVisit: 'Jun 15, 2025',
      nextVisit: 'Jul 15, 2025',
      arSessions: 0,
      lastArMode: 'None',
      avatarColor: const Color(0xFFE65100),
      avatarBg: const Color(0xFFFFF3E0),
      history: [
        TreatmentRecord(date: 'Jun 15, 2025', description: 'Cleaning & Fluoride'),
        TreatmentRecord(date: 'Jan 10, 2025', description: 'Emergency Extraction'),
      ],
    ),
    Patient(
      id: 'p4',
      name: 'Ben Lim',
      age: 30,
      contact: '0945-123-4567',
      procedure: 'Teeth Whitening',
      lastVisit: 'Jun 22, 2025',
      nextVisit: 'Jul 22, 2025',
      arSessions: 2,
      lastArMode: 'Whitening',
      avatarColor: const Color(0xFF4527A0),
      avatarBg: const Color(0xFFEDE7F6),
      history: [
        TreatmentRecord(date: 'Jun 22, 2025', description: 'Whitening Session 2', arMode: 'Whitening'),
        TreatmentRecord(date: 'Jun 8, 2025', description: 'Whitening Session 1', arMode: 'Whitening'),
        TreatmentRecord(date: 'May 20, 2025', description: 'Consultation'),
      ],
    ),
    Patient(
      id: 'p5',
      name: 'Carla Santos',
      age: 19,
      contact: '0951-987-6543',
      procedure: 'Veneers',
      lastVisit: 'Jun 25, 2025',
      nextVisit: 'Aug 1, 2025',
      arSessions: 2,
      lastArMode: 'Veneer',
      avatarColor: const Color(0xFF880E4F),
      avatarBg: const Color(0xFFFCE4EC),
      history: [
        TreatmentRecord(date: 'Jun 25, 2025', description: 'AR Veneer Preview', arMode: 'Veneer'),
        TreatmentRecord(date: 'Jun 10, 2025', description: 'Initial Veneer Consult'),
      ],
    ),
  ];

  final List<InventoryItem> inventory = [
    InventoryItem(id: 'i1', name: 'Lidocaine HCl 2%', category: InventoryCategory.anesthetic, batchNumber: 'LH2024-08', quantity: 4, expiryDate: DateTime(2025, 6, 1)),
    InventoryItem(id: 'i2', name: 'Composite Resin A2', category: InventoryCategory.restorative, batchNumber: 'CR-409', quantity: 12, expiryDate: DateTime(2025, 7, 9)),
    InventoryItem(id: 'i3', name: 'Alginate Impression', category: InventoryCategory.impression, batchNumber: 'AI-221', quantity: 6, expiryDate: DateTime(2025, 7, 17)),
    InventoryItem(id: 'i4', name: 'Epinephrine 1:100k', category: InventoryCategory.anesthetic, batchNumber: 'EP-512', quantity: 8, expiryDate: DateTime(2025, 9, 20)),
    InventoryItem(id: 'i5', name: 'Zinc Oxide Eugenol', category: InventoryCategory.restorative, batchNumber: 'ZOE-88', quantity: 10, expiryDate: DateTime(2027, 1, 1)),
    InventoryItem(id: 'i6', name: 'Articulating Paper', category: InventoryCategory.other, batchNumber: 'AP-002', quantity: 50, expiryDate: DateTime(2026, 3, 10)),
    InventoryItem(id: 'i7', name: 'Sodium Hypochlorite', category: InventoryCategory.sterilization, batchNumber: 'SH-301', quantity: 3, expiryDate: DateTime(2025, 8, 15)),
    InventoryItem(id: 'i8', name: 'Stainless Brackets', category: InventoryCategory.orthodontic, batchNumber: 'SB-77', quantity: 100, expiryDate: DateTime(2027, 1, 1)),
    InventoryItem(id: 'i9', name: 'Bonding Agent 7th Gen', category: InventoryCategory.restorative, batchNumber: 'BA-701', quantity: 5, expiryDate: DateTime(2025, 10, 30)),
    InventoryItem(id: 'i10', name: 'Dental Floss Tape', category: InventoryCategory.other, batchNumber: 'DFT-55', quantity: 30, expiryDate: DateTime(2026, 6, 1)),
    InventoryItem(id: 'i11', name: 'Prophy Paste', category: InventoryCategory.sterilization, batchNumber: 'PP-118', quantity: 8, expiryDate: DateTime(2025, 12, 15)),
    InventoryItem(id: 'i12', name: 'Calcium Hydroxide', category: InventoryCategory.restorative, batchNumber: 'CH-44', quantity: 6, expiryDate: DateTime(2026, 2, 28)),
  ];

  ArMode currentArMode = ArMode.none;
  double whiteningIntensity = 0.7;
  double overlayOpacity = 0.8;
  int selectedPatientIndex = 0;

  ThemeMode themeMode = ThemeMode.dark;

  // Whitening compare (live before/after split)
  bool whiteningCompareEnabled = false;
  double whiteningCompareSplit = 0.5; // 0..1, vertical divider position
  bool whiteningCompareFreezeBefore = false;
  double whiteningCompareBeforeIntensity = 0.0; // baseline when frozen

  bool realToothScanEnabled = false;
  String toothScanEndpoint = '';
  String toothScanStatus = 'Real tooth scan is off';
  ToothScanResult? liveToothScan;
  DateTime? lastToothScanAt;

  List<InventoryItem> get expiredItems =>
      inventory.where((i) => i.status == ExpiryStatus.expired).toList();

  List<InventoryItem> get expiringItems =>
      inventory.where((i) => i.status == ExpiryStatus.warning).toList();

  List<InventoryItem> get alertItems =>
      inventory.where((i) => i.status != ExpiryStatus.ok).toList()
        ..sort((a, b) => a.daysUntilExpiry.compareTo(b.daysUntilExpiry));

  int get totalAlerts => alertItems.length;
  Patient get selectedPatient => patients[selectedPatientIndex];
  bool get realToothScanConfigured =>
      realToothScanEnabled && toothScanEndpoint.trim().isNotEmpty;

  void addPatient(Patient p) {
    patients.add(p);
    notifyListeners();
  }

  void addInventoryItem(InventoryItem item) {
    inventory.add(item);
    notifyListeners();
  }

  void removeInventoryItem(String id) {
    inventory.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void setArMode(ArMode mode) {
    currentArMode = mode;
    notifyListeners();
  }

  void setThemeMode(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  void toggleThemeMode() {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  void setWhiteningIntensity(double val) {
    whiteningIntensity = val;
    notifyListeners();
  }

  void setWhiteningCompareEnabled(bool enabled) {
    whiteningCompareEnabled = enabled;
    if (!enabled) {
      whiteningCompareFreezeBefore = false;
      whiteningCompareBeforeIntensity = 0.0;
    }
    notifyListeners();
  }

  void setWhiteningCompareSplit(double val) {
    whiteningCompareSplit = val.clamp(0.0, 1.0);
    notifyListeners();
  }

  void setWhiteningCompareFreezeBefore(bool freeze) {
    whiteningCompareFreezeBefore = freeze;
    if (freeze) {
      whiteningCompareBeforeIntensity = whiteningIntensity;
    } else {
      whiteningCompareBeforeIntensity = 0.0;
    }
    notifyListeners();
  }

  void setOverlayOpacity(double val) {
    overlayOpacity = val;
    notifyListeners();
  }

  void setSelectedPatient(int idx) {
    selectedPatientIndex = idx;
    notifyListeners();
  }

  void setRealToothScanEnabled(bool enabled) {
    realToothScanEnabled = enabled;
    if (!enabled) {
      liveToothScan = null;
      toothScanStatus = 'Real tooth scan is off';
    } else if (toothScanEndpoint.trim().isEmpty) {
      toothScanStatus = 'Add a backend URL to enable real scanning';
    }
    notifyListeners();
  }

  void setToothScanEndpoint(String endpoint) {
    toothScanEndpoint = endpoint.trim();
    if (toothScanEndpoint.isEmpty) {
      liveToothScan = null;
      toothScanStatus = realToothScanEnabled
          ? 'Add a backend URL to enable real scanning'
          : 'Real tooth scan is off';
    } else {
      toothScanStatus = realToothScanEnabled
          ? 'Ready to scan from backend'
          : 'Backend saved';
    }
    notifyListeners();
  }

  void setLiveToothScan(ToothScanResult? result) {
    liveToothScan = result;
    lastToothScanAt = DateTime.now();
    toothScanStatus = (result == null || !result.hasDetections)
        ? 'No teeth detected from backend'
        : 'Detected ${result.teeth.length} teeth';
    notifyListeners();
  }

  void setToothScanStatus(String status) {
    toothScanStatus = status;
    notifyListeners();
  }

  void clearLiveToothScan() {
    liveToothScan = null;
    if (realToothScanConfigured) {
      toothScanStatus = 'Ready to scan from backend';
    }
    notifyListeners();
  }

  void saveArSession() {
    final p = selectedPatient;
    p.arSessions++;
    p.lastArMode = currentArMode.label;
    p.history.insert(
      0,
      TreatmentRecord(
        date: 'Today',
        description: 'AR ${currentArMode.label} Session',
        arMode: currentArMode.label,
      ),
    );
    notifyListeners();
  }
}
