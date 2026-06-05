import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../data/services/location_provider.dart';
import '../../theme/theme.dart';
import '../../widgets/widgets.dart';
import '../../widgets/location_picker_sheet.dart';

class SavedAddressesScreen extends StatefulWidget {
  const SavedAddressesScreen({super.key});

  @override
  State<SavedAddressesScreen> createState() => _SavedAddressesScreenState();
}

class _SavedAddressesScreenState extends State<SavedAddressesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<LocationProvider>().fetchSavedAddresses());
  }

  void _addNew() async {
    final loc = await showLocationPicker(context);
    if (loc != null && mounted) {
      context.read<LocationProvider>().save(loc);
      showMsg(context, 'Address saved successfully!', ok: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = context.watch<LocationProvider>();
    final addresses = lp.locations;

    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        title: Text('Saved Addresses', style: p(17, w: FontWeight.w800, color: C.t1)),
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: C.t1),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: C.divider),
          Expanded(
            child: addresses.isEmpty
                ? _buildEmptyState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                    itemCount: addresses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AddressTile(
                      loc: addresses[i],
                      onDelete: () => _confirmDelete(i),
                      onSelect: () {
                        lp.selectIndex(i);
                        showMsg(context, 'Primary address updated', ok: true);
                      },
                      isDefault: lp.location == addresses[i],
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        backgroundColor: Color(0xFF052B11),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: Text('Add New Address', style: p(14, w: FontWeight.w700, color: Colors.white)),
      ).animate().scale(delay: 300.ms, curve: Curves.easeOutBack),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100, height: 100,
            decoration: BoxDecoration(color: C.forest.withOpacity(0.06), shape: BoxShape.circle),
            child: Icon(Icons.location_on_outlined, size: 48, color: C.forest.withOpacity(0.4)),
          ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 20),
          Text('No Saved Addresses', style: p(18, w: FontWeight.w800, color: C.t1)),
          const SizedBox(height: 8),
          Text('Add your home or office address to\nspeed up your checkout process.',
            style: p(14, color: C.t3, h: 1.5), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(int index) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Address?', style: p(17, w: FontWeight.w700, color: C.t1)),
        content: Text('Are you sure you want to remove this address?', style: p(14, color: C.t3)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: p(14, color: C.t3))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete', style: p(14, w: FontWeight.w700, color: C.red))),
        ],
      ),
    );
    if (ok == true && mounted) {
      context.read<LocationProvider>().remove(index);
      showMsg(context, 'Address removed');
    }
  }
}

class _AddressTile extends StatelessWidget {
  final PickedLocation loc;
  final VoidCallback onDelete, onSelect;
  final bool isDefault;

  const _AddressTile({
    required this.loc,
    required this.onDelete,
    required this.onSelect,
    required this.isDefault,
  });

  @override
  Widget build(BuildContext context) {
    return GCard(
      onTap: onSelect,
      padding: const EdgeInsets.all(16),
      bg: isDefault ? C.forest.withOpacity(0.04) : Colors.white,
      bordered: !isDefault,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDefault ? C.forest : C.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isDefault ? Icons.check_circle_rounded : Icons.location_on_rounded,
              size: 20,
              color: isDefault ? Colors.white : C.forest,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        loc.displayLabel,
                        style: p(15, w: FontWeight.w800, color: C.t1),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: C.forest, borderRadius: BorderRadius.circular(6)),
                        child: Text('DEFAULT', style: p(9, w: FontWeight.w800, color: Colors.white, ls: 0.5)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  loc.fullAddress,
                  style: p(13, color: C.t3, h: 1.4),
                  maxLines: 2, overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 22, color: C.t4),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }
}
