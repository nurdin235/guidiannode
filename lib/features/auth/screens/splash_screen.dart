import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/services/app_preferences.dart';
import '../../../core/services/session_service.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/spacing.dart';
import '../../emergency/screens/dashboard_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth 900ms cinematic entry animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    await AppPreferences.ensureInitialized();
    // Slightly longer delay for the user to admire the premium opening animation
    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (!mounted) {
      return;
    }

    final destination = SessionService.isAuthenticated
        ? const DashboardScreen()
        : AppPreferences.hasSeenOnboarding
        ? const LoginScreen()
        : const OnboardingScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenHeight = mediaQuery.size.height;
    final logoSize = (screenHeight * 0.15).clamp(110.0, 130.0);
    final spacing = (screenHeight * 0.03).clamp(12.0, 24.0);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: AppColors.emergencyGradient,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: (screenHeight * 0.2).clamp(100.0, 140.0),
              child: CustomPaint(painter: _BamendaSilhouettePainter()),
            ),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: ScaleTransition(
                  scale: _scaleAnimation,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: IntrinsicHeight(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.xl,
                              ),
                              child: Column(
                                children: [
                                  const Spacer(flex: 3),
                                  Container(
                                    width: logoSize,
                                    height: logoSize,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(logoSize * 0.22),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.08),
                                          blurRadius: 16,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    padding: EdgeInsets.all(logoSize * 0.15),
                                    child: Image.asset(
                                      'assets/images/guardian_node_logo.png',
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, error, stackTrace) => Icon(
                                        Icons.shield_rounded,
                                        color: AppColors.trustBlue,
                                        size: logoSize * 0.6,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: spacing),
                                  Text(
                                    'GuardianNode',
                                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      fontSize: (screenHeight * 0.034).clamp(24.0, 30.0),
                                    ),
                                  ),
                                  SizedBox(height: spacing * 0.6),
                                  Text(
                                    'Help is one tap away.\nStronger together,\nsafer Bamenda.',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      height: 1.35,
                                      fontSize: (screenHeight * 0.022).clamp(18.0, 21.0),
                                    ),
                                  ),
                                  SizedBox(height: spacing),
                                  Container(
                                    width: 80,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(99)),
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.trustBlueDark,
                                          AppColors.safetyGreen,
                                          AppColors.engagementOrange,
                                          AppColors.communityYellow,
                                        ],
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: spacing * 1.2),
                                  const SizedBox(
                                    width: 28,
                                    height: 28,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  ),
                                  const Spacer(flex: 4),
                                  Text(
                                    "Bamenda, We've Got You.",
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.85),
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
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

class _BamendaSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Reduced opacities to make the silhouette a subtle, faint background watermark
    final mountainPaint = Paint()
      ..color = AppColors.cleanWhite.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;
    final townPaint = Paint()
      ..color = AppColors.cleanWhite.withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;
    final monumentPaint = Paint()
      ..color = AppColors.cleanWhite.withValues(alpha: 0.12)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final mountains = Path()
      ..moveTo(0, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.22,
        size.height * 0.34,
        size.width * 0.42,
        size.height * 0.68,
      )
      ..quadraticBezierTo(
        size.width * 0.62,
        size.height * 0.28,
        size.width,
        size.height * 0.58,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(mountains, mountainPaint);

    for (var i = 0; i < 7; i++) {
      final left = size.width * (0.18 + i * 0.09);
      final top = size.height * (0.72 - (i.isEven ? 0.04 : 0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, size.width * 0.055, size.height * 0.12),
          const Radius.circular(3),
        ),
        townPaint,
      );
    }

    final center = Offset(size.width * 0.5, size.height * 0.48);
    canvas.drawLine(
      Offset(center.dx, center.dy + 54),
      Offset(center.dx, center.dy - 20),
      monumentPaint,
    );
    canvas.drawLine(
      Offset(center.dx - 17, center.dy + 54),
      Offset(center.dx + 17, center.dy + 54),
      monumentPaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 20),
      Offset(center.dx + 11, center.dy - 5),
      monumentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
