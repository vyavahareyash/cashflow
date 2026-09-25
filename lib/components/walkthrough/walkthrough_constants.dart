import 'package:flutter/material.dart';
import 'package:cashflow/theme/theme_constants.dart';

/// Represents a single educational slide in the concept deck.
class WalkthroughConcept {
  final String title;
  final String tag;
  final String description;
  final String? formula;
  final IconData icon;
  final Color iconColor;
  final List<String> bulletPoints;

  const WalkthroughConcept({
    required this.title,
    required this.tag,
    required this.description,
    this.formula,
    required this.icon,
    required this.iconColor,
    required this.bulletPoints,
  });
}

/// The 5 core architectural and financial concepts of Cashflow.
const List<WalkthroughConcept> kWalkthroughConcepts = [
  WalkthroughConcept(
    title: '100% Offline & Private',
    tag: 'OFFLINE-FIRST PRIVACY',
    description: 'Your financial data never leaves your device. Cashflow has zero cloud servers, zero trackers, and zero network dependencies.',
    formula: 'Zero Cloud Sync • Local SQLite Storage',
    icon: Icons.shield_outlined,
    iconColor: AppColors.emerald500,
    bulletPoints: [
      'Complete local ownership of your records',
      'Encrypted on-device SQLite database',
      'Instant privacy masking for public spaces',
    ],
  ),
  WalkthroughConcept(
    title: 'Safe-to-Spend Usable Balance',
    tag: 'TRULY DISPOSABLE CASH',
    description: 'Never accidentally spend money earmarked for savings. Cashflow isolates your actual disposable cash from locked goal funds.',
    formula: 'Safe-to-Spend = Physical Balance − Goal Locks',
    icon: Icons.account_balance_wallet_outlined,
    iconColor: AppColors.emerald600,
    bulletPoints: [
      'Separates true spending cash from bank totals',
      'Guarantees your savings remain untouched',
      'Clamped at ₹0 if commitments exceed funds',
    ],
  ),
  WalkthroughConcept(
    title: 'Virtual Goal Locks',
    tag: 'VIRTUAL SINKING FUNDS',
    description: 'Reserve funds inside your existing bank accounts for specific goals without opening new accounts or transferring between banks.',
    formula: 'Earmark Funds Within Any Account',
    icon: Icons.lock_outline_rounded,
    iconColor: AppColors.warning,
    bulletPoints: [
      'Virtual envelope reservations within accounts',
      'Lock funds with one tap to protect goals',
      'Release or execute goal purchases seamlessly',
    ],
  ),
  WalkthroughConcept(
    title: 'Payday Cycle & Daily Burn',
    tag: 'SALARY-ANCHORED PACING',
    description: 'Budget along your real income rhythm. Anchor your monthly spending period to your actual payday rather than calendar month boundaries.',
    formula: 'Daily Burn Pace = Allowable / Actual Spend Rate',
    icon: Icons.calendar_month_outlined,
    iconColor: AppColors.info,
    bulletPoints: [
      'Configure your monthly salary day in Settings',
      'Real-time daily burn pace alerts you when rushing',
      'Budgets pace smoothly until your next paycheck',
    ],
  ),
  WalkthroughConcept(
    title: 'Private Voice Journaling',
    tag: 'ON-DEVICE AI LOGGING',
    description: 'Speak naturally to log expenses in seconds. On-device Whisper and local SLM models parse spoken sentences into draft transactions with zero server calls.',
    formula: 'Spoken Voice → Local SLM → Draft Transaction',
    icon: Icons.mic_none_rounded,
    iconColor: AppColors.purple,
    bulletPoints: [
      '100% on-device speech-to-text & parsing',
      'Smart account, category & amount recognition',
      'Review and edit drafts before anything is saved',
    ],
  ),
];

/// Step target identifiers for the live UI spotlight walkthrough.
enum SpotlightTargetId {
  balanceCard,
  privacyToggle,
  voiceFab,
  goalsTab,
  accountsTab,
}

/// Represents a single spotlight step in the guided screen tour.
class SpotlightStep {
  final SpotlightTargetId targetId;
  final String title;
  final String description;
  final int tabIndex;
  final int? subTabIndex;
  final String badgeText;

  const SpotlightStep({
    required this.targetId,
    required this.title,
    required this.description,
    required this.tabIndex,
    this.subTabIndex,
    required this.badgeText,
  });
}

/// Ordered sequence of spotlight steps covering Dashboard, Goals, and Accounts.
const List<SpotlightStep> kSpotlightSteps = [
  SpotlightStep(
    targetId: SpotlightTargetId.balanceCard,
    title: 'Safe-to-Spend Balance Card',
    description: 'This is your real disposable cash after deducting all active goal locks. It shows your Physical Cash minus Locked Allocations.',
    tabIndex: 0,
    badgeText: 'Dashboard',
  ),
  SpotlightStep(
    targetId: SpotlightTargetId.privacyToggle,
    title: 'Privacy Mode Toggle',
    description: 'Tap this eye icon anytime to mask your balances and transaction amounts with bullet points when you are in public.',
    tabIndex: 0,
    badgeText: 'Privacy',
  ),
  SpotlightStep(
    targetId: SpotlightTargetId.voiceFab,
    title: 'AI Voice Journaling & Quick Add',
    description: 'Tap the center microphone button to speak your expenses naturally. Cashflow transcribes and drafts transactions 100% offline.',
    tabIndex: 0,
    badgeText: 'Quick Entry',
  ),
  SpotlightStep(
    targetId: SpotlightTargetId.goalsTab,
    title: 'Sinking Funds & Goal Locks',
    description: 'Goals let you earmark savings for emergency funds, vacations, or gadgets directly inside your existing bank accounts.',
    tabIndex: 3,
    subTabIndex: 2,
    badgeText: 'Sinking Funds',
  ),
  SpotlightStep(
    targetId: SpotlightTargetId.accountsTab,
    title: 'Accounts & Physical Cash',
    description: 'Track balances across your bank accounts, cash wallets, and credit cards. Your total physical cash aggregates right here.',
    tabIndex: 3,
    subTabIndex: 0,
    badgeText: 'Accounts',
  ),
];
