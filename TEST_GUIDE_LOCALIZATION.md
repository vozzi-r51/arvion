# Testing Guide: Multi-Currency & Localization

## Test Setup

### Create Test Companies

#### Company 1: Pakistan (PKR)
- **Name:** Pakistan Test Co
- **Currency Code:** PKR
- **Currency Symbol:** Rs.
- **Decimal Places:** 0
- **Thousand Separator:** ,
- **Decimal Separator:** .
- **Date Format:** DD/MM/YYYY
- **Locale Language:** ur (Urdu)

**Expected Behavior:**
- Amounts display: "45,000" (no decimals)
- Dashboard: "آج کی کل فروخت: 45,000" (Urdu text)
- Dates: "27/08/2026"

---

#### Company 2: USA (USD)
- **Name:** USA Test Co
- **Currency Code:** USD
- **Currency Symbol:** $
- **Decimal Places:** 2
- **Thousand Separator:** ,
- **Decimal Separator:** .
- **Date Format:** MM/DD/YYYY
- **Locale Language:** en (English)

**Expected Behavior:**
- Amounts display: "$1,234.56" (2 decimals)
- Dashboard: "Today's Sales: $1,234.56" (English text)
- Dates: "08/27/2026"

---

#### Company 3: UAE (AED)
- **Name:** UAE Test Co
- **Currency Code:** AED
- **Currency Symbol:** د.إ
- **Decimal Places:** 2
- **Thousand Separator:** ,
- **Decimal Separator:** .
- **Date Format:** YYYY-MM-DD
- **Locale Language:** ar (Arabic)

**Expected Behavior:**
- Amounts display: "د.إ 1,234.56" (Arabic format)
- Dashboard: "مبيعات اليوم: د.إ 1,234.56" (Arabic text)
- Dates: "2026-08-27"

---

## Test Scenarios

### Test 1: Currency Formatting
**Steps:**
1. Create sale with amount: 45678.50
2. Switch to PKR company → Should display: "45,679" (rounded, no decimals)
3. Switch to USD company → Should display: "$45,678.50" (2 decimals)
4. Switch to AED company → Should display: "د.إ 45,678.50" (Arabic symbol)

**Pass Criteria:** ✓ All amounts display with correct currency symbol and decimals

---

### Test 2: Date Format
**Steps:**
1. Create transaction dated 2026-08-27
2. View in PKR company → Shows "27/08/2026"
3. View in USD company → Shows "08/27/2026"
4. View in AED company → Shows "2026-08-27"

**Pass Criteria:** ✓ Dates format according to company preference

---

### Test 3: Language Switching
**Steps:**
1. Open Settings
2. Click "App Language" dropdown
3. Select "English" → UI changes to English
4. Select "اردو" → UI changes to Urdu
5. Select "العربية" → UI changes to Arabic

**Pass Criteria:** ✓ UI strings change language (if already migrated)

---

### Test 4: Dashboard Display
**Steps:**
1. Switch to PKR company
2. Create sale: 10000
3. Dashboard shows: "Today's Sales: 10,000" (Urdu text)
4. Switch to USD company
5. Dashboard shows: "Today's Sales: $10,000.00" (English text)

**Pass Criteria:** ✓ Dashboard amounts and labels match company settings

---

### Test 5: Reports Display
**Steps:**
1. Generate Sales Report for PKR company
2. All amounts show: "45,000" format
3. Switch to USD company
4. Same report amounts show: "$45,000.00" format

**Pass Criteria:** ✓ Reports respect company currency settings

---

### Test 6: Ledger Display
**Steps:**
1. View Customer Ledger for PKR company
2. Balance column shows: "5,000" (no decimals)
3. Switch to USD company
4. Balance column shows: "$5,000.00" (2 decimals)

**Pass Criteria:** ✓ Ledger amounts format correctly

---

### Test 7: PDF Invoices
**Steps:**
1. Create sale for PKR company
2. Generate PDF invoice
3. Invoice shows amounts in Rs. format: "45,000"
4. Create sale for USD company
5. Generate PDF invoice
6. Invoice shows amounts in $ format: "$45,000.00"

