# PlanApp — Epics

## Epic 1 — Sending invoices
**Goal:** A freelancer can send a finished invoice and see its status.

### Story 1.1 — Send invoice
**Satisfies:** FR-2, FR-3 | **Enables:** UJ-1

As a freelancer, I can tap Send on a draft invoice and see it become Sent.
- Given a draft invoice with at least one line item, when I tap Send, then the invoice becomes Sent and the detail screen shows a "Sent" badge.

Decisions already made for this story (no open questions):
- Sent is terminal: a Sent invoice cannot be edited, re-sent, or returned to Draft.
- While the send is in flight the Send button is disabled.
- If the network send fails, the invoice stays Draft, an inline error banner with a Retry button appears, and nothing is marked Sent.
- A draft with no line items cannot be sent; the Send button is disabled.
- Surface: `InvoiceDetailView`, a new screen reached from the invoice list.

### Story 1.2 — Invoice list status
**Satisfies:** FR-3

As a freelancer, I see each invoice's status in the list.
- Given invoices in Draft and Sent, when I open the list, then each row shows its status.
