import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/elevation.dart';
import '../theme/radii.dart';
import '../theme/spacing.dart';
import 'status_widgets.dart';

class GuardianLogo extends StatelessWidget {
  const GuardianLogo({
    super.key,
    this.size = 72,
    this.width,
    this.height,
    this.showWordmark = false,
    this.onDark = false,
    this.padding,
    this.semanticLabel = 'Guardian Node logo',
    this.transparent = false,
    this.glassmorphic = false,
    this.backgroundColor,
    this.borderRadius,
  });

  static const assetPath = 'assets/images/guardian_node_logo.png';

  final double size;
  final double? width;
  final double? height;
  final bool showWordmark;
  final bool onDark;
  final EdgeInsetsGeometry? padding;
  final String semanticLabel;
  final bool transparent;
  final bool glassmorphic;
  final Color? backgroundColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? AppColors.cleanWhite : AppColors.trustBlue;
    final resolvedWidth = width ?? size;
    final resolvedHeight = height ?? size;
    
    // Increased padding to make the icon fit cleaner and look more professional
    final resolvedPadding = padding ?? EdgeInsets.all(size * 0.12);

    Color bg;
    if (transparent) {
      bg = Colors.transparent;
    } else if (backgroundColor != null) {
      bg = backgroundColor!;
    } else if (glassmorphic) {
      bg = AppColors.cleanWhite.withValues(alpha: 0.15);
    } else {
      bg = AppColors.cleanWhite;
    }

    final borderRad = borderRadius ?? (size * 0.22);

    final mark = Semantics(
      image: true,
      label: semanticLabel,
      child: Container(
        width: resolvedWidth,
        height: resolvedHeight,
        padding: resolvedPadding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(borderRad),
          border: glassmorphic
              ? Border.all(
                  color: AppColors.cleanWhite.withValues(alpha: 0.25),
                  width: 1.5,
                )
              : null,
          boxShadow: onDark && !transparent && !glassmorphic
              ? AppElevation.soft
              : null,
        ),
        child: Image.asset(
          assetPath,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
          errorBuilder: (context, error, stackTrace) => Icon(
            Icons.shield_rounded,
            color: onDark ? AppColors.cleanWhite : AppColors.trustBlue,
            size: size * 0.72,
          ),
        ),
      ),
    );

    if (!showWordmark) {
      return mark;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: AppSpacing.sm),
        Text(
          'GuardianNode',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }
}

class GuardianAppBar extends StatelessWidget {
  const GuardianAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.actions = const [],
    this.showLogo = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;
  final bool showLogo;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          leading ??
              (showLogo
                  ? const GuardianLogo(size: 40, padding: EdgeInsets.all(3))
                  : IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                      ),
                    )),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

class QuickActionTile extends StatelessWidget {
  const QuickActionTile({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: AppColors.surface,
        borderRadius: AppRadii.card,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.card,
          child: Ink(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: AppRadii.card,
              border: Border.all(color: AppColors.border),
              boxShadow: AppElevation.soft,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: AppRadii.card,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    height: 1.1,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmergencyCategoryCard extends StatelessWidget {
  const EmergencyCategoryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: AppRadii.card,
            border: Border.all(color: color.withValues(alpha: 0.18)),
            boxShadow: AppElevation.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: AppRadii.card,
                ),
                child: Icon(icon, color: AppColors.cleanWhite, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color == AppColors.communityYellow
                      ? AppColors.textPrimary
                      : color,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlertProgressStep extends StatelessWidget {
  const AlertProgressStep({
    super.key,
    required this.label,
    required this.status,
    required this.tone,
    this.isLoading = false,
  });

  final String label;
  final String status;
  final StatusTone tone;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final icon = switch (tone) {
      StatusTone.success => Icons.check_circle_rounded,
      StatusTone.warning => Icons.schedule_rounded,
      StatusTone.error => Icons.error_rounded,
      StatusTone.info => Icons.info_rounded,
      StatusTone.action => Icons.radio_button_checked_rounded,
    };
    final color = switch (tone) {
      StatusTone.success => AppColors.safetyGreen,
      StatusTone.warning => AppColors.communityYellow,
      StatusTone.error => AppColors.error,
      StatusTone.info => AppColors.trustBlue,
      StatusTone.action => AppColors.engagementOrange,
    };

    return Row(
      children: [
        isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : Icon(icon, color: color, size: 22),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          status,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: color == AppColors.communityYellow
                ? AppColors.textSecondary
                : color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class AlertDetailsCard extends StatelessWidget {
  const AlertDetailsCard({
    super.key,
    required this.rows,
    this.title = 'Alert Details',
  });

  final String title;
  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.card,
        border: Border.all(color: AppColors.border),
        boxShadow: AppElevation.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          ...rows.entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: Text(
                      entry.value,
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: AppRadii.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.card,
        child: Ink(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: AppRadii.card,
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.trustBlueSurface,
                  borderRadius: AppRadii.card,
                ),
                child: Icon(icon, color: AppColors.trustBlue, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              trailing ?? const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileStatCard extends StatelessWidget {
  const ProfileStatCard({
    super.key,
    required this.value,
    required this.label,
    this.onDark = false,
  });

  final String value;
  final String label;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: onDark ? AppColors.cleanWhite : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onDark
                  ? AppColors.cleanWhite.withValues(alpha: 0.75)
                  : AppColors.textTertiary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.backgroundAlt,
        borderRadius: AppRadii.pill,
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = index == selectedIndex;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.trustBlue : Colors.transparent,
                  borderRadius: AppRadii.pill,
                ),
                child: Text(
                  tabs[index],
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: isSelected
                        ? AppColors.cleanWhite
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onChanged,
    required this.onSos,
  });

  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final items = [
      _BottomNavItem(Icons.home_outlined, Icons.home_rounded, 'Home', 0),
      _BottomNavItem(
        Icons.notifications_none_rounded,
        Icons.notifications_rounded,
        'Alerts',
        2,
      ),
      _BottomNavItem(Icons.map_outlined, Icons.map_rounded, 'Map', 1),
      _BottomNavItem(
        Icons.history_rounded,
        Icons.history_rounded,
        'History',
        3,
      ),
      _BottomNavItem(
        Icons.person_outline_rounded,
        Icons.person_rounded,
        'Profile',
        4,
      ),
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
        decoration: BoxDecoration(
          color: AppColors.cleanWhite,
          border: const Border(top: BorderSide(color: AppColors.divider)),
          boxShadow: AppElevation.soft,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i == 2)
                Expanded(
                  child: Center(
                    child: Semantics(
                      button: true,
                      label: 'Open SOS emergency categories',
                      child: GestureDetector(
                        onTap: onSos,
                        child: Container(
                          width: 52,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.engagementOrange,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            'SOS',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.cleanWhite,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: _NavButton(
                  item: items[i],
                  current: selectedIndex,
                  onTap: onChanged,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BottomNavItem {
  const _BottomNavItem(this.icon, this.selectedIcon, this.label, this.index);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final int index;
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.current,
    required this.onTap,
  });

  final _BottomNavItem item;
  final int current;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = current == item.index;

    return InkWell(
      onTap: () => onTap(item.index),
      borderRadius: AppRadii.card,
      child: SizedBox(
        height: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? item.selectedIcon : item.icon,
              color: isSelected ? AppColors.trustBlue : AppColors.textTertiary,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isSelected
                    ? AppColors.trustBlue
                    : AppColors.textTertiary,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