**Pass Criteria:** ✓ PDF invoices use correct currency

---

### Test 8: AI Engine Responses
**Steps:**
1. Use AI voice: "Today's sales?"
2. PKR company responds: "Aaj ki total sales 45,000 hain." (Urdu, no decimals)
3. USD company responds: "Today's total sales are $45,000.00." (English, 2 decimals)

**Pass Criteria:** ✓ AI responses format amounts correctly

---

## Code Verification

Run these commands to verify completeness:

```bash
# 1. Check no hardcoded Rs. remain
grep -rn "'Rs\." lib/ 
# Expected: 0 results (or only in database defaults)

# 2. Check imports added
grep -n "LocalizationProvider" lib/app.dart
grep -n "LocalizationProvider" lib/features/dashboard/dashboard_screen.dart
# Expected: Both files have import

# 3. Check localization files exist
ls lib/l10n/app_*.arb
# Expected: app_en.arb, app_ur.arb, app_ar.arb

# 4. Build check
flutter clean && flutter pub get && flutter analyze
# Expected: No errors

# 5. Generate localizations
flutter gen-l10n
# Expected: No errors, generates lib/generated/l10n/
```

---

## Verification Checklist

- [ ] **Database:** Companies table has currency_code, decimal_places, locale_language columns
- [ ] **Utilities:** CurrencyFormatter, DateFormatter, LocalizationProvider created
- [ ] **App Wiring:** app.dart imports LocalizationProvider
- [ ] **Dashboard:** Uses formatCurrency() for amounts
- [ ] **Settings:** Language selector dropdown works
- [ ] **Test Company 1 (PKR):** Amounts show "45,000" (0 decimals)
- [ ] **Test Company 2 (USD):** Amounts show "$45,000.00" (2 decimals)
- [ ] **Test Company 3 (AED):** Amounts show "د.إ 45,000.00" (Arabic)
- [ ] **Date Formatting:** Dates format per company preference
- [ ] **Language Switching:** Settings language selector works
- [ ] **Reports:** Display correct currency for each company
- [ ] **Ledgers:** Display correct currency for each company
- [ ] **PDF Invoices:** Use correct currency formatting
- [ ] **AI Engine:** Responses include formatted amounts
- [ ] **grep -rn "'Rs\." lib/:** Returns ZERO results

---

## Deploy Readiness Criteria

App is deploy-ready when:

✅ All 8 test companies display correctly
✅ No hardcoded 'Rs.' references remain (grep returns 0)
✅ flutter analyze shows no errors
✅ Language selector works in Settings
✅ All reports and ledgers use dynamic formatting
✅ PDF invoices generate with correct currency
✅ App builds successfully for release

---

## Rollout Plan

**Phase 1:** Pakistan (PKR)
- Primary market, existing default
- Verify backward compatibility

**Phase 2:** USA/International (USD)
- Test multi-decimal formatting
- Verify date format switching

**Phase 3:** Gulf Markets (AED, Arabic)
- Test RTL support
- Verify Arabic locale

**Full Rollout:** When all 3 phases pass ✅

---

## Support & Debugging

**If amounts not formatting:**
1. Check company.currency_code in database
2. Verify LocalizationProvider.init() called in main()
3. Check CurrencyFormatter is imported in screens

**If language not changing:**
1. Check language selector in Settings
2. Verify LocalizationProvider.setLocale() called
3. Check SharedPreferences saving language choice

**If dates not formatting:**
1. Check company.date_format column
2. Verify DateFormatter.format() called with correct format param
3. Check parsed date strings are ISO format (YYYY-MM-DD)

---

## Success Indicators

🎉 **Deploy Ready When:**
- All test companies display amounts correctly
- Language selector visible and functional
- No hardcoded currency symbols in code
- App builds without warnings
- PDF invoices use correct formatting
- Reports adapt to each company's settings

**Timeline:** ~2-3 hours to run full test suite
