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
      backgroundColor: Colors.transparent,
      body: CustomScrollView(slivers: [
        SliverToBoxAdapter(child: VPageHeader(
          title: 'Addresses',
          subtitle: 'Tap an address to make it your primary one.',
          trailing: VPillAction(label: 'Add address', onTap: _addNew),
        )),
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        if (addresses.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: GEmpty(
            title: 'No saved addresses',
            sub: 'Add your home or office so booking and checkout are quicker.',
            icon: Icons.location_on_outlined,
            action: GBtn(label: 'Add address', onTap: _addNew, w: 200, h: 48)))
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 32),
            sliver: SliverList(delegate: SliverChildBuilderDelegate((_, i) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _AddressTile(
                loc: addresses[i],
                onDelete: () => _confirmDelete(i),
                onSelect: () {
                  lp.selectIndex(i);
                  showMsg(context, 'Primary address updated', ok: true);
                },
                isDefault: lp.location == addresses[i],
              ),
            ), childCount: addresses.length)),
          ),
      ]),
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

  IconData get _icon {
    final l = loc.displayLabel.toLowerCase();
    if (l.contains('home')) return Icons.home_outlined;
    if (l.contains('office') || l.contains('work')) return Icons.work_outline_rounded;
    return Icons.location_on_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final body = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      VOrb(icon: _icon, size: 44, dark: !isDefault),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Flexible(child: Text(loc.displayLabel, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: vx(17, w: FontWeight.w600, color: isDefault ? Colors.white : V.ink))),
          if (isDefault) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(color: V.lime, borderRadius: BorderRadius.circular(99)),
              child: Text('Primary', style: p(10.5, w: FontWeight.w600, color: V.ink)),
            ),
          ],
        ]),
        const SizedBox(height: 4),
        Text(loc.fullAddress, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: p(12.5, color: isDefault ? Colors.white.withValues(alpha: 0.7) : V.fog, h: 1.4)),
      ])),
      const SizedBox(width: 6),
      GestureDetector(
        onTap: onDelete,
        child: Padding(padding: const EdgeInsets.all(4),
          child: Icon(Icons.delete_outline_rounded, size: 21, color: isDefault ? Colors.white54 : V.fog)),
      ),
    ]);
    return GestureDetector(
      onTap: onSelect,
      child: isDefault
        ? VPod(radius: 22, padding: const EdgeInsets.all(16), child: body)
        : GCard(padding: const EdgeInsets.all(16), radius: BorderRadius.circular(22), child: body),
    ).animate().fadeIn().slideY(begin: 0.05, end: 0);
  }
}
