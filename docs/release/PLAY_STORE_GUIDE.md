# Google Play Store Publishing & CD Automation Guide

Comprehensive manual guide for publishing **Cashflow** (`com.vyavahareyash.cashflow`) to Google Play Store and activating automated GitHub Actions deployment.

---

## Architecture & Workflow Summary

```
[Local / Git Push Tag (v*)] 
          │
          ▼
[GitHub Actions (release.yml)]
          │
          ├──> 1. Run Unit Tests (`flutter test -j 1`)
          ├──> 2. Decode Keystore & Build Release AAB (`flutter build appbundle --release`)
          ├──> 3. Attach Artifacts to GitHub Release
          └──> 4. Deploy AAB to Play Console via `r0adkll/upload-google-play` (Internal Track)
```

---

## Step 1: Generate Release Signing Keystore (One-Time Local Setup)

Android App Bundles published to Google Play must be signed with an upload key.

1. Run the following command in terminal to create `upload-keystore.jks`:
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks \
     -keyalg RSA -keysize 2048 -validity 10000 \
     -alias upload
   ```
   *Remember the password and alias (`upload`) you set.*

2. Base64-encode the keystore for GitHub Actions secret storage:
   ```bash
   # On macOS:
   base64 -i ~/upload-keystore.jks | tr -d '\n' | pbcopy
   echo "Keystore base64 copied to clipboard!"
   ```

3. (Optional) For testing signed builds locally, create `android/key.properties` (**never commit this file**):
   ```properties
   storePassword=<your-keystore-password>
   keyPassword=<your-key-password>
   keyAlias=upload
   storeFile=/path/to/upload-keystore.jks
   ```

---

## Step 2: Google Play Console — Create Application

1. Open [Google Play Console](https://play.google.com/console).
2. Click **Create app**:
   - **App name**: `Cashflow`
   - **Default language**: English (United States) or preferred default
   - **App or game**: App
   - **Free or paid**: Free
   - Accept the Developer Program Policies and US export laws checkboxes.
3. Click **Create app**.

---

## Step 3: Complete Mandatory App Content Policy Declarations

In the left navigation sidebar, scroll down to **Policy and programs** > **App content**. You must complete each required questionnaire:

1. **Privacy Policy**:
   - URL: `https://raw.githubusercontent.com/vyavahareyash/cashflow/main/PRIVACY_POLICY.md` (or your personal website / GitHub Pages URL).
2. **App Access**:
   - Select **All functionality is available without special access** (Cashflow has no login barrier).
3. **Ads**:
   - Select **No, my app does not contain ads**.
4. **Content Rating (IARC)**:
   - Category: **Consumer / Utility / Productivity**.
   - Questionnaire: Answer **No** to violence, profanity, gambling, user-to-user communications, location sharing, digital purchases.
   - Result: Rated for **Everyone / 3+**.
5. **Target Audience**:
   - Select age groups: **18 and older** (simplifies review, no family policy complications).
6. **Financial Features Declaration**:
   - Select **Personal finance management** or **Budgeting / Expense tracker**.
   - Declare that the app is an offline ledger tool and does not provide banking, loans, or payment facilitation services.
7. **Data Safety**:
   - Does your app collect or share any user data? -> Select **No**.
   - Google Play will badge your store listing as **No data collected** and **No data shared with third parties**.
8. **Government Apps**:
   - Select **No**.

---

## Step 4: Set Up Store Listing Assets

Navigate to **Grow** > **Store presence** > **Main store listing**:

1. **Short description** (up to 80 characters):
   `Privacy-first, offline personal finance, budget, and sinking fund tracker.`
2. **Full description**:
   Highlight Cashflow's core offline strengths:
   - 100% offline-first architecture with zero cloud telemetry.
   - Envelope budgeting & sinking funds tracking.
   - Usable Balance and Safe-to-Spend calculations.
   - Local JSON ledger backup and restore.
3. **Graphics**:
   - **App icon**: 512x512 px PNG (transparent or solid, 32-bit color, max 1MB).
   - **Feature graphic**: 1024x500 px JPG or PNG.
   - **Phone screenshots**: Upload at least 2 screenshots from the repo's `screenshots/` directory (e.g. `01-dashboard-light.png`, `05-budget-light.png`, `08-goals-light.png`, `12-accounts-light.png`, `16-analytics-trends-light.png`).

---

