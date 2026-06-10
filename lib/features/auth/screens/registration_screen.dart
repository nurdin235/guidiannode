import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_service.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/status_widgets.dart';
import '../../emergency/models/emergency_models.dart';
import '../../emergency/services/emergency_coordinator.dart';
import '../utils/post_auth_flow.dart';
import '../widgets/auth_scaffold.dart';
import 'legal_document_screen.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key, this.prefillLocationEnabled = false});

  final bool prefillLocationEnabled;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _quarterController = TextEditingController();
  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final EmergencyCoordinator _emergencyCoordinator =
      EmergencyCoordinator.instance;

  late final TapGestureRecognizer _termsRecognizer;
  late final TapGestureRecognizer _privacyRecognizer;

  String? _relationship;
  bool _enableLocationSharing = false;
  bool _agreedToTerms = false;
  bool _isLoading = false;
  bool _isOpeningWhatsapp = false;
  bool _isPollingVerification = false;
  PositionSnapshot? _locationSnapshot;

  Timer? _verificationPollTimer;
  Timer? _countdownTimer;
  Timer? _lastCheckedTimer;
  DateTime _lastCheckedTime = DateTime.now();
  int _secondsElapsedSinceStart = 0;
  bool _whatsappOpened = false;
  Duration _timeLeft = const Duration(minutes: 10);
  DateTime? _expiryTime;

  _WhatsappVerification? _whatsappVerification;
  String? _verificationMessage;

  @override
  void initState() {
    super.initState();
    _enableLocationSharing = widget.prefillLocationEnabled;
    _termsRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LegalDocumentScreen(
            title: 'Terms & Conditions',
            content:
                '1. Introduction\nWelcome to GuardianNode. By using our emergency alert system, you agree to these terms.\n\n2. Acceptable Use\nUse this application only for genuine emergency situations. False alarms or misuse may result in account restriction.\n\n3. Liability\nGuardianNode does not guarantee immediate responder arrival and is not liable for network failures.',
          ),
        ),
      );
    _privacyRecognizer = TapGestureRecognizer()
      ..onTap = () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const LegalDocumentScreen(
            title: 'Privacy Policy',
            content:
                '1. Data Collection\nGuardianNode stores your name, phone number, and emergency contact details for account and emergency coordination.\n\n2. Location Sharing\nYour live location is used for emergency routing and nearby alert discovery. It matters most when you trigger SOS.\n\n3. Data Security\nAuthentication and data transport rely on secure backend contracts and Supabase-backed realtime services.',
          ),
        ),
      );
  }

  @override
  void dispose() {
    _cancelVerificationTimers();
    _termsRecognizer.dispose();
    _privacyRecognizer.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _quarterController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  Future<void> _toggleLocationSharing(bool value) async {
    if (!value) {
      setState(() {
        _enableLocationSharing = false;
        _locationSnapshot = null;
      });
      return;
    }

    final permissionResult = await _emergencyCoordinator
        .previewLocationPermission(true);

    if (!mounted) {
      return;
    }

    setState(() {
      _enableLocationSharing = permissionResult.granted;
      _locationSnapshot = permissionResult.snapshot;
    });

    if (!permissionResult.granted && permissionResult.message != null) {
      StatusSnackbar.show(
        context,
        message: permissionResult.message!,
        tone: StatusTone.error,
      );
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToTerms) {
      StatusSnackbar.show(
        context,
        message: 'Please agree to the terms before continuing.',
        tone: StatusTone.warning,
      );
      return;
    }

    await _requestRegistrationVerification();
  }

  Map<String, dynamic> _buildRegistrationData() {
    return {
      'full_name': _nameController.text.trim(),
      'phone_number': _phoneController.text.trim(),
      'quarter': _quarterController.text.trim(),
      'location_permission': _enableLocationSharing,
      'latitude': _locationSnapshot?.latitude,
      'longitude': _locationSnapshot?.longitude,
      'emergency_contact': {
        'contact_name': _contactNameController.text.trim(),
        'phone_number': _contactPhoneController.text.trim(),
        'relationship': _relationship,
      },
    };
  }

  Future<void> _requestRegistrationVerification() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.startRegistrationVerification(
        registrationData: _buildRegistrationData(),
      );

      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

      if (response['success'] != true) {
        StatusSnackbar.show(
          context,
          message:
              response['message']?.toString() ??
              'Registration could not be completed.',
          tone: StatusTone.error,
        );
        return;
      }

      final verification = _WhatsappVerification.fromResponse(response);

      if (verification == null) {
        StatusSnackbar.show(
          context,
          message: 'The backend did not return a WhatsApp verification link.',
          tone: StatusTone.error,
        );
        return;
      }

      setState(() {
        _whatsappVerification = verification;
        _whatsappOpened = false;
        _verificationMessage =
            'Waiting for your WhatsApp verification message.';
      });
      _startVerificationTimers();
      unawaited(_pollVerificationStatus());
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

  void _startVerificationTimers() {
    _cancelVerificationTimers();
    _secondsElapsedSinceStart = 0;
    _lastCheckedTime = DateTime.now();

    final verification = _whatsappVerification;
    if (verification != null) {
      try {
        _expiryTime = DateTime.parse(verification.expiresAt).toLocal();
        _timeLeft = _expiryTime!.difference(DateTime.now());
      } catch (e) {
        _expiryTime = DateTime.now().add(const Duration(minutes: 10));
        _timeLeft = const Duration(minutes: 10);
      }
    }

    _verificationPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollVerificationStatus(),
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsElapsedSinceStart++;
        if (_expiryTime != null) {
          _timeLeft = _expiryTime!.difference(DateTime.now());
          if (_timeLeft.isNegative) {
            _timeLeft = Duration.zero;
            if (_whatsappVerification != null) {
              _whatsappVerification = _whatsappVerification!.copyWith(
                status: 'expired',
              );
            }
            _cancelVerificationTimers();
            _verificationMessage =
                'Your verification link has expired. Please request a new one.';
          }
        }
      });
    });

    _lastCheckedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _cancelVerificationTimers() {
    _verificationPollTimer?.cancel();
    _countdownTimer?.cancel();
    _lastCheckedTimer?.cancel();
    _verificationPollTimer = null;
    _countdownTimer = null;
    _lastCheckedTimer = null;
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatLastChecked() {
    final difference = DateTime.now().difference(_lastCheckedTime).inSeconds;
    if (difference < 4) {
      return 'just now';
    }
    return '$difference seconds ago';
  }

  Future<void> _pollVerificationStatus({bool manual = false}) async {
    final verification = _whatsappVerification;

    if (verification == null ||
        _isPollingVerification ||
        (['expired', 'failed'].contains(verification.status) && !manual)) {
      return;
    }

    setState(() => _isPollingVerification = true);

    try {
      final response = await ApiService.getVerificationStatus(
        verification.verificationId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _lastCheckedTime = DateTime.now();
      });

      if (response['success'] != true) {
        setState(() {
          _verificationMessage =
              response['message']?.toString() ??
              'Verification status could not be refreshed.';
        });
        return;
      }

      final status = response['status']?.toString() ?? 'pending';
      final verified = response['verified'] == true || status == 'verified';

      if (verified) {
        _cancelVerificationTimers();
        final sessionPayload = _sessionFromVerifiedResponse(response);

        if (sessionPayload != null) {
          SessionService.setSession(sessionPayload);
          PostAuthFlow.routeAfterVerification(
            context,
            bootstrapLocationSharing: _enableLocationSharing,
          );
          return;
        }

        StatusSnackbar.show(
          context,
          message: 'Verification completed. Please sign in to continue.',
        );
        return;
      }

      if (status == 'failed') {
        _cancelVerificationTimers();
        setState(() {
          _whatsappVerification = verification.copyWith(status: 'failed');
          _verificationMessage =
              response['message']?.toString() ??
              'Verification failed. Please generate a new link.';
        });
        return;
      }

      if (status == 'expired') {
        _cancelVerificationTimers();
        setState(() {
          _whatsappVerification = verification.copyWith(status: 'expired');
          _verificationMessage =
              'Your verification link has expired. Please request a new one.';
        });
        return;
      }

      setState(() {
        _whatsappVerification = verification.copyWith(status: status);
        _verificationMessage =
            'Waiting for your WhatsApp verification message.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _verificationMessage = 'Connection error. Retrying...';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isPollingVerification = false);
      }
    }
  }

  Map<String, dynamic>? _sessionFromVerifiedResponse(
    Map<String, dynamic> response,
  ) {
    final session = response['session'];
    if (session is Map) {
      return Map<String, dynamic>.from(session);
    }

    final authToken = response['authToken']?.toString();
    final user = response['user'];
    if (authToken == null || authToken.isEmpty || user is! Map) {
      return null;
    }

    return {
      'access_token': authToken,
      'token_type': 'Bearer',
      'user': Map<String, dynamic>.from(user),
    };
  }

  Future<void> _openWhatsappVerification() async {
    final verification = _whatsappVerification;

    if (verification == null) {
      return;
    }

    setState(() {
      _isOpeningWhatsapp = true;
      _whatsappOpened = true;
    });

    try {
      final uri = Uri.parse(verification.whatsappUrl);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        StatusSnackbar.show(
          context,
          message: 'WhatsApp could not be opened on this device.',
          tone: StatusTone.error,
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }

      StatusSnackbar.show(
        context,
        message: 'WhatsApp could not be opened: $error',
        tone: StatusTone.error,
      );
    } finally {
      if (mounted) {
        setState(() => _isOpeningWhatsapp = false);
      }
    }
  }

  void _editRegistrationDetails() {
    _cancelVerificationTimers();
    setState(() {
      _whatsappVerification = null;
      _verificationMessage = null;
    });
  }

  Widget _buildWhatsappVerificationPanel(
    BuildContext context,
    _WhatsappVerification verification,
  ) {
    final isExpired = verification.status == 'expired';
    final isFailed = verification.status == 'failed';
    final showWarning =
        !isExpired && !isFailed && _secondsElapsedSinceStart > 30;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: isExpired
                  ? AppColors.communityYellowSurface
                  : AppColors.safetyGreenSurface,
              borderRadius: AppRadii.card,
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(
              isExpired
                  ? Icons.schedule_rounded
                  : Icons.mark_chat_read_outlined,
              color: isExpired
                  ? const Color(0xFF8A5A00)
                  : AppColors.safetyGreen,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          'Tap the button below to send your verification message on WhatsApp. Once sent, this page will update automatically.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
            height: 1.45,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Text(
                'Verification message',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SelectableText(
                verification.token,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.trustBlueDark,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        InfoBanner(
          title: isExpired
              ? 'Expired'
              : 'Expires in: ${_formatDuration(_timeLeft)}',
          message: 'This verification link is active for 10 minutes.',
        ),
        if (_verificationMessage != null) ...[
          const SizedBox(height: AppSpacing.md),
          StatusBanner(
            title: isExpired
                ? 'Expired'
                : isFailed
                ? 'Verification failed'
                : 'Waiting for WhatsApp',
            message: showWarning
                ? 'Still waiting. Make sure the message was sent to the GuardianNode business number (+237 6 57 26 20 38).'
                : _verificationMessage!,
            tone: isExpired || isFailed
                ? StatusTone.warning
                : (showWarning ? StatusTone.warning : StatusTone.info),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (!isExpired && !isFailed)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last checked: ${_formatLastChecked()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Checking every 3 seconds',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          text: _whatsappOpened ? 'Open WhatsApp again' : 'Open WhatsApp',
          icon: Icons.chat_rounded,
          isLoading: _isOpeningWhatsapp,
          onPressed: (isExpired || isFailed) ? null : _openWhatsappVerification,
        ),
        if (!isExpired && !isFailed) ...[
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: 'I have sent the message — Check now',
            icon: Icons.check_circle_outline_rounded,
            tone: AppButtonTone.secondary,
            isLoading: _isPollingVerification,
            onPressed: () => _pollVerificationStatus(manual: true),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        if (isExpired || isFailed) ...[
          OutlineActionButton(
            text: 'Generate new link',
            icon: Icons.refresh_rounded,
            onPressed: _isLoading ? null : _requestRegistrationVerification,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        OutlineActionButton(
          text: 'Edit details',
          icon: Icons.edit_outlined,
          onPressed: _isLoading ? null : _editRegistrationDetails,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final whatsappVerification = _whatsappVerification;

    if (whatsappVerification != null) {
      final isExpired = whatsappVerification.status == 'expired';
      final isFailed = whatsappVerification.status == 'failed';

      return AuthScaffold(
        eyebrow: 'WhatsApp verification',
        title: 'Verify with WhatsApp',
        subtitle:
            'GuardianNode will activate your emergency profile as soon as your message reaches the business number.',
        badge: AuthHeroBadge(
          label: isExpired
              ? 'Link expired'
              : isFailed
              ? 'Verification failed'
              : 'Waiting on WhatsApp',
          tone: isExpired || isFailed ? StatusTone.warning : StatusTone.action,
        ),
        child: _buildWhatsappVerificationPanel(context, whatsappVerification),
      );
    }

    return AuthScaffold(
      eyebrow: 'Create your emergency profile',
      title: 'Join GuardianNode',
      subtitle:
          'Set up your identity, your quarter, and one trusted emergency contact so the platform can act quickly when you need it.',
      badge: AuthHeroBadge(
        label: _enableLocationSharing ? 'Location primed' : 'Resident signup',
        tone: _enableLocationSharing ? StatusTone.success : StatusTone.info,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const CommunityUpdateCard(
              updateText:
                  'GuardianNode protects your emergency profile until your WhatsApp verification is complete.',
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Your details', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
                hintText: '+237 ...',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 8) {
                  return 'Enter a valid phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _quarterController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Quarter / neighborhood',
                prefixIcon: Icon(Icons.location_city_outlined),
                hintText: 'For example Mile 4 or Up Station',
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Enter your quarter or neighborhood';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.card,
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile.adaptive(
                value: _enableLocationSharing,
                onChanged: _isLoading ? null : _toggleLocationSharing,
                activeThumbColor: AppColors.safetyGreen,
                activeTrackColor: AppColors.safetyGreen.withValues(alpha: 0.3),
                title: const Text('Allow location for emergency routing'),
                subtitle: Text(
                  _enableLocationSharing
                      ? 'Your location will be ready after account verification.'
                      : 'You can enable this later from the dashboard as well.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                secondary: const Icon(Icons.my_location_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Primary emergency contact',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextFormField(
              controller: _contactNameController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Contact name',
                prefixIcon: Icon(Icons.contact_page_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 2) {
                  return 'Enter a contact name';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: const InputDecoration(
                labelText: 'Contact phone number',
                prefixIcon: Icon(Icons.contact_phone_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().length < 8) {
                  return 'Enter a valid contact phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _relationship,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                prefixIcon: Icon(Icons.people_outline_rounded),
              ),
              items: const [
                DropdownMenuItem(value: 'Parent', child: Text('Parent')),
                DropdownMenuItem(value: 'Sibling', child: Text('Sibling')),
                DropdownMenuItem(value: 'Spouse', child: Text('Spouse')),
                DropdownMenuItem(value: 'Friend', child: Text('Friend')),
                DropdownMenuItem(value: 'Neighbor', child: Text('Neighbor')),
              ],
              onChanged: (value) => setState(() => _relationship = value),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Choose a relationship';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: AppRadii.card,
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox.adaptive(
                    value: _agreedToTerms,
                    onChanged: (value) =>
                        setState(() => _agreedToTerms = value ?? false),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: Theme.of(context).textTheme.bodySmall,
                          children: [
                            TextSpan(
                              text: 'Terms & Conditions',
                              recognizer: _termsRecognizer,
                              style: const TextStyle(
                                color: AppColors.trustBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              recognizer: _privacyRecognizer,
                              style: const TextStyle(
                                color: AppColors.trustBlue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const TextSpan(
                              text:
                                  ' for emergency communication, WhatsApp verification, and profile storage.',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              text: 'Create account',
              icon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              onPressed: _handleRegister,
            ),
            const SizedBox(height: AppSpacing.md),
            Center(
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).pop(),
                child: const Text('Already have an account? Sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhatsappVerification {
  const _WhatsappVerification({
    required this.verificationId,
    required this.token,
    required this.expiresAt,
    required this.whatsappUrl,
    this.status = 'pending',
  });

  final String verificationId;
  final String token;
  final String expiresAt;
  final String whatsappUrl;
  final String status;

  static _WhatsappVerification? fromResponse(Map<String, dynamic> response) {
    final verificationId =
        response['verificationId']?.toString() ??
        response['otp_session_id']?.toString();
    final token = response['token']?.toString();
    final expiresAt =
        response['expiresAt']?.toString() ?? response['expires_at']?.toString();
    final whatsappUrl = response['whatsappUrl']?.toString();

    if (verificationId == null ||
        verificationId.isEmpty ||
        token == null ||
        token.isEmpty ||
        expiresAt == null ||
        expiresAt.isEmpty ||
        whatsappUrl == null ||
        whatsappUrl.isEmpty) {
      return null;
    }

    return _WhatsappVerification(
      verificationId: verificationId,
      token: token,
      expiresAt: expiresAt,
      whatsappUrl: whatsappUrl,
      status: response['status']?.toString() ?? 'pending',
    );
  }

  _WhatsappVerification copyWith({String? status}) {
    return _WhatsappVerification(
      verificationId: verificationId,
      token: token,
      expiresAt: expiresAt,
      whatsappUrl: whatsappUrl,
      status: status ?? this.status,
    );
  }
}
