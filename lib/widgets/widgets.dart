// lib/widgets/widgets.dart

import 'package:flutter/material.dart';
import '../models/models.dart';
import '../utils/theme.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// PATIENT AVATAR
// ─────────────────────────────────────────────
class PatientAvatar extends StatelessWidget {
  final Patient patient;
  final double size;

  const PatientAvatar({super.key, required this.patient, this.size = 48});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            patient.avatarBg,
            Colors.white.withOpacity(0.72),
          ],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.85)),
        boxShadow: [
          BoxShadow(
            color: patient.avatarColor.withOpacity(0.14),
            blurRadius: size * 0.28,
            offset: Offset(0, size * 0.10),
          ),
        ],
      ),
      child: Center(
        child: Text(
          patient.initials,
          style: GoogleFonts.dmSans(
            fontSize: size * 0.35,
            fontWeight: FontWeight.w700,
            color: patient.avatarColor,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// EXPIRY STATUS BADGE
// ─────────────────────────────────────────────
class ExpiryBadge extends StatelessWidget {
  final InventoryItem item;

  const ExpiryBadge({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: item.statusBgColor,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        item.expiryLabel,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: item.statusColor,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// STAT CARD
// ─────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.glassCard(
          radius: BorderRadius.circular(18),
          tint: bgColor.withOpacity(0.16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.dmSans(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: AppTheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SECTION HEADER
// ─────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.onSurfaceVariant,
              letterSpacing: 0.6,
            ),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                actionLabel!,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// ALERT BANNER
// ─────────────────────────────────────────────
class AlertBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final VoidCallback? onTap;

  const AlertBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.bgColor,
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              bgColor.withOpacity(0.95),
              Colors.white.withOpacity(0.86),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.14)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.dmSans(
                          fontSize: 14, fontWeight: FontWeight.w600, color: color)),
                  Text(subtitle,
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: color.withOpacity(0.8))),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: color, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// AR MODE CHIP
// ─────────────────────────────────────────────
class ArModeChip extends StatelessWidget {
  final ArMode mode;
  final bool isSelected;
  final VoidCallback onTap;

  const ArModeChip({
    super.key,
    required this.mode,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isSelected
                ? [
                    const Color(0xFF2A8CFF),
                    AppTheme.primary,
                  ]
                : [
                    Colors.white.withOpacity(0.96),
                    const Color(0xFFF3F7FD),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.primary : Colors.grey[300]!,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: (isSelected ? AppTheme.primary : Colors.black).withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(mode.emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              mode.label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[800],
              ),
            ),
            Text(
              mode.description,
              style: GoogleFonts.dmSans(
                fontSize: 10,
                color: isSelected ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// INVENTORY CATEGORY ICON
// ─────────────────────────────────────────────
class CategoryIconBox extends StatelessWidget {
  final InventoryCategory category;
  final double size;

  const CategoryIconBox({super.key, required this.category, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            category.bgColor,
            Colors.white.withOpacity(0.84),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.88)),
      ),
      child: Icon(category.icon, color: category.color, size: size * 0.48),
    );
  }
}

// ─────────────────────────────────────────────
// TREATMENT TIMELINE ITEM
// ─────────────────────────────────────────────
class TimelineItem extends StatelessWidget {
  final TreatmentRecord record;
  final bool isFirst;
  final bool isLast;

  const TimelineItem({
    super.key,
    required this.record,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[200],
                    ),
                  ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: record.arMode != null ? AppTheme.primary : Colors.grey[400],
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey[200],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.description,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    record.date,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                  if (record.arMode != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppTheme.primaryContainer,
                            Colors.white.withOpacity(0.88),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        '✨ AR ${record.arMode}',
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
