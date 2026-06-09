import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/services/app_preferences.dart';
import 'core/services/session_service.dart';
import 'core/theme/colors.dart';
import 'core/theme/theme.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/emergency/services/supabase_realtime_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  await AppPreferences.ensureInitialized();
  await SessionService.ensureInitialized();
  await SupabaseRealtimeService.instance.initialize();
  runApp(const GuardianNodeApp());
}

class GuardianNodeApp extends StatelessWidget {
  const GuardianNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GuardianNode',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return _MobileAppShell(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

class _MobileAppShell extends StatelessWidget {
  const _MobileAppShell({required this.child});

  static const double _maxMobileWidth = 430;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : mediaQuery.size.width;
        final availableHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : mediaQuery.size.height;
        final isWide = availableWidth > 600;
        final appWidth = isWide ? _maxMobileWidth : availableWidth;

        return ColoredBox(
          color: isWide ? AppColors.backgroundAlt : AppColors.cleanWhite,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: appWidth,
              height: availableHeight,
              child: MediaQuery(
                data: mediaQuery.copyWith(
                  size: Size(appWidth, mediaQuery.size.height),
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.cleanWhite,
                    boxShadow: isWide
                        ? [
                            BoxShadow(
                              color: AppColors.shadow.withValues(alpha: 0.14),
                              blurRadius: 28,
                              offset: const Offset(0, 10),
                            ),
                          ]
                        : null,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
