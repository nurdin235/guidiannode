import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/emergency_models.dart';
import '../utils/formatters.dart';

class DashboardAlertsTab extends StatefulWidget {
  const DashboardAlertsTab({
    super.key,
    required this.nearbyAlerts,
    required this.isLoadingAlerts,
    required this.alertsError,
    required this.onRefresh,
    required this.onOpenAlert,
  });

  final List<EmergencyAlert> nearbyAlerts;
  final bool isLoadingAlerts;
  final String? alertsError;
  final Future<void> Function() onRefresh;
  final void Function(EmergencyAlert alert) onOpenAlert;

  @override
  State<DashboardAlertsTab> createState() => _DashboardAlertsTabState();
}

class _DashboardAlertsTabState extends State<DashboardAlertsTab> {
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    final visibleAlerts = switch (_selectedTab) {
      0 => widget.nearbyAlerts,
      1 => const <EmergencyAlert>[],
      _ => widget.nearbyAlerts,
    };

    return Scaffold(
      backgroundColor: AppColors.cleanWhite,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: widget.onRefresh,
          child: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              GuardianAppBar(
                title: 'Community Alerts',
                showLogo: true,
                actions: [
                  IconButton(
                    tooltip: 'Filter',
                    onPressed: widget.onRefresh,
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              SegmentedTabs(
                tabs: const ['Nearby', 'Following', 'All'],
                selectedIndex: _selectedTab,
                onChanged: (index) => setState(() => _selectedTab = index),
              ),
              if (widget.alertsError != null) ...[
                const SizedBox(height: AppSpacing.md),
                WarningBanner(
                  title: 'Nearby alerts issue',
                  message: widget.alertsError!,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              if (widget.isLoadingAlerts)
                const LoadingCardList(count: 4)
              else if (visibleAlerts.isEmpty)
                EmptyState(
                  title: _selectedTab == 1
                      ? 'No followed alerts'
                      : 'No community alerts',
                  message: _selectedTab == 1
                      ? 'Alerts you follow will appear here when that backend support is available.'
                      : 'When SOS activity appears in your radius, it will surface here.',
                  actionLabel: 'Refresh now',
                  onAction: widget.onRefresh,
                )
              else
                ...visibleAlerts.map(
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
                      onAction: () => widget.onOpenAlert(alert),
                    ),
                  ),
                ),
            ],
          ),
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
