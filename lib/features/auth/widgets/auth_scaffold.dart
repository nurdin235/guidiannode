import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/status_widgets.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.eyebrow,
    this.footer,
    this.showBackButton = true,
    this.badge,
    this.logoSize = 96,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final String? eyebrow;
  final Widget? footer;
  final bool showBackButton;
  final Widget? badge;
  final double logoSize;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cleanWhite,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Row(
                children: [
                  if (showBackButton)
                    IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                    )
                  else
                    const SizedBox(width: 48, height: 48),
                  const Spacer(),
                  ...?badge == null ? null : [badge!],
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: AppSpacing.screenPadding,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: GuardianLogo(size: logoSize)),
                    const SizedBox(height: AppSpacing.lg),
                    if (eyebrow != null)
                      Text(
                        eyebrow!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: AppColors.trustBlue,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    if (eyebrow != null) const SizedBox(height: AppSpacing.xs),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineLarge
                          ?.copyWith(
                            color: AppColors.trustBlue,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    child,
                    if (footer != null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      footer!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthHeroBadge extends StatelessWidget {
  const AuthHeroBadge({
    super.key,
    required this.label,
    this.tone = StatusTone.info,
  });

  final String label;
  final StatusTone tone;

  @override
  Widget build(BuildContext context) {
    return StatusBadge(label: label, tone: tone);
  }
}
