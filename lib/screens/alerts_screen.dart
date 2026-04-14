// lib/screens/alerts_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_data.dart';
import '../utils/theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final alerts = data.alertItems;

    return Scaffold(
      backgroundColor: AppTheme.shellTop,
      appBar: AppBar(
        title: const Text('Expiry Alerts'),
        actions: [
          if (alerts.isNotEmpty)
            TextButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('All alerts marked as reviewed'),
                    backgroundColor: const Color(0xFF323232),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                );
              },
              child: Text(
                'Mark all',
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ),
        ],
      ),
      body: alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('✅', style: TextStyle(fontSize: 56)),
                  const SizedBox(height: 16),
                  Text(
                    'No active alerts',
                    style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All inventory items are within safe\nexpiration windows.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: [
                // Summary banner
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: AppTheme.glassCard(
                    radius: BorderRadius.circular(20),
                    tint: AppTheme.primaryContainer.withOpacity(0.40),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_rounded,
                          color: AppTheme.onPrimaryContainer, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${alerts.length} alert${alerts.length != 1 ? 's' : ''} require attention',
                              style: GoogleFonts.dmSans(
                                  fontSize: 15, fontWeight: FontWeight.w700,
                                  color: AppTheme.onPrimaryContainer),
                            ),
                            Text(
                              'SMS notifications sent to Dr. Reyes',
                              style: GoogleFonts.dmSans(
                                  fontSize: 12, color: AppTheme.onPrimaryContainer.withOpacity(0.7)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Expired section
                if (data.expiredItems.isNotEmpty) ...[
                  _SectionLabel(
                    label: 'EXPIRED',
                    count: data.expiredItems.length,
                    color: AppTheme.error,
                  ),
                  const SizedBox(height: 8),
                  ...data.expiredItems.map((item) => _AlertCard(item: item)),
                  const SizedBox(height: 16),
                ],

                // Expiring soon section
                if (data.expiringItems.isNotEmpty) ...[
                  _SectionLabel(
                    label: 'EXPIRING SOON',
                    count: data.expiringItems.length,
                    color: AppTheme.warning,
                  ),
                  const SizedBox(height: 8),
                  ...data.expiringItems.map((item) => _AlertCard(item: item)),
                ],
              ],
            ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _SectionLabel({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4, height: 16,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: color, letterSpacing: 0.6),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ),
      ],
    );
  }
}

class _AlertCard extends StatelessWidget {
  final InventoryItem item;

  const _AlertCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final isExpired = item.status == ExpiryStatus.expired;
    final borderColor = isExpired ? AppTheme.error : AppTheme.warning;
    final bgColor = isExpired ? AppTheme.errorContainer : AppTheme.warningContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgColor,
            Colors.white.withOpacity(0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIconBox(category: item.category, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name,
                          style: GoogleFonts.dmSans(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: isExpired ? AppTheme.error : AppTheme.warning)),
                      Text(
                        '${item.category.label} · Batch: ${item.batchNumber}',
                        style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
                ExpiryBadge(item: item),
              ],
            ),
            const SizedBox(height: 12),
            // Details row
            Row(
              children: [
                _DetailPill(icon: Icons.inventory_2_rounded,
                    label: 'Qty: ${item.quantity}', color: Colors.grey[700]!),
                const SizedBox(width: 8),
                _DetailPill(icon: Icons.calendar_today_rounded,
                    label: item.expiryDate.toIso8601String().split('T')[0],
                    color: Colors.grey[700]!),
              ],
            ),
            const SizedBox(height: 10),
            // SMS sent indicator
            Row(
              children: [
                Icon(Icons.sms_rounded, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 4),
                Text(
                  'SMS alert sent · System notification triggered',
                  style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {},
                    icon: Icon(Icons.add_shopping_cart_rounded, size: 16,
                        color: isExpired ? AppTheme.error : AppTheme.warning),
                    label: const Text('Reorder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isExpired ? AppTheme.error : AppTheme.warning,
                      side: BorderSide(color: borderColor.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Resolve'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isExpired ? AppTheme.error : AppTheme.warning,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DetailPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
