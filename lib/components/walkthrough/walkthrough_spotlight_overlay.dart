import 'package:flutter/material.dart';
import 'package:cashflow/components/walkthrough/walkthrough_constants.dart';
import 'package:cashflow/components/walkthrough/walkthrough_keys.dart';
import 'package:cashflow/theme/theme_constants.dart';

/// Full-screen interactive spotlight overlay that highlights live UI widgets,
/// explains them with a floating tooltip card, and allows step-by-step navigation.
class WalkthroughSpotlightOverlay extends StatefulWidget {
  final int currentStepIndex;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onExit;
  final VoidCallback onFinish;

  const WalkthroughSpotlightOverlay({
    super.key,
    required this.currentStepIndex,
    required this.onNext,
    required this.onPrevious,
    required this.onExit,
    required this.onFinish,
  });

  @override
  State<WalkthroughSpotlightOverlay> createState() =>
      _WalkthroughSpotlightOverlayState();
}

class _WalkthroughSpotlightOverlayState
    extends State<WalkthroughSpotlightOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  Rect? _targetRect;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _resolveTargetRect();
  }

  @override
  void didUpdateWidget(WalkthroughSpotlightOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentStepIndex != widget.currentStepIndex) {
      _resolveTargetRect();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _resolveTargetRect({int attempt = 0}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.currentStepIndex >= kSpotlightSteps.length) return;

      final step = kSpotlightSteps[widget.currentStepIndex];
      final key = WalkthroughKeys.keyForTarget(step.targetId);

      if (key?.currentContext != null) {
        final renderBox = key!.currentContext!.findRenderObject() as RenderBox?;
        if (renderBox != null && renderBox.hasSize) {
          final offset = renderBox.localToGlobal(Offset.zero);
          final rect = offset & renderBox.size;
          setState(() {
            _targetRect = rect;
          });
          return;
        }
      }

      // Retry only if key exists in element tree but renderObject hasn't laid out yet
      if (attempt < 2 && key?.currentContext != null) {
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _resolveTargetRect(attempt: attempt + 1);
        });
      } else {
        // Fallback to center spotlight if target widget is not mounted or already tried
        final size = MediaQuery.of(context).size;
        setState(() {
          _targetRect = Rect.fromCenter(
            center: Offset(size.width / 2, size.height * 0.35),
            width: size.width * 0.85,
            height: 120,
          );
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;
    final currentStep = kSpotlightSteps[widget.currentStepIndex];
    final isLastStep = widget.currentStepIndex == kSpotlightSteps.length - 1;

    return Stack(
      children: [
        // Touch blocker and cut-out painter
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {}, // Blocks touches behind the overlay
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                return CustomPaint(
                  painter: _SpotlightPainter(
                    targetRect: _targetRect,
                    pulseFactor: _pulseController.value,
                  ),
                );
              },
            ),
          ),
        ),

        // Top Demo Mode Banner
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: _buildDemoBanner(isDark),
            ),
          ),
        ),

        // Floating Tooltip Card
        if (_targetRect != null)
          _buildFloatingTooltip(
            context,
            step: currentStep,
            isLastStep: isLastStep,
            isDark: isDark,
            screenSize: size,
          ),
      ],
    );
  }

  Widget _buildDemoBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E3128) : AppColors.emerald50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.emerald600 : AppColors.emerald300,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.explore_rounded,
            size: 16,
            color: AppColors.emerald600,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'Walkthrough Demo Mode — Your data is preserved',
              style: AppTypography.labelSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.emerald300 : AppColors.emerald800,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            key: const Key('walkthrough_exit_banner_button'),
            onTap: widget.onExit,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.1,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                size: 14,
                color: isDark ? AppColors.emerald200 : AppColors.emerald900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingTooltip(
    BuildContext context, {
    required SpotlightStep step,
    required bool isLastStep,
    required bool isDark,
    required Size screenSize,
  }) {
    final rect = _targetRect!;
    const cardHeight = 220.0;
    const margin = 16.0;

    // Determine whether to place tooltip below or above the target rect
    final spaceBelow = screenSize.height - rect.bottom;
    final placeBelow = spaceBelow >= cardHeight || spaceBelow > rect.top;

    final topPosition = placeBelow
        ? (rect.bottom + 14).clamp(
            margin,
            screenSize.height - cardHeight - margin,
          )
        : (rect.top - cardHeight - 14).clamp(
            margin,
            screenSize.height - cardHeight - margin,
          );

    return Positioned(
      top: topPosition,
      left: margin,
      right: margin,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF192721) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isDark ? AppColors.emerald600 : AppColors.emerald200,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge and Step Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.emerald600.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${step.badgeText.toUpperCase()} • ${widget.currentStepIndex + 1}/${kSpotlightSteps.length}',
                      style: AppTypography.labelSmall.copyWith(
                        color: isDark
                            ? AppColors.emerald300
                            : AppColors.emerald700,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  TextButton(
                    key: const Key('walkthrough_exit_tour_button'),
                    onPressed: widget.onExit,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: isDark
                          ? AppColors.gray400
                          : AppColors.gray600,
                      padding: EdgeInsets.zero,
                    ),
                    child: const Text('Exit Tour'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                step.title,
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? Colors.white : AppColors.gray900,
                ),
              ),
              const SizedBox(height: 6),

              // Description
              Text(
                step.description,
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12.5,
                  height: 1.45,
                  color: isDark ? AppColors.gray300 : AppColors.gray700,
                ),
              ),
              const SizedBox(height: 14),

              // Navigation Buttons: Back / Next or Finish
              Row(
                children: [
                  if (widget.currentStepIndex > 0)
                    TextButton(
                      key: const Key('walkthrough_tour_prev_button'),
                      onPressed: widget.onPrevious,
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? AppColors.gray300
                            : AppColors.gray700,
                      ),
                      child: const Text('Back'),
                    )
                  else
                    const Spacer(),
                  if (widget.currentStepIndex > 0) const Spacer(),
                  if (isLastStep)
                    ElevatedButton.icon(
                      key: const Key('walkthrough_tour_finish_button'),
                      onPressed: widget.onFinish,
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Finish Tour'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      key: const Key('walkthrough_tour_next_button'),
                      onPressed: widget.onNext,
                      iconAlignment: IconAlignment.end,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Next Step'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? targetRect;
  final double pulseFactor;

  _SpotlightPainter({required this.targetRect, required this.pulseFactor});

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.76)
      ..style = PaintingStyle.fill;

    final screenRect = Rect.fromLTWH(0, 0, size.width, size.height);

    if (targetRect == null) {
      canvas.drawRect(screenRect, backgroundPaint);
      return;
    }

    // Cutout with padding and rounded corners
    final inflated = targetRect!.inflate(6);
    final cutoutRRect = RRect.fromRectAndRadius(
      inflated,
      const Radius.circular(16),
    );

    final path = Path()
      ..addRect(screenRect)
      ..addRRect(cutoutRRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);

    // Glowing border around cutout
    final pulseOffset = pulseFactor * 3.0;
    final pulseRRect = RRect.fromRectAndRadius(
      inflated.inflate(pulseOffset),
      const Radius.circular(18),
    );

    final glowPaint = Paint()
      ..color = AppColors.emerald500.withValues(alpha: 0.5 + pulseFactor * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawRRect(pulseRRect, glowPaint);
  }

  @override
  bool shouldRepaint(_SpotlightPainter oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.pulseFactor != pulseFactor;
  }
}
