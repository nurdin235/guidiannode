import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/api_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status_widgets.dart';
import '../widgets/auth_scaffold.dart';

class WhatsappVerificationScreen extends StatefulWidget {
  const WhatsappVerificationScreen({
    super.key,
    required this.verificationId,
    required this.token,
    required this.whatsappUrl,
    required this.onVerified,
    required this.onRequestNew,
    this.expiresAt,
    this.title = 'Verify with WhatsApp',
    this.subtitle =
        'Send the prepared message and GuardianNode will continue automatically.',
  });

  final String verificationId;
  final String token;
  final String whatsappUrl;
  final ValueChanged<Map<String, dynamic>> onVerified;
  final Future<Map<String, dynamic>> Function() onRequestNew;
  final String? expiresAt;
  final String title;
  final String subtitle;

  @override
  State<WhatsappVerificationScreen> createState() =>
      _WhatsappVerificationScreenState();
}

class _WhatsappVerificationScreenState
    extends State<WhatsappVerificationScreen> {
  late String _verificationId;
  late String _token;
  late String _whatsappUrl;
  Timer? _pollTimer;
  Timer? _countdownTimer;
  Timer? _lastCheckedTimer;

  bool _isPolling = false;
  bool _isOpeningWhatsapp = false;
  bool _isRequestingNew = false;
  bool _whatsappOpened = false;
  String _status = 'pending';
  String _message = 'Waiting for your WhatsApp verification message.';

  Duration _timeLeft = const Duration(minutes: 10);
  DateTime? _expiryTime;
  DateTime _lastCheckedTime = DateTime.now();
  int _secondsElapsedSinceStart = 0;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    _token = widget.token;
    _whatsappUrl = widget.whatsappUrl;
    _initExpiry();
    _startTimers();
    // Immediate initial poll
    _pollStatus();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  void _initExpiry() {
    try {
      final expAt = widget.expiresAt;
      if (expAt != null) {
        _expiryTime = DateTime.parse(expAt).toLocal();
        _timeLeft = _expiryTime!.difference(DateTime.now());
        if (_timeLeft.isNegative) {
          _timeLeft = Duration.zero;
          _status = 'expired';
        }
        return;
      }
    } catch (e) {
      // Fall through
    }
    _expiryTime = DateTime.now().add(const Duration(minutes: 10));
    _timeLeft = const Duration(minutes: 10);
  }

  void _startTimers() {
    _cancelTimers();

    // Poll status every 3 seconds as required
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _pollStatus(),
    );

    // Expiry countdown timer every 1 second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsElapsedSinceStart++;
        if (_expiryTime != null) {
          _timeLeft = _expiryTime!.difference(DateTime.now());
          if (_timeLeft.isNegative) {
            _timeLeft = Duration.zero;
            _status = 'expired';
            _cancelTimers();
            _message = 'Your verification link has expired. Please request a new one.';
          }
        }
      });
    });

    // Rebuild UI every second to update "Last checked X seconds ago" dynamically
    _lastCheckedTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _cancelTimers() {
    _pollTimer?.cancel();
    _countdownTimer?.cancel();
    _lastCheckedTimer?.cancel();
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

  Future<void> _pollStatus({bool manual = false}) async {
    if (_isPolling || (_status == 'expired' && !manual)) {
      return;
    }

    setState(() {
      _isPolling = true;
    });

    try {
      final response = await ApiService.getVerificationStatus(_verificationId);

      if (!mounted) return;

      setState(() {
        _lastCheckedTime = DateTime.now();
      });

      if (response['success'] != true) {
        setState(() {
          _message = response['message']?.toString() ??
              'Verification status could not be refreshed.';
        });
        return;
      }

      final status = response['status']?.toString() ?? 'pending';

      if (response['verified'] == true || status == 'verified') {
        _cancelTimers();
        final session = response['session'];

        if (session is Map) {
          widget.onVerified(Map<String, dynamic>.from(session));
          return;
        }

        setState(() {
          _message = 'Verification succeeded, but no app session was returned.';
        });
        return;
      }

      if (status == 'expired') {
        _cancelTimers();
        setState(() {
          _status = 'expired';
          _timeLeft = Duration.zero;
          _message = 'Your verification link has expired. Please request a new one.';
        });
        return;
      }

      setState(() {
        _status = status;
        _message = 'Waiting for your WhatsApp verification message.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _message = 'Connection error. Retrying...';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPolling = false;
        });
      }
    }
  }

  Future<void> _openWhatsapp() async {
    setState(() {
      _isOpeningWhatsapp = true;
      _whatsappOpened = true;
    });

    try {
      final launched = await launchUrl(
        Uri.parse(_whatsappUrl),
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        StatusSnackbar.show(
          context,
          message: 'WhatsApp could not be opened on this device.',
          tone: StatusTone.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOpeningWhatsapp = false);
      }
    }
  }

  Future<void> _requestNew() async {
    setState(() => _isRequestingNew = true);

    try {
      final response = await widget.onRequestNew();

      if (!mounted) return;

      if (response['success'] != true) {
        StatusSnackbar.show(
          context,
          message: response['message']?.toString() ??
              'A new verification link could not be created.',
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

      setState(() {
        _verificationId = verificationId;
        _token = token;
        _whatsappUrl = whatsappUrl;
        _status = 'pending';
        _whatsappOpened = false;
        _secondsElapsedSinceStart = 0;
        _message = 'Waiting for your WhatsApp verification message.';
        _lastCheckedTime = DateTime.now();
        if (expiresAt != null) {
          _expiryTime = DateTime.parse(expiresAt).toLocal();
        } else {
          _expiryTime = DateTime.now().add(const Duration(minutes: 10));
        }
      });
      _startTimers();
      _pollStatus();
    } finally {
      if (mounted) {
        setState(() => _isRequestingNew = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpired = _status == 'expired';
    final showWarning = !isExpired && _secondsElapsedSinceStart > 30;

    return AuthScaffold(
      eyebrow: 'WhatsApp authentication',
      title: widget.title,
      subtitle: widget.subtitle,
      badge: AuthHeroBadge(
        label: isExpired ? 'Link expired' : 'Waiting on WhatsApp',
        tone: isExpired ? StatusTone.warning : StatusTone.action,
      ),
      child: Column(
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
                  _token,
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
            title: isExpired ? 'Expired' : 'Expires in: ${_formatDuration(_timeLeft)}',
            message: 'This verification link is active for 10 minutes.',
          ),
          const SizedBox(height: AppSpacing.md),
          StatusBanner(
            title: isExpired ? 'Expired' : 'Waiting for WhatsApp',
            message: showWarning
                ? 'Still waiting. Make sure the message was sent to the GuardianNode business number (+237 6 57 26 20 38).'
                : _message,
            tone: isExpired ? StatusTone.warning : (showWarning ? StatusTone.warning : StatusTone.info),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!isExpired)
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
            text: _whatsappOpened ? 'Open WhatsApp again' : 'Verify via WhatsApp',
            icon: Icons.chat_rounded,
            isLoading: _isOpeningWhatsapp,
            onPressed: isExpired ? null : _openWhatsapp,
          ),
          if (!isExpired) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Check verification status',
              icon: Icons.check_circle_outline_rounded,
              tone: AppButtonTone.secondary,
              isLoading: _isPolling,
              onPressed: () => _pollStatus(manual: true),
            ),
          ],
          if (isExpired) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Request a new link',
              icon: Icons.refresh_rounded,
              tone: AppButtonTone.outline,
              isLoading: _isRequestingNew,
              onPressed: _requestNew,
            ),
          ],
        ],
      ),
    );
  }
}
