import 'package:flutter/material.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../emergency/services/emergency_coordinator.dart';
import 'login_screen.dart';

class PermissionsEducationScreen extends StatefulWidget {
  const PermissionsEducationScreen({super.key});

  @override
  State<PermissionsEducationScreen> createState() =>
      _PermissionsEducationScreenState();
}

class _PermissionsEducationScreenState
    extends State<PermissionsEducationScreen> {
  bool _isRequesting = false;
  String? _message;

  Future<void> _continue({required bool requestNow}) async {
    setState(() {
      _isRequesting = requestNow;
      _message = null;
    });

    var locationEnabled = false;

    if (requestNow) {
      final permissionResult = await EmergencyCoordinator.instance
          .previewLocationPermission(true);
      locationEnabled = permissionResult.granted;
      _message = permissionResult.message;
    }

    await AppPreferences.setHasSeenOnboarding(true);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(prefillLocationEnabled: locationEnabled),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const SizedBox(height: AppSpacing.md),
            const Align(
              alignment: Alignment.centerLeft,
              child: StatusBadge(
                label: 'Permission guide',
                tone: StatusTone.info,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.card,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Center(child: GuardianLogo(size: 88)),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Before you begin, allow location when you can',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'GuardianNode uses location to route nearby help, refresh live SOS positions, and show incidents around you. Your position is most important during an emergency.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const InfoBanner(
                    title: 'How it is used',
                    message:
                        'Location sharing improves nearby alert discovery and live responder guidance. You can still review the app first and enable it later.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _PermissionRow(
              title: 'Nearby alert discovery',
              message: 'Find active incidents and safe points close to you.',
              icon: Icons.radar_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            _PermissionRow(
              title: 'Faster SOS routing',
              message:
                  'Send the backend your live position so responders have a better starting point.',
              icon: Icons.my_location_rounded,
            ),
            const SizedBox(height: AppSpacing.md),
            _PermissionRow(
              title: 'Realtime community follow mode',
              message:
                  'Community responders can see route guidance with the latest victim location.',
              icon: Icons.route_rounded,
            ),
            if (_message != null) ...[
              const SizedBox(height: AppSpacing.lg),
              WarningBanner(title: 'Permission note', message: _message!),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: AppColors.background,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PrimaryButton(
                text: 'Enable location now',
                icon: Icons.location_searching_rounded,
                isLoading: _isRequesting,
                onPressed: _isRequesting
                    ? null
                    : () => _continue(requestNow: true),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlineActionButton(
                text: 'Set up later',
                onPressed: _isRequesting
                    ? null
                    : () => _continue(requestNow: false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.engagementOrangeSurface,
              borderRadius: AppRadii.card,
            ),
            child: Icon(icon, color: AppColors.engagementOrange),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
