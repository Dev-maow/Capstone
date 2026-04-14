// lib/screens/inventory_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/app_data.dart';
import '../utils/theme.dart';
import '../models/models.dart';
import '../widgets/widgets.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  ExpiryStatus? _filter; // null = all

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = context.watch<AppData>();
    final filtered = data.inventory.where((item) {
      if (_filter != null && item.status != _filter) return false;
      if (_query.isNotEmpty &&
          !item.name.toLowerCase().contains(_query.toLowerCase()) &&
          !item.category.label.toLowerCase().contains(_query.toLowerCase())) {
        return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.shellTop,
      appBar: AppBar(
        title: const Text('Inventory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: Colors.white),
            onPressed: () => _showAddItemSheet(context, data),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Search materials…',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                      )
                    : null,
              ),
            ),
          ),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _FilterChip(label: 'All', icon: Icons.apps_rounded,
                    isActive: _filter == null, onTap: () => setState(() => _filter = null)),
                const SizedBox(width: 8),
                _FilterChip(label: 'OK', icon: Icons.check_circle_outline_rounded,
                    isActive: _filter == ExpiryStatus.ok,
                    onTap: () => setState(() => _filter = ExpiryStatus.ok),
                    color: AppTheme.success),
                const SizedBox(width: 8),
                _FilterChip(label: 'Expiring', icon: Icons.schedule_rounded,
                    isActive: _filter == ExpiryStatus.warning,
                    onTap: () => setState(() => _filter = ExpiryStatus.warning),
                    color: AppTheme.warning),
                const SizedBox(width: 8),
                _FilterChip(label: 'Expired', icon: Icons.cancel_outlined,
                    isActive: _filter == ExpiryStatus.expired,
                    onTap: () => setState(() => _filter = ExpiryStatus.expired),
                    color: AppTheme.error),
              ],
            ),
          ),

          // Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('${filtered.length} items',
                    style: GoogleFonts.dmSans(fontSize: 13, color: Colors.grey[500])),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_rounded, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text('No items found',
                            style: GoogleFonts.dmSans(fontSize: 16, color: Colors.grey[400])),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) => _InventoryTile(
                      item: filtered[i],
                      onDelete: () => data.removeInventoryItem(filtered[i].id),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddItemSheet(context, data),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _showAddItemSheet(BuildContext context, AppData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _AddItemSheet(data: data),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final Color? color;

  const _FilterChip({
    required this.label, required this.icon,
    required this.isActive, required this.onTap, this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isActive
                ? [
                    c.withOpacity(0.16),
                    Colors.white.withOpacity(0.88),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFF5F9FF),
                  ],
          ),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: isActive ? c : Colors.grey[300]!),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isActive ? c : Colors.grey[600]),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: isActive ? c : Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}

class _InventoryTile extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onDelete;

  const _InventoryTile({required this.item, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(0),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: AppTheme.glassCard(
            radius: BorderRadius.circular(18),
            tint: item.category.bgColor.withOpacity(0.18),
          ),
          child: Row(
          children: [
            CategoryIconBox(category: item.category),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    '${item.category.label} · ${item.batchNumber} · Qty: ${item.quantity}',
                    style: GoogleFonts.dmSans(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      ExpiryBadge(item: item),
                      const SizedBox(width: 8),
                      Text(
                        item.expiryDate.toIso8601String().split('T')[0],
                        style: GoogleFonts.dmSans(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 20),
              color: Colors.grey[400],
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text('Remove Item', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                    content: Text('Remove "${item.name}" from inventory?',
                        style: GoogleFonts.dmSans()),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                      ElevatedButton(
                        onPressed: () { Navigator.pop(ctx); onDelete(); },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _AddItemSheet extends StatefulWidget {
  final AppData data;
  const _AddItemSheet({required this.data});

  @override
  State<_AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<_AddItemSheet> {
  final _nameCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController();
  InventoryCategory _category = InventoryCategory.restorative;
  DateTime? _expiryDate;

  @override
  void dispose() {
    _nameCtrl.dispose(); _batchCtrl.dispose(); _qtyCtrl.dispose();
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
          Text('Add Inventory Item', style: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          TextField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Material Name')),
          const SizedBox(height: 12),
          DropdownButtonFormField<InventoryCategory>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: InventoryCategory.values.map((c) => DropdownMenuItem(
              value: c,
              child: Row(children: [
                Icon(c.icon, size: 16, color: c.color),
                const SizedBox(width: 8),
                Text(c.label),
              ]),
            )).toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(controller: _batchCtrl,
                    decoration: const InputDecoration(labelText: 'Batch No.')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(controller: _qtyCtrl, keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Quantity')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now().subtract(const Duration(days: 365)),
                lastDate: DateTime(2030),
              );
              if (d != null) setState(() => _expiryDate = d);
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Text(
                    _expiryDate == null
                        ? 'Select Expiry Date'
                        : _expiryDate!.toIso8601String().split('T')[0],
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: _expiryDate == null ? Colors.grey[500] : null,
                    ),
                  ),
                ],
              ),
            ),
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
                  onPressed: _addItem,
                  child: const Text('Add Item'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _addItem() {
    if (_nameCtrl.text.trim().isEmpty || _expiryDate == null) return;
    widget.data.addInventoryItem(InventoryItem(
      id: 'i${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      category: _category,
      batchNumber: _batchCtrl.text.trim().isEmpty ? 'N/A' : _batchCtrl.text.trim(),
      quantity: int.tryParse(_qtyCtrl.text) ?? 0,
      expiryDate: _expiryDate!,
    ));
    Navigator.pop(context);
  }
}
