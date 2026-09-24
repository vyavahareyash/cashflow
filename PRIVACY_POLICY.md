# Privacy Policy for Cashflow

**Last Updated**: September 24, 2026

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

## 5. Local Data Storage & Security
- All application data is stored in a private local SQLite database contained within the app's sandboxed storage directory on your device.
- Data remains strictly on your device and is permanently deleted if you uninstall the application or clear application data through your device settings.

## 6. Local Backup & Export
- Cashflow allows you to manually export your financial ledger to JSON, CSV, or raw SQLite backup files and restore previous backups.
- Export files are written only to storage locations explicitly selected by you via your operating system's native file picker. Cashflow does not upload, sync, or transmit these files to any external service.

## 7. Third-Party Services & Libraries
- Cashflow does not integrate with any third-party tracking, advertising, analytics, or behavioral profiling software development kits (SDKs).

## 8. Children's Privacy
- Cashflow does not collect, store, or share information from anyone, including children under the age of 13.

## 9. Changes to This Privacy Policy
- Because Cashflow does not collect personal data, changes to this policy will be infrequent and will be reflected directly in this document and accompanying repository updates.

## 10. Contact Information
- If you have questions regarding this Privacy Policy or Cashflow's privacy architecture, please open an issue in the public GitHub repository: [https://github.com/vyavahareyash/cashflow](https://github.com/vyavahareyash/cashflow).
