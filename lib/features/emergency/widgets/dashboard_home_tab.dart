import 'package:flutter/material.dart';

import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/elevation.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/emergency_models.dart';
import '../services/emergency_coordinator.dart';
import '../utils/formatters.dart';

class DashboardHomeTab extends StatelessWidget {
  const DashboardHomeTab({
    super.key,
    required this.coordinator,
    required this.nearbyAlerts,
    required this.isLoadingAlerts,
    required this.alertsError,
    required this.onRefresh,
    required this.onToggleLocationSharing,
    required this.onTriggerSos,
    required this.onOpenMap,
    required this.onOpenProfile,
    required this.onOpenAlert,
    required this.onOpenActiveSos,
    required this.onOpenCategorySheet,
  });

  final EmergencyCoordinator coordinator;
  final List<EmergencyAlert> nearbyAlerts;
  final bool isLoadingAlerts;
  final String? alertsError;
  final Future<void> Function() onRefresh;
  final Future<void> Function(bool enabled) onToggleLocationSharing;
  final Future<void> Function(String emergencyType, {String? description})
  onTriggerSos;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenProfile;
  final void Function(EmergencyAlert alert) onOpenAlert;
  final VoidCallback onOpenActiveSos;
  final VoidCallback onOpenCategorySheet;

  @override
  Widget build(BuildContext context) {
    final currentUser = SessionService.currentUser;
    final fullName = currentUser?['full_name']?.toString() ?? 'Resident';
    final firstName = fullName.split(' ').first;
    final activeAlert = coordinator.activeAlert;
    final position = coordinator.currentPosition;
    final locationText = position?.displayAddress ?? 'Market Road, Bamenda';

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          _HomeHeader(
            firstName: firstName,
            activeAlert: activeAlert,
            onOpenProfile: onOpenProfile,
          ),
          Padding(
            padding: AppSpacing.screenPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LocationCard(
                  title: 'Current Location',
                  subtitle: locationText,
                  icon: Icons.location_on_rounded,
                  trailing: TextButton(
                    onPressed: coordinator.isUpdatingLocationSharing
                        ? null
                        : () => onToggleLocationSharing(true),
                    child: Text(
                      coordinator.locationSharingEnabled ? 'Change' : 'Enable',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (activeAlert != null)
                  StatusBanner.action(
                    title: 'Emergency active',
                    message:
                        'Your SOS is live and your location is still streaming.',
                  )
                else if (!coordinator.locationSharingEnabled)
                  StatusBanner.warning(
                    title: 'Location recommended',
                    message:
                        'Enable location sharing for faster routing and nearby alerts.',
                  ),
                if (activeAlert != null || !coordinator.locationSharingEnabled)
                  const SizedBox(height: AppSpacing.lg),
                Center(
                  child: SosButton(
                    onPressed: activeAlert == null
                        ? () => onTriggerSos('general_distress')
                        : onOpenActiveSos,
                    isBusy: coordinator.isTriggeringSos,
                    isSafeState: false,
                    label: 'SOS',
                    subtitle: 'TAP FOR HELP',
                  ),
                ),
                if (activeAlert != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  OutlineActionButton(
                    text: 'Open live SOS map',
                    icon: Icons.my_location_rounded,
                    onPressed: onOpenActiveSos,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Quick Actions',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: QuickActionTile(
                        label: 'Call Emergency',
                        icon: Icons.call_rounded,
                        color: AppColors.safetyGreen,
                        // TODO: Connect to a verified emergency dialer when the backend/product flow defines one.
                        onTap: onOpenCategorySheet,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: QuickActionTile(
                        label: 'Trusted Contacts',
                        icon: Icons.groups_rounded,
                        color: AppColors.engagementOrange,
                        onTap: onOpenProfile,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: QuickActionTile(
                        label: 'Report Incident',
                        icon: Icons.warning_amber_rounded,
                        color: AppColors.communityYellow,
                        onTap: onOpenCategorySheet,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: QuickActionTile(
                        label: 'Safe Places',
                        icon: Icons.location_on_rounded,
                        color: AppColors.trustBlue,
                        onTap: onOpenMap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Nearby alerts',
                        value: '${nearbyAlerts.length}',
                        helper: 'Around Bamenda',
                        tone: nearbyAlerts.isEmpty
                            ? StatusTone.info
                            : StatusTone.error,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: StatTile(
                        label: 'Live status',
                        value: activeAlert == null ? 'Ready' : 'Active',
                        helper: activeAlert == null ? 'Standby' : 'Streaming',
                        tone: activeAlert == null
                            ? StatusTone.success
                            : StatusTone.action,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                const SectionHeader(
                  title: 'Recent activity',
                  subtitle:
                      'Nearby emergency activity from the GuardianNode feed.',
                ),
                const SizedBox(height: AppSpacing.md),
                if (isLoadingAlerts)
                  const LoadingCardList(count: 2)
                else if (nearbyAlerts.isEmpty)
                  EmptyState(
                    title: 'No nearby incidents right now',
                    message:
                        alertsError ??
                        'GuardianNode will keep listening for realtime alerts around you.',
                    actionLabel: 'Refresh nearby alerts',
                    onAction: onRefresh,
                  )
                else
                  ...nearbyAlerts
                      .take(2)
                      .map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AlertCard(
                            title: formatEmergencyType(alert.emergencyType),
                            subtitle: alert.displayAddress,
                            distance: formatDistance(alert.distanceMeters),
                            time: formatRelativeTime(
                              alert.updatedAt ?? alert.createdAt,
                            ),
                            onTap: () => onOpenAlert(alert),
                            onAction: () => onOpenAlert(alert),
                          ),
                        ),
                      ),
                const SizedBox(height: AppSpacing.xl),
                const SafeZoneCard(
                  locationName: 'Regional Hospital Bamenda',
                  distance: '2.4 km',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.firstName,
    required this.activeAlert,
    required this.onOpenProfile,
  });

  final String firstName;
  final EmergencyAlert? activeAlert;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.trustBlue,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const GuardianLogo(
                    size: 46,
                    onDark: true,
                    padding: EdgeInsets.all(3),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Good morning,\n$firstName',
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: AppColors.cleanWhite,
                            fontWeight: FontWeight.w900,
                            height: 1.08,
                          ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Notifications',
                    onPressed: () {},
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      color: AppColors.cleanWhite,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Profile',
                    onPressed: onOpenProfile,
                    icon: const Icon(
                      Icons.account_circle_outlined,
                      color: AppColors.cleanWhite,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.cleanWhite.withValues(alpha: 0.12),
                  borderRadius: AppRadii.card,
                  border: Border.all(
                    color: AppColors.cleanWhite.withValues(alpha: 0.18),
                  ),
                  boxShadow: AppElevation.soft,
                ),
                child: Row(
                  children: [
                    Icon(
                      activeAlert == null
                          ? Icons.verified_user_rounded
                          : Icons.sos_rounded,
                      color: AppColors.cleanWhite,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        activeAlert == null
                            ? "Bamenda, We've Got You."
                            : 'Emergency session is live.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.cleanWhite,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
