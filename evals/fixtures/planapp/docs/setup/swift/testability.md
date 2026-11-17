# Testability (Apple projects)

- **Accessibility identifiers:** `{feature}-{element}-{role}` kebab-case, one per interactive element and per dynamic row (e.g. `invoice-save-button`, `invoice-row-\(item.id)`).
- **Deep links:** every screen has a route `planapp://{screen}`; screens without a route cannot be screenshot-verified.
- **Seed scenarios:** UI states are rendered through a `SeedScenario` launch argument — never "tap to set up state".
