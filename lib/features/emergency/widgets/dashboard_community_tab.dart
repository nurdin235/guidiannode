import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/emergency_models.dart';
import '../utils/formatters.dart';

class DashboardCommunityTab extends StatefulWidget {
  const DashboardCommunityTab({
    super.key,
    required this.nearbyAlerts,
    required this.onOpenAlert,
    required this.onOpenProfile,
    required this.onOpenMap,
  });

  final List<EmergencyAlert> nearbyAlerts;
  final void Function(EmergencyAlert alert) onOpenAlert;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenMap;

  @override
  State<DashboardCommunityTab> createState() => _DashboardCommunityTabState();
}

class _DashboardCommunityTabState extends State<DashboardCommunityTab> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final alerts = switch (_selectedTab) {
      1 =>
        widget.nearbyAlerts
            .where((alert) => !alert.status.toLowerCase().contains('resolved'))
            .toList(),
      2 =>
        widget.nearbyAlerts
            .where((alert) => alert.status.toLowerCase().contains('resolved'))
            .toList(),
      _ => widget.nearbyAlerts,
    };

    return Scaffold(
      backgroundColor: AppColors.cleanWhite,
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            GuardianAppBar(
              title: 'Emergency History',
              showLogo: true,
              actions: [
                IconButton(
                  tooltip: 'Profile',
                  onPressed: widget.onOpenProfile,
                  icon: const Icon(Icons.person_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            SegmentedTabs(
              tabs: const ['All', 'Active', 'Resolved'],
              selectedIndex: _selectedTab,
              onChanged: (index) => setState(() => _selectedTab = index),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (alerts.isEmpty)
              EmptyState(
                title: _selectedTab == 2
                    ? 'No resolved incidents'
                    : 'No emergency history yet',
                message:
                    'Your alerts and nearby incidents will appear here once available from the current feed.',
                icon: Icons.history_rounded,
              )
            else
              ...alerts.map(
                (alert) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: AlertCard(
                    title: formatEmergencyType(alert.emergencyType),
                    subtitle: alert.displayAddress,
                    distance: formatDistance(alert.distanceMeters),
                    time: formatRelativeTime(
                      alert.updatedAt ?? alert.createdAt,
                    ),
                    statusLabel: alert.status.toUpperCase(),
                    tone: _toneForStatus(alert.status),
                    onTap: () => widget.onOpenAlert(alert),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  StatusTone _toneForStatus(String status) {
    final normalized = status.toLowerCase();
    if (normalized.contains('resolved')) {
      return StatusTone.success;
    }
    if (normalized.contains('caution') || normalized.contains('pending')) {
      return StatusTone.warning;
    }
    return StatusTone.action;
  }
}
