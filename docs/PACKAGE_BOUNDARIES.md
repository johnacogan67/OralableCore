# OralableCore Package Boundaries

**Status:** Current single-target boundary contract  
**Applies to:** the `OralableCore` SwiftPM library and its consumers in `oralable_swift`.

## Current architecture

`Package.swift` intentionally publishes one product and one implementation target, `OralableCore`. It compiles all source folders under `Sources/OralableCore`, so it is **not** yet a set of independently importable Swift modules.

This is acceptable while the package remains lightweight and avoids external dependencies, but it makes its internal layers an architectural contract. New work must follow the sub-boundaries below so a future target split is mechanical rather than a cross-app rewrite.

## Internal sub-boundaries

| Layer | Current folders | Responsibility | Dependency rule |
|---|---|---|---|
| **Signal and domain foundation** | `Algorithms/`, `Filters/`, `Signal/`, value-oriented parts of `Models/`, `Utilities/ClinicalThresholds.swift` | Sampling, filters, packet-independent biometric math, stable data values, and algorithm constants | Must not import SwiftUI, CloudKit, StoreKit, application lifecycle APIs, or CSV/EDF exporters. It may use Foundation, Accelerate/Core ML where genuinely required, and the shared model types. |
| **Device integration** | `BLE/`, `Calibration/`, `Calculations/` | GATT parsing, streaming buffers, coupling, real-time processing, calibration, and Core ML feature preparation | May depend on the foundation layer. It must not depend on presentation views, CloudKit persistence, or file-export implementation. |
| **Data exchange** | `CSV/`, `Export/`, serializable CloudKit record models | CSV/EDF interchange, serialized session/event representations, and professional handoff payloads | May depend on foundation models. It must not drive BLE, inference, or UI behavior. |
| **Cloud/service adapters** | `CloudKit/` | Cloud-record schema adapters and professional-session export integration | May depend on foundation/data-exchange models. It must not become the owner of signal-processing or UI decisions. |
| **Presentation support** | `DesignSystem/`, `SharedComponents/`, SwiftUI-specific model conveniences | Reusable visual primitives and charts | May consume foundation values but must not be imported by signal, BLE, inference, export, or persistence code. |
| **Application composition** | `oralable_swift/OralableApp/` (outside this package) | App lifecycle, navigation, permissions, account/service configuration, screens, feature rollout, and product claims | Owns composition of Core facilities. It must not copy signal/GATT constants already exposed by Core. |

## Import-direction rules

```text
Foundation ← Device integration ← Application composition
     ↑              ↑
Data exchange ──────┘
     ↑
Cloud/service adapters

Foundation → Presentation support → Application composition
```

The arrow means “may depend on.” In particular:

- `Algorithms`, `Filters`, and `Signal` must remain usable without SwiftUI or CloudKit.
- `MAMInferenceManager`, `SpO2Service`, and other calculations must return domain values; screens and view modifiers belong in the app or the presentation-support layer.
- `CSV`, `Export`, and `CloudKit` code must serialize already-computed data rather than calculate or reinterpret biometric outcomes.
- A product feature needing lifecycle, entitlement, HealthKit, App Store, or navigation behavior belongs in the application repository, not `OralableCore`.

## Resources and model policy

`Resources/` is package-owned, but model eligibility is not inferred from resource presence. `BruxismMAM_Temporalis` has a provenance sidecar and is loaded only when it is explicitly approved as non-stub and release-eligible. See the research hub’s `docs/MODEL_PROVENANCE.md`.

## Test ownership

- Pure algorithm/filter/data tests belong under `OralableCoreTests` and must run on macOS without an app host.
- BLE/GATT parsing tests use captured payload fixtures and do not require physical hardware.
- CSV/EDF and CloudKit adapter tests validate representation and schema mappings, not app navigation.
- SwiftUI presentation tests should exercise reusable rendering/configuration only; app flows belong in `oralable_swift` tests.

## Future modularization (not part of this change)

A future split should preserve public API names while moving code in this order:

1. `OralableSignalCore`: `Algorithms`, `Filters`, `Signal`, pure models, and threshold utilities.
2. `OralableDevice`: BLE parsing/buffers, calibration, and real-time calculation services; depends on `OralableSignalCore`.
3. `OralableDataExchange`: CSV/EDF and serializable session/event models; depends on `OralableSignalCore`.
4. `OralablePresentation`: `DesignSystem` and `SharedComponents`; depends on `OralableSignalCore` only.
5. `OralableServices` (optional): CloudKit adapters; depends on the data/domain targets and stays optional for offline users.

Do not create those targets until package consumers and public symbols have been catalogued, CI builds every product, and migration compatibility shims are planned. Until then, preserve the rules above and record any intentional exception in this document.
