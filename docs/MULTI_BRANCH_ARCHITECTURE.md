# Tajer Multi-Branch Architecture

Baseline protected release: `1.0.107+107`

Development branch: `feature/multi-branch-v1`

## Core decision

Tajer remains merchant-centric, but operational financial records become branch-aware.

### Merchant-scoped

- Product catalog identity and commercial definition
- Categories
- Customers
- Suppliers
- Merchant subscription
- Merchant identity/account

### Branch-scoped

- Shifts and cash drawer
- Orders at creation time
- Expenses
- Inventory balances
- Raw-material balances
- Inventory movements
- Supplier financial operations that affect a branch drawer
- Operational reports

### Hybrid

- Employees: merchant-owned, restricted by allowed branch IDs
- Customer debt: customer total remains merchant-wide while each originating order/payment keeps branch provenance
- Supplier debt: supplier total remains merchant-wide while each purchase/payment keeps branch provenance
- Store profile: merchant identity remains global; branch contact/display overrides may be introduced without duplicating legal merchant identity

## Backward compatibility

Legacy documents without `branchId` are treated as belonging to the stable main branch ID:

`main`

No existing 1.0.107 financial document is rewritten merely to enable multi-branch support.

Queries must not silently exclude legacy documents. Any branch-aware repository must explicitly account for legacy main-branch records until a separately reviewed migration is proven safe.

## Accounting invariants

1. A Branch A sale must never mutate Branch B inventory.
2. A Branch A made-to-order sale must never mutate Branch B raw materials.
3. A Branch A void/refund must restore only Branch A inventory/raw materials.
4. A Branch A expense must never affect Branch B shift totals.
5. Customer debt collection must be attributed to the branch where cash/card/transfer was received.
6. Supplier payment must be attributed to the branch whose drawer/bank flow was affected.
7. A shift belongs to exactly one branch.
8. At most one applicable open shift may exist per operational branch/employee policy; merchant-wide single-shift assumptions must be removed deliberately.
9. Branch reports contain only that branch's branch-scoped operations.
10. Consolidated merchant reports equal the mathematical sum of included branch reports, with merchant-wide entities counted only where appropriate.
11. Employees may only operate within allowed branch IDs.
12. `merchantId` isolation remains mandatory in addition to branch isolation.
13. Historical VAT/TaxMode/COGS snapshots remain immutable.
14. PDF/printer invoice financial values come from the historical order snapshot, not live product/store values.
15. Closed-shift historical protections remain valid after branch scoping.
16. Customer and supplier overpayment protections from 1.0.107 remain valid after branch scoping.

## Current high-risk findings from 1.0.107

- `AppOrder` has `merchantId` but no `branchId`.
- `Shift` has `merchantId` but no `branchId`.
- `Expense` has `merchantId` but no `branchId` or persisted `shiftId`.
- Product and raw-material quantities are currently global per merchant document.
- `OrderRepository` directly mutates global product/raw-material quantities and merchant-level inventory logs.
- Void/delete flows restore global quantities and locate an open shift by merchant only.
- `ShiftRepository` currently enforces one open shift per merchant, which is incompatible with simultaneous branches.
- Reports aggregate merchant-wide streams without branch filtering.
- Employee identities are merchant-owned but have no allowed-branch list.
- Firestore rules enforce merchant access but currently have no branch authorization primitive.
- StoreProfile is merchant-level and cached under one local key.
- RevenueCat premium entitlement is currently binary; Business entitlements/limits do not yet exist.

## Implementation safety rule

Do not change formulas merely to add multi-branch. Change data scope and provenance first. Any formula change requires separate evidence and regression tests.
