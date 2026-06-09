import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radii.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/status_widgets.dart';
import '../widgets/auth_scaffold.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.otpSessionId,
    this.debugHelperMessage,
    this.otpLength = 6,
    required this.onVerified,
  });

  final String phoneNumber;
  final String? otpSessionId;
  final String? debugHelperMessage;
  final int otpLength;
  final Function(Map<String, dynamic> session) onVerified;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;
  late final int _otpLength;
  late String? _otpSessionId;
  late String? _debugHelperMessage;
  Timer? _resendTimer;
  int _resendRemaining = 24;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _otpLength = widget.otpLength;
    _controllers = List.generate(_otpLength, (_) => TextEditingController());
    _focusNodes = List.generate(_otpLength, (_) => FocusNode());
    _otpSessionId = widget.otpSessionId;
    _debugHelperMessage = widget.debugHelperMessage;
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendRemaining = 24);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_resendRemaining <= 1) {
        timer.cancel();
        setState(() => _resendRemaining = 0);
        return;
      }

      setState(() => _resendRemaining--);
    });
  }

  void _onOtpChanged(String value, int index) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '').split('');
      for (var i = 0; i < digits.length && i + index < _otpLength; i++) {
        _controllers[index + i].value = TextEditingValue(
          text: digits[i],
          selection: const TextSelection.collapsed(offset: 1),
        );
      }
      final nextIndex = (index + digits.length).clamp(0, _otpLength - 1);
      FocusScope.of(context).requestFocus(_focusNodes[nextIndex]);
    } else if (value.length == 1 && index < _otpLength - 1) {
      FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
    }

    if (_controllers.every((controller) => controller.text.isNotEmpty)) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    final otpCode = _controllers.map((controller) => controller.text).join();
    if (otpCode.length != _otpLength) {
      StatusSnackbar.show(
        context,
        message: 'Enter the full $_otpLength-digit code.',
        tone: StatusTone.warning,
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.verifyOtp(
        phoneNumber: widget.phoneNumber,
        otpCode: otpCode,
        otpSessionId: _otpSessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() => _isLoading = false);

      if (response['success'] != true) {
        StatusSnackbar.show(
          context,
          message: response['message']?.toString() ?? 'Verification failed.',
          tone: StatusTone.error,
        );
        return;
      }

      widget.onVerified(Map<String, dynamic>.from(response['session'] as Map));
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

  Future<void> _handleResendOtp() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.resendOtp(
        phoneNumber: widget.phoneNumber,
        otpSessionId: _otpSessionId,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _otpSessionId = response['otp_session_id']?.toString() ?? _otpSessionId;
        final debugPayload = response['debug'];
        _debugHelperMessage = debugPayload is Map
            ? debugPayload['helper_message']?.toString() ?? _debugHelperMessage
            : _debugHelperMessage;
      });

      if (response['success'] != true) {
        StatusSnackbar.show(
          context,
          message: response['message']?.toString() ?? 'Unable to resend OTP.',
          tone: StatusTone.error,
        );
        return;
      }

      for (final controller in _controllers) {
        controller.clear();
      }

      _startResendTimer();
      FocusScope.of(context).requestFocus(_focusNodes.first);
      StatusSnackbar.show(
        context,
        message: response['message']?.toString() ?? 'A new OTP was sent.',
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
    final showDebugHelper =
        AppConfig.showDebugOtpHelper &&
        _debugHelperMessage != null &&
        _debugHelperMessage!.isNotEmpty;

    return AuthScaffold(
      title: 'Enter the $_otpLength-digit code',
      subtitle: 'We sent a code to ${widget.phoneNumber}.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: AppColors.trustBlueSurface,
                borderRadius: AppRadii.card,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(
                Icons.mark_chat_read_outlined,
                color: AppColors.trustBlue,
                size: 42,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (showDebugHelper)
            InfoBanner(title: 'Debug helper', message: _debugHelperMessage!),
          if (showDebugHelper) const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.card,
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = AppSpacing.xs;
                final width =
                    ((constraints.maxWidth - ((_otpLength - 1) * spacing)) /
                            _otpLength)
                        .clamp(40.0, 52.0)
                        .toDouble();

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    _otpLength,
                    (index) => SizedBox(
                      width: width,
                      child: TextField(
                        controller: _controllers[index],
                        focusNode: _focusNodes[index],
                        enabled: !_isLoading,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        maxLength: index == 0 ? _otpLength : 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(color: AppColors.trustBlueDark),
                        decoration: const InputDecoration(
                          counterText: '',
                          contentPadding: EdgeInsets.symmetric(
                            vertical: AppSpacing.md,
                          ),
                        ),
                        onChanged: (value) => _onOtpChanged(value, index),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            _resendRemaining > 0
                ? 'Resend code in 00:${_resendRemaining.toString().padLeft(2, '0')}'
                : "Didn't receive code?",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _resendRemaining > 0
                  ? AppColors.engagementOrange
                  : AppColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            text: 'Verify and continue',
            icon: Icons.verified_outlined,
            isLoading: _isLoading,
            onPressed: _verifyOtp,
          ),
          const SizedBox(height: AppSpacing.md),
          OutlineActionButton(
            text: 'Resend code',
            onPressed: _isLoading || _resendRemaining > 0
                ? null
                : _handleResendOtp,
            icon: Icons.refresh_rounded,
          ),
        ],
      ),
    );
  }
}