## Step 5: Configure Google Cloud Service Account (For Automated GitHub Releases)

Google Play Console requires API access via a Google Cloud Service Account to enable automated publishing from GitHub Actions.

1. Open [Google Cloud Console](https://console.cloud.google.com/).
2. Select or create the Google Cloud project linked to your Google Play Console account.
3. Enable the **Google Play Android Developer API**:
   - Go to **APIs & Services** > **Library**.
   - Search for `Google Play Android Developer API` and click **Enable**.
4. Create a Service Account:
   - Go to **APIs & Services** > **Credentials** > **Create Credentials** > **Service Account**.
   - Name: `github-actions-play-deploy`
   - Grant role: `Service Account User` (or leave blank).
   - Click **Done**.
5. Create and download JSON key:
   - Click on the created service account email.
   - Go to the **Keys** tab > **Add Key** > **Create new key** > **JSON**.
   - Download the `.json` file to a secure place.
6. Grant Permissions in Google Play Console:
   - In Google Play Console, go to **API access** (under Developer account settings) or **Users and permissions**.
   - Click **Invite new users**.
   - Enter the service account email address.
   - Under **App permissions**, select `Cashflow`.
   - Under **Permissions**, grant:
     - *View app information and download bulk reports (read-only)*
     - *Create, edit, and delete draft releases*
     - *Release to testing tracks* (Internal, Closed, Open)
     - *Manage testing tracks and edit tester lists*
   - Click **Invite user** and accept permissions.

---

## Step 6: Configure GitHub Repository Secrets

Go to your repository on GitHub:
`https://github.com/vyavahareyash/cashflow/settings/secrets/actions`

Add the following Repository Secrets:

| Secret Name | Description / Value |
|-------------|---------------------|
| `PLAY_KEYSTORE_BASE64` | Base64-encoded content of `upload-keystore.jks` (from Step 1) |
| `PLAY_KEYSTORE_PASSWORD` | Password of your upload keystore |
| `PLAY_KEY_ALIAS` | Key alias (e.g., `upload`) |
| `PLAY_KEY_PASSWORD` | Password for the key alias |
| `PLAY_SERVICE_ACCOUNT_JSON` | Entire plaintext content of the Google Cloud Service Account JSON file (from Step 5) |

---

## Step 7: Perform the Mandatory First Manual Upload

> [!IMPORTANT]
> Google Play Developer API will reject automated uploads for an application until **at least one** release artifact has been uploaded manually via the web console.

1. Build a signed release App Bundle locally:
   - Ensure `android/key.properties` exists locally or supply variables:
     ```bash
     flutter clean
     flutter pub get
     flutter build appbundle --release
     ```
   - Generated bundle: `build/app/outputs/bundle/release/app-release.aab`

   > [!TIP]
   > If building locally on macOS and Flutter reports `Failed to find cmdline-tools`:
   > Open **Android Studio** > **Settings / Preferences** > **Languages & Frameworks** (or **System Settings**) > **Android SDK** > **SDK Tools** tab, check **Android SDK Command-line Tools (latest)**, and click **Apply**.
   > In GitHub Actions CI, this tool is already pre-installed.

2. In Google Play Console:
   - Navigate to **Testing** > **Internal testing**.
   - Click **Create new release**.
   - Upload `app-release.aab`.
   - Google Play App Signing: Click **Use Google-generated key** (Play App Signing).
   - Review release details, enter release name (e.g. `3.1.1`), and click **Save** > **Review release** > **Start rollout to Internal testing**.

---

## Step 8: Trigger Automated Releases

From this point forward, every new release is automated!

1. Update version in `pubspec.yaml`:
   ```yaml
   version: 3.1.2+10
   ```
   *(Ensure the integer build number after `+` increases with each release).*

2. Commit, tag, and push:
   ```bash
   git commit -am "chore: bump version to 3.1.2+10"
   git tag v3.1.2
   git push origin main --tags
   ```

3. What happens next:
   - GitHub Actions executes `.github/workflows/release.yml`.
   - The `build-android` job decodes the keystore, writes `android/key.properties`, and builds `cashflow-release.aab`.
   - The `publish-release` job publishes the GitHub release with APKs and AAB attached.
   - The `publish-play-store` job uploads `cashflow-release.aab` directly to Google Play Console's **Internal testing** track via Google Play Developer API.
   - Open Play Console to verify the build, test it on your devices, and promote to **Production** with one click.
