# PlanApp — Architecture

## 1. Stack
Swift 6, SwiftUI, SwiftData. Min iOS 18. No third-party dependencies.

## 2. Modules
- `Invoicing/InvoiceStore.swift` — `@MainActor` store owning invoice state transitions.
- `Invoicing/InvoiceSender.swift` — protocol wrapping the network send; production impl calls `POST /v1/invoices/{id}/send`.
- `Views/InvoiceDetailView.swift` — detail screen with the Send button.

## 5. Conventions
- **Convention 1:** state transitions live in `InvoiceStore`, never in views.
- **Convention 2:** network access goes through a protocol so tests inject a fake.
- **Banned pattern:** `DispatchQueue.main.async` — use `@MainActor`.

## 6. Testing strategy
Swift Testing for unit tests (`InvoiceStoreTests`); XCUITest for flows. UI is driven by `SeedScenario` launch arguments.
