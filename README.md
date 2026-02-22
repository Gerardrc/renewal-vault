# Renewal Vault (iOS MVP)

Native iOS 17+ SwiftUI app for tracking renewals/expirations, attachments, reminders, and Pro subscription features.

## Requirements
- Xcode 15.2+ (recommended latest Xcode 15/16)
- iOS 17+
- Swift 5.9+

## Setup
1. Open the project in Xcode and set your **Bundle Identifier** (e.g. `com.yourcompany.renewalvault`).
2. Ensure Signing team is selected.
3. Add the `StoreKit/RenewalVault.storekit` file to the run scheme for local purchase tests.

## StoreKit product setup (App Store Connect)
Create an auto-renewable subscription group and two products:
- `com.renewalvault.pro.monthly`
- `com.renewalvault.pro.yearly`

Then submit metadata/pricing and attach to app version.

## Local purchase testing
1. In Xcode, Edit Scheme → Run → Options → StoreKit Configuration: select `RenewalVault.storekit`.
2. Launch app and open Paywall.
3. Purchase monthly/yearly and verify Pro gates unlock.
4. Use “Restore Purchases” in Settings to validate restore flow.

## Sandbox testing
1. Create Sandbox Tester in App Store Connect (Users and Access → Sandbox).
2. Sign out of App Store on test device/simulator.
3. Install TestFlight (or debug build with remote products).
4. Purchase using sandbox account when prompted.

## Notifications behavior
- Local notifications only (no APNs).
- Each item schedules one notification per reminder day at 09:00 local time.
- Any item edit/renewal cancels prior requests and reschedules.
- To reset: delete app, or remove item (which clears pending IDs and cancels pending requests).

## Architecture summary
- SwiftUI + MVVM-ish feature slices under `RenewalVault/Features/*`
- SwiftData models in `Core/Domain/Models.swift`
- Runtime in-app language choice via `LanguageManager` + SwiftUI locale environment
- Launch flow router: Language Picker → Onboarding (once) → Main tabs
- Subscription gating centralized in `FeatureGate`

## MVP coverage
- Language picker before onboarding (English/Spanish)
- One-time onboarding
- Vault CRUD (default Personal)
- Item CRUD + reminder day editor
- Home buckets (soon/later/expired), search/upcoming toggle
- Item detail + renewal events
- Local reminders scheduling
- Paywall + purchase/restore + entitlement observation
- Privacy screen
- DEBUG tools: simulate Pro + reset onboarding

## Notes
- Attachment ingest UI (camera/library/files) is scaffold-ready; storage and file protection implementation are included in `AttachmentStorage`.
- PDF export engine is implemented with UIKit PDF renderer (`VaultPDFExporter`).
