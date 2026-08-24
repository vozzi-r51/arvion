# DukanEdge — Setup Guide (Phase 1-8)

DukanEdge ek 100% offline Flutter ERP app hai household/kitchenware/gift/plastic items wholesale & retail shops ke liye.

## Setup Steps (Android Studio)

1. **Naya Flutter project banayein**:
   ```
   flutter create dukanedge
   ```

2. Naye bane `dukanedge` folder ke andar:
   - `pubspec.yaml` ko is zip wale `pubspec.yaml` se **replace** kar dein.
   - `lib` folder ko poora delete karein aur is zip wale `lib` folder se replace kar dein.

3. **Android permissions add karein** — `android/app/src/main/AndroidManifest.xml` mein, `<manifest>` tag ke andar (application tag se upar):
   ```xml
   <uses-permission android:name="android.permission.USE_BIOMETRIC" />
   <uses-permission android:name="android.permission.USE_FINGERPRINT" />
   ```

4. **minSdkVersion set karein** — `android/app/build.gradle` (ya `build.gradle.kts`) mein `minSdk` kam se kam **23**:
   ```
   minSdk = 23
   ```

5. **MainActivity ko FlutterFragmentActivity banayein** (local_auth ki requirement) — `android/app/src/main/kotlin/.../MainActivity.kt`:
   ```kotlin
   import io.flutter.embedding.android.FlutterFragmentActivity

   class MainActivity: FlutterFragmentActivity()
   ```

6. Terminal mein project folder ke andar:
   ```
   flutter pub get
   flutter run
   ```

## App Ka Structure (Bottom Navigation)

- **Dashboard** — Quick Actions + 8 live overview cards (Sales, Purchase, Profit, Expenses, Customers, Suppliers, Products, Low Stock)
- **Products** — Products | Categories | Brands
- **Customers** — Customers | Suppliers (dono mein Ledger button hai)
- **Sales** — Sales history + New Sale (POS)
- **Purchases** — Purchase history + New Purchase
- **More** — Expenses & Income, Cash Book, Bank Book (aur aane wale modules ka preview)

## Phase-by-Phase Summary

**Phase 1**: Project setup, multi-company SQLite DB, PIN + Fingerprint login.

**Phase 2**: Company Profile (logo/stamp/signature/invoice footer), Settings (theme, fingerprint toggle, company switch), Dashboard shell.

**Phase 3**: Product/Category/Brand management. Dashboard "Total Products" & "Low Stock Alert" live.

**Phase 4**: Customer/Supplier management. Dashboard "Total Customers" & "Total Suppliers" live.

**Phase 5**: Sales/POS — cart, stock deduction, customer balance update on due sales. Dashboard "Today's Sales" & "Today's Profit" live.

**Phase 6**: Purchase — cart, stock increase, purchase price refresh, supplier balance update on due purchases. Dashboard "Today's Purchase" live.

**Phase 7**: Expenses & Income (in the new "More" tab). Dashboard "Today's Expenses" live — ab dashboard ke saare 8 cards live hain.

**Phase 8 (latest)**: 
- **Customer Ledger**: har customer ki sales (due) + payments received ki combined statement, "Payment Record Karein" se due wasool karein — balance automatically kam hota hai.
- **Supplier Ledger**: har supplier ki purchases (due) + payments made ki statement, payment record karne se balance kam hota hai.
- **Cash Book** (More tab): manual Cash In / Cash Out entries, totals ke sath.
- **Bank Book** (More tab): multiple bank accounts, har account ka deposit/withdrawal ledger with running balance.

## Test Karne Ka Tareeqa (Phase 8)

