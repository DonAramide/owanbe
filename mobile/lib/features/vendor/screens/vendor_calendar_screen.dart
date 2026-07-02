import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../eos/eos.dart';

class VendorCalendarScreen extends ConsumerStatefulWidget {
  const VendorCalendarScreen({super.key});

  @override
  ConsumerState<VendorCalendarScreen> createState() => _VendorCalendarScreenState();
}

class _VendorCalendarScreenState extends ConsumerState<VendorCalendarScreen> {
  bool _vacationMode = false;
  final List<String> _blackoutDates = ['2026-07-15', '2026-07-20'];

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark(),
      child: Scaffold(
        backgroundColor: EosColors.plumDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'Schedule & Availability',
            style: context.eosText.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Vacation Mode Switch
            Card(
              color: Colors.white.withOpacity(0.02),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white10),
              ),
              child: SwitchListTile(
                title: const Text('Vacation Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Temporarily pause new incoming client requests'),
                value: _vacationMode,
                onChanged: (val) {
                  setState(() {
                    _vacationMode = val;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Vacation mode ${_vacationMode ? "enabled" : "disabled"}.')),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Blackout Calendar slots list
            const Text('BLACKOUT DATES & BOOKING CONFLICTS', style: TextStyle(color: EosColors.champagne, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            for (final date in _blackoutDates)
              Card(
                color: Colors.white.withOpacity(0.02),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.white10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.block, color: Colors.redAccent),
                  title: Text('July ${date.split("-").last}nd, 2026'),
                  subtitle: const Text('Reason: Fully booked for corporate gala'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white54),
                    onPressed: () {
                      setState(() {
                        _blackoutDates.remove(date);
                      });
                    },
                  ),
                ),
              ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _blackoutDates.add('2026-07-28');
                });
              },
              child: const Text('Add Blackout Date'),
            ),
          ],
        ),
      ),
    );
  }
}
