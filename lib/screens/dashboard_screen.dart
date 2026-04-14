import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/models.dart';
import '../utils/app_data.dart';
import '../utils/theme.dart';
import '../widgets/widgets.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.appBackground),
        child: SafeArea(
          bottom: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 110),
            children: [
              _DashboardHero(data: data),
              const SizedBox(height: 18),
              Text(
                'Overview',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.onSurfaceVariant,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.02,
                children: [
                  _MetricCard(
                    label: 'Patients this month',
                    value: '${data.patients.length + 19}',
                    icon: Icons.people_alt_rounded,
                    color: AppTheme.primary,
                    accent: const Color(0xFFE8F0FF),
                  ),
                  _MetricCard(
                    label: 'AR sessions today',
                    value: '11',
                    icon: Icons.auto_fix_high_rounded,
                    color: const Color(0xFF0F9D7A),
                    accent: const Color(0xFFE4FBF4),
                  ),
                  _MetricCard(
                    label: 'Inventory items',
                    value: '${data.inventory.length}',
                    icon: Icons.inventory_2_rounded,
                    color: const Color(0xFF2F7A47),
                    accent: const Color(0xFFEAF7EF),
                  ),
                  _MetricCard(
                    label: 'Active alerts',
                    value: '${data.totalAlerts}',
                    icon: Icons.warning_amber_rounded,
                    color: data.totalAlerts > 0 ? AppTheme.warning : AppTheme.success,
                    accent: data.totalAlerts > 0
                        ? const Color(0xFFFFF4DD)
                        : const Color(0xFFE7FAF1),
                  ),
                ],
              ),
              if (data.expiredItems.isNotEmpty || data.expiringItems.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'Clinic alerts',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurfaceVariant,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (data.expiredItems.isNotEmpty)
                AlertBanner(
                  title: '${data.expiredItems.length} material${data.expiredItems.length > 1 ? 's have' : ' has'} expired',
                  subtitle: data.expiredItems.map((i) => i.name).take(3).join(', '),
                  color: AppTheme.error,
                  bgColor: AppTheme.errorContainer,
                  icon: Icons.error_outline_rounded,
                ),
              if (data.expiringItems.isNotEmpty)
                AlertBanner(
                  title: '${data.expiringItems.length} item${data.expiringItems.length > 1 ? 's are' : ' is'} expiring soon',
                  subtitle: data.expiringItems.map((i) => i.name).take(3).join(', '),
                  color: AppTheme.warning,
                  bgColor: AppTheme.warningContainer,
                  icon: Icons.schedule_rounded,
                ),
              SectionHeader(
                title: "TODAY'S APPOINTMENTS",
                actionLabel: 'View all',
                onAction: () {},
              ),
              ...data.patients.take(4).toList().asMap().entries.map(
                    (entry) => _AppointmentTile(
                      patient: entry.value,
                      index: entry.key,
                    ),
                  ),
              SectionHeader(title: 'INVENTORY HEALTH'),
              _InventoryHealthCard(data: data),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHero extends StatelessWidget {
  final AppData data;

  const _DashboardHero({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF07111D), Color(0xFF123D92), Color(0xFF1B73FF)],
          stops: [0.0, 0.5, 1.0],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF11347A).withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -42,
            right: -34,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -56,
            left: -10,
            child: Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.18)),
                    ),
                    child: Center(
                      child: Text(
                        'DL',
                        style: GoogleFonts.dmSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DentaLogic',
                          style: GoogleFonts.dmSans(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.6,
                          ),
                        ),
                        Text(
                          'Good morning, Dr. Reyes',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.74),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HeroAction(icon: Icons.notifications_none_rounded, hasBadge: data.totalAlerts > 0),
                  const SizedBox(width: 8),
                  const _HeroAction(icon: Icons.account_circle_outlined),
                ],
              ),
              const SizedBox(height: 22),
              Text(
                'You have a healthy clinic day ahead. Review appointments, monitor stock, and keep AR sessions moving.',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  height: 1.5,
                  color: Colors.white.withOpacity(0.82),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _HeroStatCard(label: 'Today', value: '8', subtitle: 'appointments'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroStatCard(label: 'AR', value: '11', subtitle: 'sessions'),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _HeroStatCard(label: 'Alerts', value: '${data.totalAlerts}', subtitle: 'active'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroAction extends StatelessWidget {
  final IconData icon;
  final bool hasBadge;

  const _HeroAction({required this.icon, this.hasBadge = false});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.14)),
          ),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        if (hasBadge)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Color(0xFFFFC04D),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _HeroStatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;

  const _HeroStatCard({
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white.withOpacity(0.72),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.dmSans(
              fontSize: 11,
              color: Colors.white.withOpacity(0.56),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color accent;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Color(0xFFF8FBFF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.90)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1726).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: color,
              height: 1,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppTheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentTile extends StatelessWidget {
  final Patient patient;
  final int index;

  const _AppointmentTile({required this.patient, required this.index});

  @override
  Widget build(BuildContext context) {
    const times = ['9:00 AM', '10:30 AM', '2:00 PM', '4:00 PM'];
    final time = index < times.length ? times[index] : '5:00 PM';
    final isPending = index == 2;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassCard(radius: BorderRadius.circular(22)),
      child: Row(
        children: [
          PatientAvatar(patient: patient, size: 48),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  patient.procedure,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppTheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isPending ? AppTheme.warningContainer : AppTheme.successContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPending ? 'Pending' : 'Confirmed',
                  style: GoogleFonts.dmSans(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isPending ? AppTheme.warning : AppTheme.success,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InventoryHealthCard extends StatelessWidget {
  final AppData data;

  const _InventoryHealthCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.inventory.length;
    final ok = data.inventory.where((i) => i.status == ExpiryStatus.ok).length;
    final warn = data.expiringItems.length;
    final expired = data.expiredItems.length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(18),
      decoration: AppTheme.glassCard(radius: BorderRadius.circular(24)),
      child: Column(
        children: [
          _HealthRow(
            label: 'Stock OK',
            value: ok,
            total: total,
            color: AppTheme.success,
          ),
          const SizedBox(height: 14),
          _HealthRow(
            label: 'Expiring Soon',
            value: warn,
            total: total,
            color: AppTheme.warning,
          ),
          const SizedBox(height: 14),
          _HealthRow(
            label: 'Expired',
            value: expired,
            total: total,
            color: AppTheme.error,
          ),
        ],
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;

  const _HealthRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : value / total;

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 8,
              backgroundColor: const Color(0xFFE8EEF8),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '$value',
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
