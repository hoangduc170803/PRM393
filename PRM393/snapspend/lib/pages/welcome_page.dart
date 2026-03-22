import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:snapspend/theme/app_colors.dart';
import 'download_model_page.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _continue() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboardingAndContinue();
    }
  }

  Future<void> _completeOnboardingAndContinue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const DownloadModelPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Background ambient glows
          Positioned(
            top: -SizeConfig.screenHeight(context) * 0.1,
            right: -SizeConfig.screenWidth(context) * 0.1,
            child: Container(
              width: SizeConfig.screenWidth(context) * 0.5,
              height: SizeConfig.screenWidth(context) * 0.5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.05),
                    blurRadius: 100,
                    spreadRadius: 50,
                  )
                ],
              ),
            ),
          ),
          Positioned(
            bottom: -SizeConfig.screenHeight(context) * 0.05,
            left: -SizeConfig.screenWidth(context) * 0.1,
            child: Container(
              width: SizeConfig.screenWidth(context) * 0.4,
              height: SizeConfig.screenWidth(context) * 0.4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tertiary.withOpacity(0.05),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tertiary.withOpacity(0.05),
                    blurRadius: 80,
                    spreadRadius: 40,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Header (Top Branding Anchor)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Center(
                    child: Text(
                      'SnapSpend',
                      style: GoogleFonts.manrope(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),

                // Carousel
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    physics: const BouncingScrollPhysics(),
                    children: const [
                      _Step1View(),
                      _Step2View(),
                      _Step3View(),
                    ],
                  ),
                ),

                // Footer (Bottom Action Area)
                Container(
                  padding: const EdgeInsets.only(left: 32, right: 32, bottom: 48, top: 24),
                  decoration: BoxDecoration(
                    color: AppColors.background.withOpacity(0.8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Pill Indicators
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(3, (index) {
                              final isActive = _currentPage == index;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                margin: const EdgeInsets.symmetric(horizontal: 5),
                                width: isActive ? 32 : 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? AppColors.primary
                                      : AppColors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(5),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                            color: AppColors.primary.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 0),
                                          )
                                        ]
                                      : [],
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 40),

                          // Get Started / Continue Button
                          GestureDetector(
                            onTap: _continue,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: double.infinity,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(32),
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primary,
                                    AppColors.primaryContainer,
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.2),
                                    blurRadius: 24,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _currentPage == 2 ? 'Get Started' : 'Continue',
                                    style: GoogleFonts.manrope(
                                      color: AppColors.onPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.arrow_forward,
                                    color: AppColors.onPrimary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Login Link
                          RichText(
                            text: TextSpan(
                              text: 'Already have an account? ',
                              style: GoogleFonts.inter(
                                color: AppColors.onSurfaceVariant,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              children: [
                                TextSpan(
                                  text: 'Log In',
                                  style: GoogleFonts.inter(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
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

class _Step1View extends StatelessWidget {
  const _Step1View();
  @override
  Widget build(BuildContext context) {
    return _BaseStepView(
      title: 'Seamless Scanning',
      description: 'Capture receipts effortlessly and let our intelligent engine parse the data instantly.',
      buildIconContent: () {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 224,
              height: 224,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 10,
                  )
                ],
              ),
            ),
            Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(11, 15, 16, 0.06),
                    blurRadius: 48,
                    offset: Offset(0, 24),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    size: 80,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Step2View extends StatelessWidget {
  const _Step2View();
  @override
  Widget build(BuildContext context) {
    return _BaseStepView(
      title: 'AI-Powered Insights',
      description: 'Our intelligent engine decodes your spending habits to provide personalized advice.',
      buildIconContent: () {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 288,
              height: 288,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 50,
                    spreadRadius: 20,
                  )
                ],
              ),
            ),
            Container(
              width: 224,
              height: 224,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest.withOpacity(0.7),
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                boxShadow: const [
                  BoxShadow(
                    color: Color.fromRGBO(11, 15, 16, 0.06),
                    blurRadius: 48,
                    offset: Offset(0, 24),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(
                        Icons.psychology_rounded,
                        size: 100,
                        color: AppColors.primary,
                      ),
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: AppColors.tertiary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              )
                            ],
                          ),
                          child: const Icon(
                            Icons.photo_camera_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Step3View extends StatelessWidget {
  const _Step3View();
  @override
  Widget build(BuildContext context) {
    return _BaseStepView(
      title: 'Smart Analytics',
      description: 'Elegant line charts track your progress and help you save more effectively.',
      buildIconContent: () {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 256,
              height: 256,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.tertiary.withOpacity(0.1),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.tertiary.withOpacity(0.1),
                    blurRadius: 40,
                    spreadRadius: 20,
                  )
                ],
              ),
            ),
            const Icon(
              Icons.analytics,
              size: 120,
              color: AppColors.tertiary,
            ),
          ],
        );
      },
    );
  }
}

class _BaseStepView extends StatelessWidget {
  final String title;
  final String description;
  final Widget Function() buildIconContent;

  const _BaseStepView({
    required this.title,
    required this.description,
    required this.buildIconContent,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 16),
            buildIconContent(),
            const SizedBox(height: 32),
            Text(
              title,
              style: GoogleFonts.manrope(
                fontSize: 32, // slightly smaller for small screens
                fontWeight: FontWeight.w800,
                color: AppColors.onSurface,
                letterSpacing: -1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                description,
                style: GoogleFonts.inter(
                  fontSize: 16, // slightly smaller for small screens
                  color: AppColors.onSurfaceVariant,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class SizeConfig {
  static double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) => MediaQuery.of(context).size.height;
}
