import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/widgets/guardian_components.dart';
import '../../../core/widgets/status_widgets.dart';

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.content,
  });

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final sections = content
        .split('\n\n')
        .where((section) => section.isNotEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            const GuardianLogo(size: 38, padding: EdgeInsets.all(3)),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(title)),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.screenPadding,
          children: [
            const InfoBanner(
              title: 'Policy overview',
              message:
                  'These documents explain how GuardianNode handles access, safety expectations, and emergency-related data.',
            ),
            const SizedBox(height: AppSpacing.lg),
            ...sections.map(
              (section) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: Text(
                  section,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                    height: 1.7,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
