import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cashflow/components/walkthrough/walkthrough_concept_carousel.dart';
import 'package:cashflow/components/walkthrough/walkthrough_constants.dart';
import 'package:cashflow/services/database_helper.dart';
import 'package:cashflow/theme/theme_constants.dart';

/// Central state manager coordinating the walkthrough carousel, live spotlight tour,
/// tab transitions, and isolated demo database lifecycle.
class WalkthroughController extends ChangeNotifier {
  static final WalkthroughController instance = WalkthroughController._init();

  WalkthroughController._init();

  bool _isTourActive = false;
  bool get isTourActive => _isTourActive;

  int _currentStepIndex = 0;
  int get currentStepIndex => _currentStepIndex;

  void Function(int, {int? subTabIndex})? _onNavigateTab;

  /// Registers the navigation callback from MainNavigationScreen.
  void registerNavigationCallback(
    void Function(int, {int? subTabIndex}) onNavigateTab,
  ) {
    _onNavigateTab = onNavigateTab;
  }

  /// Launches the full sequential walkthrough (Concepts Carousel -> Live Screen Tour).
  Future<void> startFullWalkthrough(BuildContext context) async {
    await WalkthroughConceptCarousel.show(
      context,
      onTakeTour: () {
        unawaited(startScreenTour(context));
      },
      onFinish: () {
        unawaited(finishWithoutTour(context));
      },
      onSkip: () {
        unawaited(finishWithoutTour(context));
      },
    );
  }

  /// Launches only the Concept Cards review on-demand.
  Future<void> startConceptReview(BuildContext context) async {
    await WalkthroughConceptCarousel.show(
      context,
      onTakeTour: () {
        unawaited(startScreenTour(context));
      },
      onFinish: () {},
      onSkip: () {},
    );
  }

  /// Enters isolated demo mode and launches the step-by-step UI spotlight tour.
  Future<void> startScreenTour(BuildContext context) async {
    await DatabaseHelper.instance.enterWalkthroughDemoMode();

    _isTourActive = true;
    _currentStepIndex = 0;

    final firstStep = kSpotlightSteps.first;
    _onNavigateTab?.call(
      firstStep.tabIndex,
      subTabIndex: firstStep.subTabIndex,
    );

    notifyListeners();
  }

  /// Advances to the next spotlight step, automatically switching screens if required.
  void nextStep() {
    if (_currentStepIndex < kSpotlightSteps.length - 1) {
      _currentStepIndex++;
      final step = kSpotlightSteps[_currentStepIndex];
      _onNavigateTab?.call(step.tabIndex, subTabIndex: step.subTabIndex);
      notifyListeners();
    }
  }

  /// Moves back to the previous spotlight step.
  void previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      final step = kSpotlightSteps[_currentStepIndex];
      _onNavigateTab?.call(step.tabIndex, subTabIndex: step.subTabIndex);
      notifyListeners();
    }
  }

  /// Concludes the tour, safely restores user data, records completion,
  /// and shows the welcome start prompt.
  Future<void> finishTour(BuildContext context) async {
    _isTourActive = false;
    notifyListeners();

    await DatabaseHelper.instance.exitWalkthroughDemoMode();
    await DatabaseHelper.instance.setWalkthroughCompleted(completed: true);

    _onNavigateTab?.call(0);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Ready to start? Add your primary account or configure your salary day in Settings.',
          ),
          backgroundColor: AppColors.emerald700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Got it',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  /// Exits the tour early, safely restoring the user data and marking walkthrough handled.
  Future<void> exitTour(BuildContext context) async {
    _isTourActive = false;
    notifyListeners();

    await DatabaseHelper.instance.exitWalkthroughDemoMode();
    await DatabaseHelper.instance.setWalkthroughCompleted(completed: true);

    _onNavigateTab?.call(0);
  }

  /// Handles completion or skip from the concept carousel without running the spotlight tour.
  Future<void> finishWithoutTour(BuildContext context) async {
    await DatabaseHelper.instance.setWalkthroughCompleted(completed: true);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Welcome to Cashflow! Add your primary account to get started.',
          ),
          backgroundColor: AppColors.emerald700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
