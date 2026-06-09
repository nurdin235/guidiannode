import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../emergency/services/emergency_coordinator.dart';
import '../utils/post_auth_flow.dart';
import '../widgets/auth_scaffold.dart';
import 'registration_screen.dart';
import 'whatsapp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.prefillLocationEnabled = false});

  final bool prefillLocationEnabled;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final EmergencyCoordinator _emergencyCoordinator =
      EmergencyCoordinator.instance;

  bool _isLocationEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isLocationEnabled = widget.prefillLocationEnabled;
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _toggleLocationSharing(bool value) async {
    if (!value) {
      setState(() => _isLocationEnabled = false);
      return;
    }

    final permissionResult = await _emergencyCoordinator
        .previewLocationPermission(true);

    if (!mounted) {
      return;
    }

    setState(() => _isLocationEnabled = permissionResult.granted);

    if (!permissionResult.granted && permissionResult.message != null) {
      StatusSnackbar.show(
        context,
        message: permissionResult.message!,
        tone: StatusTone.error,
      );
    }
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final phoneNumber = _phoneController.text.trim();
      final response = await ApiService.startLoginVerification(phoneNumber);

      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

      if (response['success'] != true) {
        StatusSnackbar.show(
          context,
          message:
              response['message']?.toString() ??
              'WhatsApp verification could not be started.',
          tone: StatusTone.error,
        );
        return;
      }

      final verificationId = response['verificationId']?.toString();
      final token = response['token']?.toString();
      final whatsappUrl = response['whatsappUrl']?.toString();
      final expiresAt = response['expiresAt']?.toString() ?? response['expires_at']?.toString();

      if (verificationId == null || token == null || whatsappUrl == null) {
        StatusSnackbar.show(
          context,
          message: 'The backend returned an incomplete verification link.',
          tone: StatusTone.error,
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => WhatsappVerificationScreen(
            verificationId: verificationId,
            token: token,
            whatsappUrl: whatsappUrl,
            expiresAt: expiresAt,
            title: 'Verify your login',
            subtitle:
                'Send the prepared message from WhatsApp to securely continue.',
            onRequestNew: () => ApiService.startLoginVerification(phoneNumber),
            onVerified: (session) {
              SessionService.setSession(session);
              PostAuthFlow.routeAfterVerification(
                context,
                bootstrapLocationSharing: _isLocationEnabled,
              );
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);
      StatusSnackbar.show(
        context,
        message: 'An error occurred: $error',
        tone: StatusTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      showBackButton: false,
      title: 'Welcome back!',
      subtitle: 'Login to continue',
      badge: AuthHeroBadge(
        label: _isLocationEnabled ? 'Location ready' : 'WhatsApp sign-in',
        tone: _isLocationEnabled ? StatusTone.success : StatusTone.info,
      ),
      footer: Center(
        child: TextButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => RegistrationScreen(
                  prefillLocationEnabled: _isLocationEnabled,
                ),
              ),
            );
          },
          child: const Text('Create a GuardianNode account'),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 184,
                height: 40,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: AppColors.backgroundAlt,
                  borderRadius: AppRadii.pill,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.cleanWhite,
                          borderRadius: AppRadii.pill,
                        ),
                        child: Text(
                          'Phone',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: AppColors.trustBlue,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'Email',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Phone',
                hintText: '+237 6 75 12 34 56',
                prefixIcon: Icon(Icons.phone_iphone_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your phone number';
                }
                if (value.replaceAll(' ', '').length < 8) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
              onFieldSubmitted: (_) => _isLoading ? null : _handleLogin(),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.card,
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile.adaptive(
                value: _isLocationEnabled,
                onChanged: _isLoading ? null : _toggleLocationSharing,
                activeThumbColor: AppColors.safetyGreen,
                activeTrackColor: AppColors.safetyGreen.withValues(alpha: 0.3),
                title: const Text('Keep location ready for emergencies'),
                subtitle: Text(
                  _isLocationEnabled
                      ? 'Faster routing after login.'
                      : 'You can enable this later.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                secondary: const Icon(Icons.location_searching_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              text: 'Continue with WhatsApp',
              icon: Icons.chat_rounded,
              isLoading: _isLoading,
              onPressed: _handleLogin,
            ),
          ],
        ),
      ),
    );
  }
}
