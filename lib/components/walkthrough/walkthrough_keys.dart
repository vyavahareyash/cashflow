import 'package:flutter/material.dart';
import 'package:cashflow/components/walkthrough/walkthrough_constants.dart';

/// Central registry of GlobalKeys used by the Walkthrough Spotlight Overlay
/// to calculate exact screen coordinates of target widgets.
class WalkthroughKeys {
  static final GlobalKey balanceCardKey = GlobalKey(
    debugLabel: 'walkthrough_balance_card',
  );
  static final GlobalKey privacyToggleKey = GlobalKey(
    debugLabel: 'walkthrough_privacy_toggle',
  );
  static final GlobalKey voiceFabKey = GlobalKey(
    debugLabel: 'walkthrough_voice_fab',
  );
  static final GlobalKey goalsSummaryKey = GlobalKey(
    debugLabel: 'walkthrough_goals_summary',
  );
  static final GlobalKey accountsSummaryKey = GlobalKey(
    debugLabel: 'walkthrough_accounts_summary',
  );

  /// Resolves the corresponding GlobalKey for a given SpotlightTargetId.
  static GlobalKey? keyForTarget(SpotlightTargetId targetId) {
    switch (targetId) {
      case SpotlightTargetId.balanceCard:
        return balanceCardKey;
      case SpotlightTargetId.privacyToggle:
        return privacyToggleKey;
      case SpotlightTargetId.voiceFab:
        return voiceFabKey;
      case SpotlightTargetId.goalsTab:
        return goalsSummaryKey;
      case SpotlightTargetId.accountsTab:
        return accountsSummaryKey;
    }
  }
}
