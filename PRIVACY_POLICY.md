# Privacy Policy for Cashflow

**Last Updated**: October 19, 2026

Cashflow is an offline-first personal finance and expense tracking application designed with user privacy as a foundational principle.

## 1. No Personal Data Collection
- Cashflow does **not** collect, harvest, transmit, or monitor any personal information, financial data, device identifiers, or usage metrics.
- All transactions, accounts, categories, and financial goals recorded in Cashflow reside exclusively on your local device storage.

## 2. Network Usage & Zero Outbound Telemetry
- Cashflow has zero cloud backends, zero remote telemetry, zero analytics trackers, and zero advertising SDKs.
- The network permission (`android.permission.INTERNET`) is utilized **exclusively** for user-initiated downloading of static, verified open-source AI model weights (SmolLM2 GGUF) from public repositories (such as Hugging Face) with SHA-256 integrity validation.
- No financial data, transaction logs, device data, or user queries are ever transmitted over the network.

## 3. Microphone & Audio Processing
- The microphone permission (`android.permission.RECORD_AUDIO`) is requested solely when you choose to use the optional Voice Journaling feature.
- Speech recognition is processed entirely on-device using platform-native speech recognition services.
- Audio streams exist strictly in volatile memory during active dictation and are immediately discarded. No audio recordings or voice data are ever saved to storage, uploaded, or transmitted.

## 4. Biometric Authentication
- The biometric permission (`android.permission.USE_BIOMETRIC`) is utilized solely for the optional App Lock security feature.
- Authentication is handled entirely by your operating system's secure hardware enclave. Cashflow never accesses, reads, collects, or stores your biometric data.

## 5. SMS & Financial Transaction Data
- The SMS permissions (`android.permission.RECEIVE_SMS`, `android.permission.READ_SMS`) are requested strictly for offline money management and automatic transaction tracking.
- Cashflow inspects only incoming and existing transactional and banking SMS notifications to parse transaction amounts, dates, and merchant descriptions.
- The notification permission (`android.permission.POST_NOTIFICATIONS`) is used strictly to alert you locally on-device when a bank transaction is detected, allowing you to review and confirm draft transactions before adding them to your ledger. Notifications are generated locally and contain no tracking or analytics.
- All SMS parsing is performed entirely on-device (via local rule-based heuristics and local on-device SLM inference).
- Personal SMS, non-financial messages, contact details, and OTPs/passwords are never collected, logged, or retained.
- No SMS content or extracted data is ever transmitted off the device, sold, or shared with third parties.

## 6. Local Data Storage & Security
- All application data is stored in a private local SQLite database contained within the app's sandboxed storage directory on your device.
- Data remains strictly on your device and is permanently deleted if you uninstall the application or clear application data through your device settings.

## 7. Local Backup & Export
- Cashflow allows you to manually export your financial ledger to JSON, CSV, or raw SQLite backup files and restore previous backups.
- Export files are written only to storage locations explicitly selected by you via your operating system's native file picker. Cashflow does not upload, sync, or transmit these files to any external service.

## 8. Third-Party Services & Libraries
- Cashflow does not integrate with any third-party tracking, advertising, analytics, or behavioral profiling software development kits (SDKs).

## 9. Children's Privacy
- Cashflow does not collect, store, or share information from anyone, including children under the age of 13.

## 10. Changes to This Privacy Policy
- Because Cashflow does not collect personal data, changes to this policy will be infrequent and will be reflected directly in this document and accompanying repository updates.

## 11. Contact Information
- If you have questions regarding this Privacy Policy or Cashflow's privacy architecture, please open an issue in the public GitHub repository: [https://github.com/vyavahareyash/cashflow](https://github.com/vyavahareyash/cashflow).
