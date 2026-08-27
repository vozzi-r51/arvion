# Quick Start: Completing Localization Setup

## What's Done ✅

1. **Database:** Currency columns added (v37 migration)
2. **Utilities:** CurrencyFormatter, DateFormatter, LocalizationProvider created
3. **Translations:** English, Urdu, Arabic .arb files ready
4. **AI Engine:** All 7 business tools use dynamic currency formatting
5. **Documentation:** Full implementation guide created

**Current Build Status:** Ready to compile ✅

---

## Next Steps (In Order)

### Step 1: Generate Localization (5 min)
```bash
cd F:/files/dukanedge_final/dukanedge
flutter gen-l10n
```
This generates `lib/generated/l10n/app_localizations.dart` and locale variants.

### Step 2: Wire Provider into App (10 min)
**File:** `lib/app.dart`
```dart
import 'package:flutter_localizations/flutter_localizations.dart';
import 'lib/core/providers/localization_provider.dart';

// In MaterialApp:
localizationsDelegates: const [
  AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
],
supportedLocales: const [
  Locale('en'),
  Locale('ur'),
  Locale('ar'),
],
```

### Step 3: Initialize in main() (5 min)
**File:** `lib/main.dart`
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ... other init ...
  
  final locProvider = LocalizationProvider();
  await locProvider.init();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => locProvider,
      child: const DukanEdgeApp(),
    ),
  );
}
```

### Step 4: Update 3 Dashboard Display Values (20 min)
**File:** `lib/features/dashboard/dashboard_screen.dart`

Search for: `Text('Rs.`
Replace with: `Text(Provider.of<LocalizationProvider>(context).formatCurrency(...)`

Quick wins:
- Line 40: `String _currency = 'Rs.';` → remove (managed by provider now)
- Line 66: currency assignment → remove
- Line ~240-260: Dashboard metric displays → update 5-6 Text widgets

### Step 5: Test Build (5 min)
```bash
flutter pub get
flutter analyze  # Check for errors
flutter build apk --debug  # Quick test
```

### Step 6: Create Test Companies (10 min)
1. Company 1: PKR, 0 decimals, DD/MM/YYYY, Urdu
2. Company 2: USD, 2 decimals, MM/DD/YYYY, English
3. Switch between them → verify amounts display correctly

---

## Critical Files to Update (Priority Order)

If time is limited, do these 5 in order:

1. **Dashboard** (6 changes) - most visible
2. **Sales screens** (15 changes) - core business
3. **Ledger screens** (20 changes) - reporting
4. **Report screens** (25 changes) - analytics
5. **All others** (remaining)

Pattern for all:
```dart
// Replace
Text('Rs. ${value.toStringAsFixed(0)}')

// With
Text(Provider.of<LocalizationProvider>(context).formatCurrency(value))
```

---

## Verification (Final Checklist)

Before considering "deploy-ready":

```bash
# 1. No hardcoded currency symbols
grep -rn "'Rs\." lib/ → Should return 0 results

# 2. Build succeeds
flutter clean && flutter pub get && flutter build apk

# 3. Test functionality
- Switch companies → currency updates ✓
- Switch language → UI text updates ✓
- Display amounts → formatted correctly ✓
- PDF invoices → correct format ✓
```

---

## Time Estimate

- Phase 2 (Wire provider + update widgets): **3-4 hours**
- Phase 3 (String localization): **2-3 hours**
- Phase 4 (Date formatting): **1 hour**
- Phase 5 (Full testing): **2 hours**

**Total to full deploy-ready: ~8-10 hours**

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `lib/core/utils/currency_formatter.dart` | Format amounts with company settings |
| `lib/core/utils/date_formatter.dart` | Format dates with company settings |
| `lib/core/providers/localization_provider.dart` | Manage all locale settings |
| `lib/l10n/app_*.arb` | Translations (English, Urdu, Arabic) |
| `lib/app.dart` | Wire localization into MaterialApp |
| `lib/main.dart` | Initialize provider at startup |
| `LOCALIZATION_IMPLEMENTATION_GUIDE.md` | Full reference (this repo) |

---

## Common Patterns

### In StatefulWidget
```dart
final loc = Provider.of<LocalizationProvider>(context);
Text(loc.formatCurrency(amount))
```

### In Consumer
```dart
Consumer<LocalizationProvider>(
  builder: (_, loc, __) => Text(loc.formatCurrency(amount)),
)
```

### In String Interpolation
```dart
final loc = Provider.of<LocalizationProvider>(context);
String message = 'Total: ${loc.formatCurrency(total)}';
```

---

## Support

**If stuck:**
1. See `LOCALIZATION_IMPLEMENTATION_GUIDE.md` for full context
2. Memory file: `localization-currency-migration-progress.md`
3. Check AI engine (lib/features/ai/ai_engine.dart) for example usage

**Goal:** App works flawlessly in PKR, USD, AED with correct localization for Pakistan, USA, UAE.
