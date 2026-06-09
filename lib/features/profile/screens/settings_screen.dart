import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/app_preferences.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../auth/screens/legal_document_screen.dart';
import '../../auth/screens/login_screen.dart';
import '../../emergency/services/emergency_coordinator.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final EmergencyCoordinator _coordinator = EmergencyCoordinator.instance;

  late bool _showCommunityBanners;
  late bool _showSafetyTips;
  bool _isUpdatingLocation = false;

  @override
  void initState() {
    super.initState();
    _showCommunityBanners = AppPreferences.showCommunityBanners;
    _showSafetyTips = AppPreferences.showSafetyTips;
  }

  Future<void> _toggleLocation(bool value) async {
    setState(() => _isUpdatingLocation = true);
    final success = await _coordinator.setLocationSharingEnabled(value);

    if (!mounted) {
      return;
    }

    setState(() => _isUpdatingLocation = false);

    if (!success && value) {
      StatusSnackbar.show(
        context,
        message:
            _coordinator.locationError ??
            'Location permission could not be enabled.',
        tone: StatusTone.error,
      );
    }
  }

  void _signOut() {
    SessionService.clearSession();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showUnsupportedPreference() {
    // TODO: Connect this setting when backend/user preference support is defined.
    StatusSnackbar.show(
      context,
      message: 'This setting is not connected yet.',
      tone: StatusTone.info,
    );
  }

  Future<void> _openDataDeletion() async {
    final opened = await launchUrl(
      AppConfig.dataDeletionUri,
      mode: LaunchMode.externalApplication,
    );

    if (!mounted || opened) {
      return;
    }

    StatusSnackbar.show(
      context,
      message: 'The account deletion page could not be opened.',
      tone: StatusTone.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _coordinator,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: AppColors.cleanWhite,
          appBar: AppBar(
            titleSpacing: 0,
            title: const Row(
              children: [
                GuardianLogo(size: 38, padding: EdgeInsets.all(3)),
                SizedBox(width: AppSpacing.sm),
                Text('Settings'),
              ],
            ),
          ),
          body: ListView(
            padding: AppSpacing.screenPadding,
            children: [
              const SectionHeader(title: 'General'),
              const SizedBox(height: AppSpacing.md),
              SettingsTile(
                icon: Icons.location_searching_rounded,
                title: 'Location Permissions',
                subtitle: _coordinator.locationSharingEnabled
                    ? 'Always'
                    : 'Off until you enable it.',
                trailing: Switch.adaptive(
                  value: _coordinator.locationSharingEnabled,
                  onChanged: _isUpdatingLocation ? null : _toggleLocation,
                  activeThumbColor: AppColors.safetyGreen,
                  activeTrackColor: AppColors.safetyGreen.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                subtitle: _showCommunityBanners ? 'On' : 'Off',
                trailing: Switch.adaptive(
                  value: _showCommunityBanners,
                  onChanged: (value) async {
                    await AppPreferences.setShowCommunityBanners(value);
                    if (!mounted) {
                      return;
                    }
                    setState(() => _showCommunityBanners = value);
                  },
                  activeThumbColor: AppColors.safetyGreen,
                  activeTrackColor: AppColors.safetyGreen.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.lock_outline_rounded,
                title: 'Privacy & Data',
                subtitle: 'Review how account and location data are handled.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentScreen(
                        title: 'Privacy Policy',
                        content:
                            'GuardianNode stores account details, emergency contact information, and emergency-related location updates to support SOS response, WhatsApp verification, and realtime routing.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.delete_forever_outlined,
                title: 'Delete account & data',
                subtitle:
                    'Open the secure deletion request page and verify ownership.',
                onTap: _openDataDeletion,
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'Preferences'),
              const SizedBox(height: AppSpacing.md),
              SettingsTile(
                icon: Icons.language_rounded,
                title: 'Language',
                subtitle: 'English',
                onTap: _showUnsupportedPreference,
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.light_mode_outlined,
                title: 'App Theme',
                subtitle: 'Light',
                onTap: _showUnsupportedPreference,
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.text_fields_rounded,
                title: 'Text Size',
                subtitle: 'Medium',
                onTap: _showUnsupportedPreference,
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.tips_and_updates_outlined,
                title: 'Safety Tips',
                subtitle: _showSafetyTips ? 'Visible on dashboard' : 'Hidden',
                trailing: Switch.adaptive(
                  value: _showSafetyTips,
                  onChanged: (value) async {
                    await AppPreferences.setShowSafetyTips(value);
                    if (!mounted) {
                      return;
                    }
                    setState(() => _showSafetyTips = value);
                  },
                  activeThumbColor: AppColors.safetyGreen,
                  activeTrackColor: AppColors.safetyGreen.withValues(
                    alpha: 0.3,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'Support'),
              const SizedBox(height: AppSpacing.md),
              SettingsTile(
                icon: Icons.help_outline_rounded,
                title: 'Help Center',
                subtitle: 'Emergency use and account support.',
                onTap: _showUnsupportedPreference,
              ),
              const SizedBox(height: AppSpacing.sm),
              SettingsTile(
                icon: Icons.info_outline_rounded,
                title: 'About GuardianNode',
                subtitle: 'Bamenda emergency alert app.',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const LegalDocumentScreen(
                        title: 'About GuardianNode',
                        content:
                            'GuardianNode connects residents of Bamenda to real-time alerts, nearby responders, and trusted emergency contacts.',
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),
              DangerButton(
                text: 'Sign out',
                icon: Icons.logout_rounded,
                onPressed: _signOut,
              ),
            ],
          ),
        );
      },
    );
  }
}
