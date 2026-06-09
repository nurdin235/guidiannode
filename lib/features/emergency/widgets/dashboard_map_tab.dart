import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/placeholders.dart';
import '../../../core/widgets/status_widgets.dart';
import '../models/emergency_models.dart';
import 'guardian_map_view.dart';

class DashboardMapTab extends StatelessWidget {
  const DashboardMapTab({
    super.key,
    required this.mapsLoaderFuture,
    required this.position,
    required this.nearbyAlerts,
    required this.isLoadingAlerts,
    required this.onRefreshAlerts,
    required this.onShowLegend,
    required this.onOpenFollow,
    required this.onEnableLocationSharing,
  });

  final Future<void> mapsLoaderFuture;
  final PositionSnapshot? position;
  final List<EmergencyAlert> nearbyAlerts;
  final bool isLoadingAlerts;
  final Future<void> Function() onRefreshAlerts;
  final VoidCallback onShowLegend;
  final void Function(EmergencyAlert alert) onOpenFollow;
  final VoidCallback onEnableLocationSharing;

  @override
  Widget build(BuildContext context) {
    final currentPosition = position;
    if (currentPosition == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: EmptyState(
          title: 'Map unavailable',
          message:
              'Turn on location sharing to load nearby alerts, your current position, and route context.',
          icon: Icons.map_outlined,
          actionLabel: 'Enable location sharing',
          onAction: onEnableLocationSharing,
        ),
      );
    }

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('current-user'),
        position: currentPosition.latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'You'),
      ),
      ...nearbyAlerts.map(
        (alert) => Marker(
          markerId: MarkerId('alert-${alert.id}'),
          position: alert.latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => onOpenFollow(alert),
        ),
      ),
    };

    final focusPoints = <LatLng>[
      currentPosition.latLng,
      ...nearbyAlerts.map((alert) => alert.latLng),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<void>(
        future: mapsLoaderFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return ErrorState(
              title: 'Map could not load',
              message: snapshot.error.toString(),
              onRetry: onRefreshAlerts,
            );
          }

          return Stack(
            children: [
              Positioned.fill(
                child: GuardianMapView(
                  markers: markers,
                  focusPoints: focusPoints,
                  initialCenter: currentPosition.latLng,
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.cleanWhite.withValues(
                                  alpha: 0.96,
                                ),
                                borderRadius: AppRadii.card,
                                border: Border.all(color: AppColors.border),
                              ),
                              child: GuardianAppBar(
                                title: 'Live Map',
                                showLogo: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          IconButton.filledTonal(
                            onPressed: onShowLegend,
                            icon: const Icon(Icons.legend_toggle_rounded),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          IconButton.filledTonal(
                            onPressed: isLoadingAlerts ? null : onRefreshAlerts,
                            icon: const Icon(Icons.refresh_rounded),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.cleanWhite.withValues(alpha: 0.96),
                          borderRadius: AppRadii.card,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  nearbyAlerts.isEmpty
                                      ? 'Live map ready'
                                      : 'Active Alert',
                                  style: Theme.of(context).textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const Spacer(),
                                if (nearbyAlerts.isNotEmpty)
                                  const StatusBadge(
                                    label: 'LIVE',
                                    tone: StatusTone.error,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              nearbyAlerts.isEmpty
                                  ? currentPosition.displayAddress
                                  : nearbyAlerts.first.displayAddress,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            if (nearbyAlerts.isNotEmpty)
                              Row(
                                children: [
                                  Expanded(
                                    child: StatTile(
                                      label: 'Alerts',
                                      value: '${nearbyAlerts.length}',
                                      helper: 'Nearby',
                                      tone: StatusTone.info,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: StatTile(
                                      label: 'Distance',
                                      value: _formatDistance(
                                        nearbyAlerts.first.distanceMeters,
                                      ),
                                      helper: 'From you',
                                      tone: StatusTone.success,
                                    ),
                                  ),
                                ],
                              ),
                            if (nearbyAlerts.isNotEmpty)
                              const SizedBox(height: AppSpacing.md),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlineActionButton(
                                    text: 'Refresh nearby',
                                    icon: Icons.refresh_rounded,
                                    onPressed: isLoadingAlerts
                                        ? null
                                        : onRefreshAlerts,
                                  ),
                                ),
                                if (nearbyAlerts.isNotEmpty) ...[
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: CommunityActionButton(
                                      onPressed: () =>
                                          onOpenFollow(nearbyAlerts.first),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDistance(double? meters) {
    if (meters == null) {
      return '--';
    }
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.round()} m';
  }
}
