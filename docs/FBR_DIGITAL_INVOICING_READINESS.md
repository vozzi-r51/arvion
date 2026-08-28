# BizManager — FBR Digital Invoicing Readiness & Regulatory Compliance Specification

## 1. Legal & Regulatory Applicability
Under the Federal Board of Revenue (FBR) Sales Tax Act 1990, Sales Tax Rules 2006, and relevant Sales Tax Special Procedures / POS Integration Rules:

1. **Mandatory Categories**:
   - Tier-1 Retailers (large shopping malls, retail chains, air-conditioned outlets, bulk importers/wholesalers).
   - Notified Corporate and Non-Corporate Registered Entities.
   - Restaurants and Bakeries operating in notified urban jurisdictions.
   - E-commerce merchants operating Tier-1 online portals.

2. **Buyer Identification Rules**:
   - **Registered Buyers**: Require valid NTN (National Tax Number) / STRN.
   - **Unregistered Buyers**: For transactions exceeding specified regulatory thresholds (e.g., Rs. 100,000+), buyer CNIC/NTN must be recorded.

---

## 2. Integration Model
BizManager operates through FBR-licensed integrators / PRAL (Pakistan Revenue Automation Limited):

```
┌─────────────────┐       ┌──────────────────────┐       ┌────────────────────────┐
│   BizManager    │ ────> │  Licensed Integrator │ ────> │ FBR Digital Invoicing  │
│  (Offline-First)│ <──── │      (PRAL API)      │ <──── │    (Central Server)    │
└─────────────────┘       └──────────────────────┘       └────────────────────────┘
```

- BizManager completes local sales transactions atomically first.
- The FBR submission pipeline executes asynchronously or via post-commit worker.
- Credentials (POS ID, API Key, Token) are stored in platform secure storage (`SecureAppStorage` / Android Keystore).

---

## 3. Data Model Mapping

| BizManager Field | FBR Field Name | Required? | Type / Format | Transformation / Notes |
| :--- | :--- | :--- | :--- | :--- |
| `company.ntn_gst` | `PNTN` / `SellerNTN` | Yes | String (7-7) | Seller NTN Number |
| `company.pos_id` | `POSID` | Yes | Integer (6 digits) | Unique registered POS Outlet ID |
| `sale.id` | `USIN` | Yes | String | Unique System Invoice Number |
| `sale.fbr_invoice_number` | `FBRInvoiceNumber` | Yes (On Response) | String (18 digits) | FBR Fiscal Invoice Number |
| `sale.sale_date` | `DateTime` | Yes | YYYY-MM-DD HH:mm:ss | Transaction timestamp |
| `customer.cnic` | `BuyerCNIC` / `BuyerNTN` | Conditional | String (13 digits) | Required for sales > Rs. 100k |
| `sale_item.quantity` | `Quantity` | Yes | Decimal | Quantity sold |
| `sale_item.unit_price` | `PCTCode` / `UnitPrice` | Yes | Decimal | Unit selling price |
| `sale.tax_amount` | `SalesTaxAmount` | Yes | Decimal | Total sales tax charged |
| `sale.total_amount` | `TotalAmount` | Yes | Decimal | Net payable invoice amount |
| `sale.payment_method` | `PaymentMode` | Yes | Integer | 1 = Cash, 2 = Card, 3 = Mobile Wallet |

---

## 4. Invoice State Machine & Lifecycle

```
[Local Sale Saved] ──> [FBR Pending] ──> [Submitting API] ──> [ACCEPTED: FBR Invoice # & QR]
                                                │
                                                └──> [FAILED: Offline / Timeout] ──> [Retry Queue]
```

- **Preview & Offline Safety**: Local sale, inventory stock deduction, and General Ledger entries commit before FBR API invocation.
- **Failures & Timeouts**: If FBR API fails or times out, local sale stays intact with `fbr_status = 'pending'`. The user can tap **Retry FBR Submission**.
- **No Duplicate Sales**: Retries transmit the same `USIN` to prevent duplicate FBR invoice creation.

---

## 5. FBR QR Code Payload Specification
When FBR accepts an invoice, the thermal receipt prints an official verification QR code payload:

```text
FBRInvoiceNumber|USIN|POSID|DateTime|TotalAmount|SalesTaxAmount|PNTN
```

Example QR Payload:
```text
700001202608281042|INV-10042|700001|2026-08-28 17:30:00|12500.00|1875.00|7000000-0
```

---

## 6. Testing & Certification Status
BizManager is marked as **"FBR Integration Ready"**. Full FBR certification is completed upon user configuration with official PRAL sandbox/live merchant credentials.
