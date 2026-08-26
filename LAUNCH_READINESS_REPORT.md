# ARVION — Play Store Launch Readiness Report

**Status: Phase 17 Complete**

## 1. Compliance & Legal
- [x] **Privacy Policy**: Created `PRIVACY_POLICY.md`. (Action Required: Host this at `https://arvion.tech/privacy` or a GitHub Pages URL and link in Play Console).
- [x] **Data Safety**: App is 100% offline-first. No data leaves the device except for user-initiated Google Drive backups.
- [x] **Permissions**: Minimal permissions declared. Bluetooth and Camera usage is justified for printing and scanning.

## 2. Technical Stability
- [x] **Crash Reporting**: Sentry integrated. Toggle added in Settings (User-controlled).
- [x] **Target API**: `compileSdk` is 36. `targetSdk` is managed by Flutter (Ensure `flutter build` uses latest stable).
- [x] **App Size**: Proguard (minification) enabled in release build.
- [x] **Architecture**: Offline-first with optional cloud sync.

## 3. Store Assets (Checklist for User)
- [ ] **Feature Graphic**: 1024 x 500 px.
- [ ] **App Icon**: 512 x 512 px (Already generated via Developer tool in Settings).
- [ ] **Screenshots**:
    - Dashboard with Charts
    - New Sale / Cart Screen
    - Inventory Management
    - Profit & Loss Report
- [ ] **Short Description** (80 chars): Smart Business. Simple Control. Offline POS & Accounting for Retailers.
- [ ] **Full Description**: (Refer to README.md for key features list).

## 4. Release Strategy
1. **Internal Test**: Deploy to 5 internal devices.
2. **Closed Alpha**: Invite 20 early adopters (Shopkeepers).
3. **Production Rollout**: 
    - 10% (Monitor for 2 days)
    - 50% (Monitor for 3 days)
    - 100% Full Launch.

## 5. App Signing Instructions
Run the following command to generate your upload key:
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `android/key.properties` with:
```properties
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=YOUR_PATH_TO_JKS
```
*Note: `key.properties` is already in `.gitignore`.*

**READY FOR: `flutter build appbundle --release`**
