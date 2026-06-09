import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/guardian_components.dart';
import 'permissions_education_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const PermissionsEducationScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cleanWhite,
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _continue(context),
                child: const Text('Skip'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            const Center(child: GuardianLogo(size: 88)),
            const SizedBox(height: AppSpacing.xl),
            Text(
              "We've got your back,\nBamenda.",
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: AppColors.trustBlue,
                fontWeight: FontWeight.w900,
                height: 1.08,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'GuardianNode connects you to help and your community when it matters most.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppColors.textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            const _OnboardingCard(
              icon: Icons.shield_rounded,
              title: 'Quick Alerts',
              message: 'Send SOS and get help fast.',
              color: AppColors.trustBlue,
            ),
            const SizedBox(height: AppSpacing.md),
            const _OnboardingCard(
              icon: Icons.groups_rounded,
              title: 'Nearby Community',
              message: 'Trusted nearby users are notified.',
              color: AppColors.safetyGreen,
            ),
            const SizedBox(height: AppSpacing.md),
            const _OnboardingCard(
              icon: Icons.notifications_active_rounded,
              title: 'Stay Informed',
              message: 'Get real-time updates on your alerts.',
              color: AppColors.communityYellow,
            ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: index == 0 ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? AppColors.trustBlue
                        : AppColors.disabled.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              text: 'Get Started',
              onPressed: () => _continue(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingCard extends StatelessWidget {
  const _OnboardingCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final foreground = color == AppColors.communityYellow
        ? AppColors.textPrimary
        : color;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.cleanWhite,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: foreground, size: 25),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.25,
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
