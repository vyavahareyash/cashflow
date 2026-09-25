import 'package:flutter/material.dart';
import 'package:cashflow/components/walkthrough/walkthrough_constants.dart';
import 'package:cashflow/theme/theme_constants.dart';

/// Modal dialog presenting the 5 core financial and architectural concepts of Cashflow
/// through a swipeable card deck carousel.
class WalkthroughConceptCarousel extends StatefulWidget {
  final VoidCallback onTakeTour;
  final VoidCallback onFinish;
  final VoidCallback onSkip;

  const WalkthroughConceptCarousel({
    super.key,
    required this.onTakeTour,
    required this.onFinish,
    required this.onSkip,
  });

  /// Displays the concept carousel in an adaptive dialog.
  static Future<void> show(
    BuildContext context, {
    required VoidCallback onTakeTour,
    required VoidCallback onFinish,
    required VoidCallback onSkip,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => WalkthroughConceptCarousel(
        onTakeTour: () {
          Navigator.of(dialogContext).pop();
          onTakeTour();
        },
        onFinish: () {
          Navigator.of(dialogContext).pop();
          onFinish();
        },
        onSkip: () {
          Navigator.of(dialogContext).pop();
          onSkip();
        },
      ),
    );
  }

  @override
  State<WalkthroughConceptCarousel> createState() =>
      _WalkthroughConceptCarouselState();
}

class _WalkthroughConceptCarouselState
    extends State<WalkthroughConceptCarousel> {
  late final PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < kWalkthroughConcepts.length - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.height < 680;

    final backgroundColor = isDark ? const Color(0xFF16231E) : Colors.white;
    final cardBorderColor = isDark
        ? const Color(0xFF284136)
        : AppColors.gray200;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) widget.onSkip();
      },
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: cardBorderColor, width: 1.5),
        ),
        backgroundColor: backgroundColor,
        elevation: 16,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: isSmallScreen ? 430 : 470,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row: Tagline + Step counter + Skip Button
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'STEP ${_currentPage + 1} OF ${kWalkthroughConcepts.length}',
                        style: AppTypography.labelSmall.copyWith(
                          color: isDark
                              ? AppColors.emerald300
                              : AppColors.emerald700,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    TextButton(
                      key: const Key('walkthrough_skip_button'),
                      onPressed: widget.onSkip,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isDark
                            ? AppColors.gray400
                            : AppColors.gray600,
                      ),
                      child: const Text('Skip'),
                    ),
                  ],
                ),
              ),

              // PageView Content
              Expanded(
                child: PageView.builder(
                  key: const Key('walkthrough_concept_page_view'),
                  controller: _pageController,
                  itemCount: kWalkthroughConcepts.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    final concept = kWalkthroughConcepts[index];
                    return _buildConceptSlide(
                      concept,
                      isDark: isDark,
                      isSmallScreen: isSmallScreen,
                    );
                  },
                ),
              ),

              const Divider(height: 1),

              // Footer Controls: Dots + Back / Next / Action Buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: _buildFooterControls(isDark),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConceptSlide(
    WalkthroughConcept concept, {
    required bool isDark,
    required bool isSmallScreen,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Glowing Icon Container
          Container(
            width: isSmallScreen ? 46 : 52,
            height: isSmallScreen ? 46 : 52,
            decoration: BoxDecoration(
              color: concept.iconColor.withValues(alpha: isDark ? 0.20 : 0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: concept.iconColor.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
            child: Icon(
              concept.icon,
              size: isSmallScreen ? 24 : 26,
              color: concept.iconColor,
            ),
          ),
          const SizedBox(height: 8),

          // Concept Tag
          Text(
            concept.tag,
            style: AppTypography.labelSmall.copyWith(
              color: concept.iconColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              fontSize: 10.5,
            ),
          ),
          const SizedBox(height: 4),

          // Title
          Text(
            concept.title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isSmallScreen ? 17 : 18.5,
              color: isDark ? Colors.white : AppColors.gray900,
            ),
          ),
          const SizedBox(height: 6),

          // Description
          Text(
            concept.description,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(
              color: isDark ? AppColors.gray300 : AppColors.gray700,
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),

          // Formula or Badge Pill (if provided)
          if (concept.formula != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E3128) : AppColors.emerald50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? AppColors.emerald600.withValues(alpha: 0.35)
                      : AppColors.emerald200,
                ),
              ),
              child: Text(
                concept.formula!,
                textAlign: TextAlign.center,
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.emerald300 : AppColors.emerald800,
                  fontSize: 11,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          // Key Bullet Points
          ...concept.bulletPoints.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 15,
                      color: concept.iconColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      bullet,
                      style: AppTypography.bodySmall.copyWith(
                        color: isDark ? AppColors.gray300 : AppColors.gray700,
                        fontSize: 12,
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

  Widget _buildFooterControls(bool isDark) {
    final isLastPage = _currentPage == kWalkthroughConcepts.length - 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Dots Indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(kWalkthroughConcepts.length, (index) {
            final isSelected = _currentPage == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: isSelected ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.emerald600
                    : (isDark ? AppColors.gray700 : AppColors.gray300),
                borderRadius: BorderRadius.circular(3),
              ),
            );
          }),
        ),
        const SizedBox(height: 14),

        if (!isLastPage) ...[
          // Intermediate Pages: Back / Next
          Row(
            children: [
              if (_currentPage > 0)
                TextButton(
                  onPressed: _prevPage,
                  style: TextButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.gray300
                        : AppColors.gray700,
                  ),
                  child: const Text('Back'),
                )
              else
                const Spacer(),
              if (_currentPage > 0) const Spacer(),
              ElevatedButton.icon(
                key: const Key('walkthrough_next_button'),
                onPressed: _nextPage,
                iconAlignment: IconAlignment.end,
                icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                label: const Text('Next'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],
          ),
        ] else ...[
          // Final Slide: Two distinct options
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('walkthrough_explore_button'),
                  onPressed: widget.onFinish,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.gray300
                        : AppColors.gray800,
                    side: BorderSide(
                      color: isDark ? AppColors.gray700 : AppColors.gray300,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Explore App'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  key: const Key('walkthrough_take_tour_button'),
                  onPressed: widget.onTakeTour,
                  icon: const Icon(Icons.explore_rounded, size: 16),
                  label: const Text('Screen Tour'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald700,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
