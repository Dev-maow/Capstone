// lib/screens/patients_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_data.dart';
import '../utils/theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsScreenState();
}

class _PatientsScreenState extends State<PatientsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final filtered = data.patients
        .where((p) => p.name.toLowerCase().contains(_query.toLowerCase()) ||
            p.procedure.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.shellTop,
      appBar: AppBar(
        title: const Text('Patients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Colors.white),
            onPressed: () => _showAddPatientSheet(context, data),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search patients…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // Patient count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} patient${filtered.length != 1 ? 's' : ''}',
                  style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),

          // Patient list
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No patients found',
                            style: GoogleFonts.dmSans(fontSize: 16, color: Colors.grey[400])),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: filtered.length,
                    itemBuilder: (ctx, i) => _PatientCard(
                      patient: filtered[i],
                      onTap: () => _showPatientDetail(context, filtered[i], data),
                      onArTap: () {
                        final idx = data.patients.indexOf(filtered[i]);
                        data.setSelectedPatient(idx);
                        DefaultTabController.of(context);
                        // Navigate to AR tab
                        Navigator.of(context).pop();
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddPatientSheet(context, data),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showPatientDetail(BuildContext context, Patient patient, AppData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.92,
        builder: (_, ctrl) => PatientDetailSheet(patient: patient, data: data, scrollController: ctrl),
      ),
    );
  }

  void _showAddPatientSheet(BuildContext context, AppData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddPatientSheet(data: data),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PATIENT CARD
// ─────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final Patient patient;
  final VoidCallback onTap;
  final VoidCallback? onArTap;

  const _PatientCard({required this.patient, required this.onTap, this.onArTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        elevation: 0,
        shadowColor: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: AppTheme.glassCard(
                radius: BorderRadius.circular(20),
                tint: patient.avatarBg.withOpacity(0.22),
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    PatientAvatar(patient: patient, size: 50),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patient.name,
                              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
                          Text(patient.procedure,
                              style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[500])),
                          Text('Last visit: ${patient.lastVisit}',
                              style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[400])),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Chip(
                      label: 'Active',
                      color: AppTheme.success,
                      bgColor: AppTheme.successContainer,
                      icon: Icons.check_circle_rounded,
                    ),
                    const SizedBox(width: 8),
                    _Chip(
                      label: '✨ ${patient.arSessions} AR sessions',
                      color: AppTheme.primary,
                      bgColor: AppTheme.primaryContainer,
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: onArTap,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Start AR →',
                        style: GoogleFonts.dmSans(
                            fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final IconData? icon;

  const _Chip({required this.label, required this.color, required this.bgColor, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [bgColor, Colors.white.withOpacity(0.72)],
        ),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PATIENT DETAIL SHEET
// ─────────────────────────────────────────────
class PatientDetailSheet extends StatelessWidget {
  final Patient patient;
  final AppData data;
  final ScrollController scrollController;

  const PatientDetailSheet({
    super.key, required this.patient,
    required this.data, required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12),
              width: 32, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                PatientAvatar(patient: patient, size: 64),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(patient.name,
                          style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700)),
                      Text(patient.procedure,
                          style: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey[500])),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _Chip(
                            label: 'Age ${patient.age}',
                            color: Colors.grey[700]!,
                            bgColor: Colors.grey[100]!,
                          ),
                          const SizedBox(width: 6),
                          _Chip(
                            label: '✨ ${patient.arSessions} AR',
                            color: AppTheme.primary,
                            bgColor: AppTheme.primaryContainer,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Info section
          _DetailSection(
            title: 'Patient Info',
            child: Column(
              children: [
                _InfoRow(label: 'Contact', value: patient.contact),
                _InfoRow(label: 'Last Visit', value: patient.lastVisit),
                _InfoRow(label: 'Next Visit', value: patient.nextVisit),
                _InfoRow(label: 'Last AR Mode', value: patient.lastArMode),
              ],
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final idx = data.patients.indexOf(patient);
                      data.setSelectedPatient(idx);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Navigate to AR tab to start session'),
                          backgroundColor: Color(0xFF323232),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                    label: const Text('Start AR Session'),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                  child: const Icon(Icons.edit_rounded, size: 18),
                ),
              ],
            ),
          ),

          // Treatment history
          _DetailSection(
            title: 'Treatment History',
            child: Column(
              children: patient.history.asMap().entries.map((e) => TimelineItem(
                record: e.value,
                isFirst: e.key == 0,
                isLast: e.key == patient.history.length - 1,
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.dmSans(
                fontSize: 12, fontWeight: FontWeight.w700,
                color: Colors.grey[500], letterSpacing: 0.6),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[500])),
          Text(value, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ADD PATIENT SHEET
// ─────────────────────────────────────────────
class _AddPatientSheet extends StatefulWidget {
  final AppData data;
  const _AddPatientSheet({required this.data});

  @override
  State<_AddPatientSheet> createState() => _AddPatientSheetState();
}

class _AddPatientSheetState extends State<_AddPatientSheet> {
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  String _procedure = 'Teeth Whitening';

  final _procedures = [
    'Teeth Whitening', 'Braces Consultation', 'Dental Cleaning',
    'Veneers', 'Extraction', 'Root Canal', 'Other',
  ];

  final _colors = [
    [const Color(0xFF1565C0), const Color(0xFFE3F2FD)],
    [const Color(0xFF2E7D32), const Color(0xFFE8F5E9)],
    [const Color(0xFFE65100), const Color(0xFFFFF3E0)],
    [const Color(0xFF4527A0), const Color(0xFFEDE7F6)],
    [const Color(0xFF880E4F), const Color(0xFFFCE4EC)],
  ];

  @override
  void dispose() {
    _nameCtrl.dispose(); _ageCtrl.dispose(); _contactCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 32, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('New Patient', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full Name')),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(controller: _ageCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Age')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(controller: _contactCtrl, keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Contact')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _procedure,
            decoration: const InputDecoration(labelText: 'Procedure'),
            items: _procedures.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
            onChanged: (v) => setState(() => _procedure = v!),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _addPatient,
                  child: const Text('Add Patient'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _addPatient() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    final ci = widget.data.patients.length % _colors.length;
    widget.data.addPatient(Patient(
      id: 'p${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      age: int.tryParse(_ageCtrl.text) ?? 0,
      contact: _contactCtrl.text.trim().isEmpty ? 'N/A' : _contactCtrl.text.trim(),
      procedure: _procedure,
      lastVisit: 'N/A',
      nextVisit: 'TBD',
      avatarColor: _colors[ci][0],
      avatarBg: _colors[ci][1],
      history: [TreatmentRecord(date: 'Today', description: 'Patient registered')],
    ));
    Navigator.pop(context);
  }
}
