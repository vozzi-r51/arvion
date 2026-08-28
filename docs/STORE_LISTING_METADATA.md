# BizManager — Google Play Store Listing & Staged Rollout Strategy

## 1. Store Listing Metadata

- **App Name**: `BizManager — ERP, POS & Accounting`
- **Short Description** (80 chars max):
  `Offline-first ERP, POS, Accounting, Inventory & FBR Invoicing for Businesses.`
- **Full Description**:
  ```text
  BizManager is a professional, offline-first ERP, Point of Sale (POS), Inventory, and Accounting solution built for Pakistani SMEs, Retailers, Wholesalers, Restaurants, and Manufacturing businesses.

  KEY FEATURES:
  • Offline-First Reliability: Full offline POS checkout, inventory, and accounting with local AES-256 database encryption.
  • FBR Digital Invoicing Ready: 18-Digit FBR POS Invoice Number generation and thermal receipt QR code verification.
  • Mobile Wallet Payments: JazzCash, EasyPaisa, and Raast instant payment deep-links with TRX ID tracking.
  • Double-Entry Accounting: General Ledger, Trial Balance, P&L, Balance Sheet, Cost Centers, and Fiscal Year-End Closing.
  • Industry Vertical Modules: Restaurant Table Management & KOT, Clothing Size-Color Variant Grid, Pharmacy Batch/Expiry, Hardware Multi-UOM, and Service Jobs.
  • Multi-Level Manufacturing: Recursive BOM sub-assemblies, Work Center Routing, and Wastage/Scrap tracking.
  • Universal Data Importer: One-click import from QuickBooks, Tally, Vyapar, and Excel.
  ```
- **Category**: `Business` / `Finance`
- **Content Rating**: `3+ (Everyone)`
- **Privacy Policy URL**: `https://arvion.tech/privacy-policy`

---

## 2. Graphic Asset Specifications

| Asset Type | Dimension | Format | Notes |
| :--- | :--- | :--- | :--- |
| **App Icon** | $512 \times 512$ px | PNG (32-bit) | Hi-res BizManager logo on brand background |
| **Feature Graphic** | $1024 \times 500$ px | PNG / JPG | Vibrant brand graphic with tagline |
| **Phone Screenshots** | $1080 \times 1920$ px | PNG | Min 4 screenshots (POS, Inventory, Ledger, Manufacturing) |

---

## 3. Data Safety Declarations

- **Data Collected**: Anonymized crash logs and diagnostics (Only if user opts in via Settings).
- **Data Shared**: **None**. Zero third-party data sharing.
- **Data Security**: Data encrypted at rest (Android KeyStore AES-256) and in transit (TLS/HTTPS).
- **Data Deletion**: Users can purge or reset local business databases at any time inside app Settings.

---

## 4. Staged Rollout Plan

```
[Internal Testing] ──> [Closed Beta (50 Merchants)] ──> [5% Production] ──> [20%] ──> [50%] ──> [100% Full Release]
```

1. **Internal Testing**: Verification of release build, R8 proguard minification, and release APK/AAB signing.
2. **Closed Beta (50 Merchants)**: Field testing across real retail and workshop environments.
3. **Staged Production Rollout**:
   - Day 1-2: 5% Rollout
   - Day 3-4: 20% Rollout
   - Day 5-6: 50% Rollout
   - Day 7: 100% Full Production Release
4. **Quality Gate**: Crash-free session rate must exceed **99.5%** before progressing to the next staged percentage.