1. **Customers** tab → kisi customer ki row par tap karein (ya receipt icon) → Ledger khulega. Agar us customer ki koi Due sale hai to wo dikhegi. "Payment Record Karein" se payment darj karein — balance kam hoga.
2. **Suppliers** tab mein bhi yehi tareeqa — Due purchase dikhegi, payment record karne se balance kam hoga.
3. **More → Cash Book**: "+" se Cash In aur Cash Out entries banayein, totals check karein.
4. **More → Bank Book**: "+" se ek bank account banayein, us par tap karke deposit/withdrawal karein, balance update hote dekhein.

## Agla Phase

Baaki sirf poora Urdu/RTL UI reh gaya hai (bada, separate undertaking). Baki sab ban chuka hai.

---

# Big Gap-Fill — Journal, Excel Export, Soft-Delete, Auto-Backup

- **More → Journal & Accounts**: manual double-entry Journal — entry banayein (multiple debit/credit lines, harf Journal automatically balance check karta hai), **Trial Balance** (sab accounts ka debit/credit total), **Balance Sheet** (Assets/Liabilities/Equity, is period ka Net Income included). Default chart of accounts (Cash, Bank, Accounts Receivable, Inventory, Accounts Payable, Owner's Equity, Sales Revenue, COGS, Expenses) khud ban jata hai jab pehli baar kholte hain.
  **Important**: Ye manual double-entry system hai — Sales/Purchase/Expense jaise modules khud is mein post nahi hotay, sirf jo Journal entry aap khud banayein wahi is mein aati hai.
- **Excel Export**: Reports (Sales, Purchase, Expense, Stock, Customer, Supplier) mein ab share icon hai — **CSV file** banti hai jo Excel/Google Sheets mein seedha khulti hai.
- **Soft-Delete/Restore**: Products, Customers, Suppliers, Employees delete karne par ab **turant permanent delete nahi hote** — **More → Recycle Bin** mein jaake Restore ya Hamesha Ke Liye Delete kar sakte hain.
- **Automatic Backup**: Settings mein "Auto-Backup" toggle — har 7 din mein app khulte waqt khud-ba-khud ek backup local storage mein ban jata hai (share nahi hota, bas safety ke liye save hota hai; purane 5 se zyada backups khud delete ho jate hain). Last backup date bhi Settings mein dikhti hai.

## Test Karne Ka Tareeqa

1. **More → Journal & Accounts** → New Entry banayein (jaise: Cash debit 5000, Sales Revenue credit 5000) → save karein → Trial Balance aur Balance Sheet check karein.
2. Kisi Report (jaise Sales Report) mein share icon tap karein — CSV file share/save honi chahiye.
3. Koi product delete karein → **More → Recycle Bin** mein jaake Restore karein — product wapis list mein aana chahiye.
4. Settings mein Auto-Backup toggle check karein.

---

# Gap-Fill — Module Audit ke Baad

Original spec check karne par 3 cheezein missing mili, wo ab add ho gayi hain:
- **More → Inventory Adjustment**: Increase/Decrease/Damage/Lost stock, history ke sath.
- **Product Expiry Date**: ab product form mein field hai (optional).
- **Credit Limit Check**: Due sale karte waqt agar customer ki credit limit cross ho rahi ho to warning dikhti hai (continue ya cancel kar sakte hain).

Baaki cheezein jo abhi tak nahi bani (jaan-bujh kar chhodi gayi hain kyunke ye bade, separate undertakings hain):
- Urdu/RTL poora UI (sirf name fields Urdu mein hain)
- Balance Sheet, Trial Balance, Journal (proper double-entry accounting)
- Excel export (PDF invoice hai, Excel reports nahi)
- Soft-delete/Restore records (abhi delete permanent hai)
- Automatic scheduled backup (abhi sirf manual backup hai)

---

# Phase 16 — Audit Log

Naya kya ban chuka hai:
- **More → Audit Log**: Module aur Action ke filters ke sath, saari logged activity ki list — kis waqt kya hua.
- Ye modules ab activity log karte hain: **Login** (jab app khulti hai / company open hoti hai), **Product** (add/edit/delete), **Customer** (add/edit/delete), **Supplier** (add/edit/delete), **Sale** (create/delete + stock change note), **Purchase** (create/delete + stock change note), **Expense** (add/edit/delete), **Income** (add/edit/delete).

**Scope ki honesty**: Audit log app ke sabse zyada istemal hone wale modules (Products, Customers, Suppliers, Sales, Purchases, Expenses, Income, Login) cover karta hai. Baaki chote modules (jaise HR, Committee, Cheque, Returns, Challan, PO, Ledger payments) abhi log nahi hote — agar wo bhi chahiye to bata dein, wahi pattern har jagah repeat kar sakte hain.

## Test Karne Ka Tareeqa (Phase 16)

1. Koi product add/edit/delete karein, ek customer banayein, ek sale karein.
2. **More → Audit Log** kholein — sab entries dikhni chahiye, sab se naya sabse upar.
3. Module filter se sirf "Product" select karke check karein sirf product wali entries dikh rahi hain.
4. Action filter se "delete" select karke check karein.

---

# Phase 15 — Delivery Challan + Purchase Order

Naya kya ban chuka hai:
- **More → Delivery Challan**: koi bhi sale select karein → uske items khud load ho jate hain → delivery address/notes likhein → customer se **hath se signature** lein (draw karke, koi extra app/scanner nahi chahiye) → save karein. List mein Pending/Delivered status dikhta hai, tap karke "Delivered Mark Karein" bhi kar sakte hain.
- **More → Purchase Order**: supplier select karein, product cart banayein (jaisa New Purchase mein hota hai), PO save hota hai as **Draft**. PO detail mein status **Draft → Approved → Received** badha sakte hain, ya **Cancel** kar sakte hain.
- Note: PO sirf ek planning/tracking document hai — jab maal actually aa jaye, to use normal **Purchases** tab se record karna hoga taake stock aur supplier balance sahi update ho (PO khud stock nahi badalta).

## Test Karne Ka Tareeqa (Phase 15)

1. **More → Delivery Challan** → "New Challan" → koi sale select karein → address likhein → box mein ungli/mouse se signature draw karein → save karein.
2. List mein wo challan "Delivered" status ke sath dikhna chahiye (agar signature li thi), aur detail kholne par signature image dikhni chahiye.
3. **More → Purchase Order** → "New PO" → supplier aur products select karke save karein (Draft status mein banega).
4. PO detail kholein → "Mark as Approved" phir "Mark as Received" try karein.

---

# Phase 14 — Returns Management

Naya kya ban chuka hai:
- **More → Returns**: Sales Returns aur Purchase Returns do tabs, history + "New Return" FAB.
- **Sales Return**: koi bhi purani sale select karein (ya Sale Detail screen se seedha "Return Items" button), items checklist mein select karein, quantity adjust karein. Refund method: **Cash** (sirf record hota hai) ya **Adjust Due** (customer ka balance kam ho jata hai). Return save hone par **stock wapis barh jata hai**.
- **Purchase Return**: purani purchase select karein (ya Purchase Detail se "Return Items"), items select karein — return hone par **stock kam ho jata hai** aur **supplier ka balance kam ho jata hai** (jo dena hai wo kam hua).
- Sale Detail aur Purchase Detail screens mein ab "Return Items" button bhi hai — seedha usi transaction ke liye return shuru kar sakte hain.

## Test Karne Ka Tareeqa (Phase 14)

1. Kisi purani Sale ka detail kholein → "Return Items" tap karein → 1 item select karke thori quantity return karein → "Cash Refund" ya "Adjust Due" choose karein → save karein.
2. Products tab mein check karein us product ka stock wapis barh gaya.
3. Agar customer wala sale tha aur "Adjust Due" choose kiya tha, to Customers tab mein uska balance kam hona chahiye.
4. Wahi tareeqa Purchase ke sath try karein — stock kam hoga, supplier balance kam hoga.
5. **More → Returns** mein dono list check karein.

---

# Phase 13 — Backup / Restore

Naya kya ban chuka hai:
- **Settings → Data section**:
  - **Backup Banayein**: pura data (SQLite database) + saari images (logo, stamp, signature, product photos) ek `.zip` file mein bandh kar system ka **share sheet** khulta hai — jahan chahein save karein (Google Drive, WhatsApp, Files app, email, wagera).
  - **Backup Restore Karein**: pehle se saved `.zip` file select karein — confirm karne par mojooda data **overwrite** ho jata hai (isliye ek warning dialog aata hai). Restore ke baad app band karke dobara kholni hoti hai taake sab kuch sahi load ho.

## Extra Setup for Phase 13

Koi naya Android permission nahi chahiye — bas:
```
flutter pub get
```
chalayein (naye packages: `archive`, `share_plus`, `file_picker`).

## Test Karne Ka Tareeqa (Phase 13)

1. **Settings → Backup Banayein** — share sheet khulne par "Save to Files" (ya koi bhi app) choose karke zip file save kar lein.
2. Kuch naya data add karein (jaise ek product) taake farq pata chale.
3. **Settings → Backup Restore Karein** — wahi zip file select karein, confirm karein.
4. Dialog mein "App Band Karein" par tap karein, phir app dobara kholein — purana data (jo backup mein tha) wapis aana chahiye, aur baad mein add kiya gaya product ab nahi hona chahiye.

---

# Phase 12 — Committee (BC System) + Cheque Management

Naya kya ban chuka hai:
- **More → Committee (BC System)**: committee banayein (naam, monthly installment, total members, start date). Har committee ke 3 tabs:
  - **Members**: members add/remove karein.
  - **Installments**: har member ki monthly installment record karein.
  - **Draws**: jab kisi member ki bari aaye to draw record karein — wo member "already drawn" mark ho jata hai aur dubara list mein nahi aata.
  - Top par **Collected / Drawn / Balance** summary dikhta hai (refresh icon se update karein).
- **More → Cheque Management**: **Received** aur **Issued** do tabs. Cheque add karein (party, bank, number, amount, date). Status **Pending/Cleared/Bounced** — chip par tap karke change karein. Delete ke liye cheque par **long-press** karein.

## Test Karne Ka Tareeqa (Phase 12)

1. **More → Committee** → "+" se ek committee banayein (jaise: 10 members, Rs. 5000/month).
2. **Members** tab mein 2-3 members add karein.
3. **Installments** tab mein kisi member ki is mahine ki installment record karein.
4. **Draws** tab mein kisi member ka draw record karein — Members tab mein check karein wo "Draw Ho Gaya" dikhna chahiye.
5. Top ka Collected/Drawn/Balance summary refresh icon se check karein.
6. **More → Cheque Management** → Received tab mein ek cheque add karein, uska status chip par tap karke "Cleared" karein. Issued tab mein bhi try karein.

---

# Phase 11 — Employees / HR

Naya kya ban chuka hai:
- **More → Employees / HR**: employee list, add/edit, search.
- Har employee ka tap karne par 4 tabs khulte hain:
  - **Attendance**: aaj ki attendance mark karein (Present/Absent/Leave/Half Day), past records dekhein.
  - **Salary**: monthly salary dikhti hai, "Salary Pay Karein" se month-wise payment record karein, history dekhein.
  - **Advance**: "Advance Dein" se advance salary dein, "Recover" se pending advance wapis lein — pending balance khud track hota hai.
  - **Commission**: manually commission entries add karein (sales commission tracking).

## Test Karne Ka Tareeqa (Phase 11)

1. **More → Employees / HR** → "+" se naya employee banayein (naam, designation, monthly salary).
2. Employee par tap karke **Attendance** tab mein "Present" mark karein — dubara tap karke status change bhi ho sakta hai.
3. **Salary** tab mein "Salary Pay Karein" se is mahine ki salary record karein.
4. **Advance** tab mein ek advance dein, phir "Recover" se partial ya poora recover karein — status "Cleared" ho jana chahiye jab poora recover ho jaye.
5. **Commission** tab mein ek commission entry add karein.

---

# Phase 10 — Barcode/QR Support + Invoice Designer

Naya kya ban chuka hai:
- **Barcode Scan**: Product form ke Barcode field mein scan icon — camera se scan karke seedha barcode fill hota hai.
- **Scan to Search**: Products list, New Sale aur New Purchase ke product picker — sab mein scan icon hai jo barcode scan karke product dhoondta hai.
- **Barcode/QR Display**: Products list mein har product ke saath ek icon — uska Code128 barcode aur QR code (label printing/screenshot ke liye) dikhata hai.
- **Invoice Designer (PDF)**: Sale Detail screen mein "Print / Share Invoice" button — **A4** (full page, logo/stamp/signature/footer ke sath) ya **Thermal (80mm)** receipt format choose kar sakte hain. PDF mein invoice number ka QR code bhi hota hai. "Print" dialog se PDF ko print, save, ya share kar sakte hain (system ka print/share sheet khulta hai).

## Extra Setup for Phase 10 (Zaroori)

1. **Camera permission** — `android/app/src/main/AndroidManifest.xml` mein (agar Phase 1 wali biometric permissions already add ki hain, unke sath):
   ```xml
   <uses-permission android:name="android.permission.CAMERA" />
   ```

2. `flutter pub get` chalayein (naye packages: `barcode_widget`, `mobile_scanner`, `pdf`, `printing`).

3. `minSdk` already 23 hai (Phase 1 se) — mobile_scanner ke liye kaafi hai, koi change nahi chahiye.

## Test Karne Ka Tareeqa (Phase 10)

1. Kisi product ko edit karein → Barcode field ke scan icon par tap karein → koi bhi barcode/QR camera ke samne rakhein → field automatically fill honi chahiye.
2. Products list mein us product ke QR icon par tap karein → uska barcode aur QR code dikhna chahiye.
3. New Sale kholein → "Product Add Karein" → scan icon se product dhoondein.
4. Koi bhi Sale ka detail kholein → "Print / Share Invoice" → **A4** choose karein → system ka print/share dialog khulna chahiye, PDF preview dikhni chahiye.
5. Wahi sale se **Thermal (80mm)** try karein — receipt-style layout dikhna chahiye.

---

# Phase 9 — Reports Module

Naya kya ban chuka hai:
- **More → Reports**: 7 report types, sab grid mein.
- **Sales Report**: date range, sales list, total sales + total due + invoice count.
- **Purchase Report**: date range, purchase list, total purchase + total due.
- **Profit & Loss**: Revenue, Gross Profit, Other Income, Expenses, aur final Net Profit/Loss card.
- **Expense Report**: category-wise breakdown with percentage of total.
- **Stock Report**: har product ka stock + valuation (purchase price x stock), low-stock items highlight.
- **Customer Report**: Accounts Receivable — kis customer se kitna lena hai, highest pehle.
- **Supplier Report**: Accounts Payable — kis supplier ko kitna dena hai, highest pehle.

Note: Is phase mein PDF/Excel export shamil nahi hai — reports sirf app ke andar (date-range filter ke sath) dikhte hain. Export feature ek alag phase mein add karenge taake naya package (pdf/excel generation) dependency carefully test ho.

## Test Karne Ka Tareeqa (Phase 9)

1. **More → Reports** kholein.
2. **Sales Report** aur **Purchase Report** mein date range change karke dekhein numbers update hote hain.
3. **Profit & Loss** kholein — Net Profit/Loss card check karein.
4. **Stock Report** mein low-stock products red mein highlight ho rahe hain, check karein.
5. **Customer Report** aur **Supplier Report** mein wahi balances dikhne chahiye jo Ledger screens mein the.
