---
git_sha: 241eff2
generated_at: 2026-09-16T12:00:00-07:00
scope: whole repo
---

# graphics1 — Project Review

*Updated 2026-09-16 against `241eff2`. Previous audit 2026-08-05 against `2f73d1f` (F1–F29).*

---

## Executive summary

1. **24 of the 29 prior findings are RESOLVED.** All quick wins from the last audit landed: the preview works, the timer is time-based and runs in `.common` modes, the docs are correct, the test stubs became real suites, selection is visible, the button bar no longer eats clicks, and all six idiom items are fixed. The repo is in materially better shape than six weeks ago.
2. **NEW F32 is the one behavioral defect this audit found: the Center button does not stop a coasting shape.** Fling an oval off-screen and press <kbd>0</kbd> — it teleports to the center and then keeps flying, because its velocity survives the move. The button fails in exactly the runaway-fling scenario it exists to recover from.
3. **The biggest carried-over item is still F6/issue #8** — the gesture pick/preview/commit flow and the inertia loop live on `ContentView`, so they have only screenshot-level coverage, and the menu-bar command feature (#39) is blocked on the same extraction.
4. **NEW F30: `AppState` is still `ObservableObject`/`@Published`/`@EnvironmentObject`.** The target is macOS 15.5, where `@Observable` is the idiom — and the house style rules explicitly say to avoid Combine.
5. **NEW F33: the selection outline is accent-on-blue.** The default macOS accent is blue and the launch-selected item is blue, so the affordance added for F12 is nearly invisible in the app's default state.
6. **NEW F35: `AGENTS.md` is an untracked, verbatim copy of `CLAUDE.md`** (only the title line differs). `CLAUDE.md` changed in most recent commits; a manual copy will drift immediately.
7. **F15's cost has materialized.** Canvas content still has no accessibility representation, which is now why the UI tests must compare screenshots against a measured noise floor instead of asserting positions. Severity stays Low for a sandbox, but it is no longer hypothetical.
8. **Tooling is clean**: zero compiler warnings (the `appintentsmetadataprocessor` lines are toolchain noise), and `swiftformat --lint` reports 0/6 files needing changes — down from 18 violations last audit.
9. **No new category was needed**; all nine new findings fit the existing vocabulary, and the `category:` labels already on GitHub match it exactly.

**Scope note on finding count.** The protocol suggests 30–80 findings; this repeat run carries 5 open findings forward and adds 9 new ones (F30–F38), for 14 open against ~400 lines of non-test Swift. That is where genuine signal ran out — most of what the first audit found has been fixed, and padding a healthy 400-line repo to 30 findings would manufacture noise. Nothing here is Critical or High.

---

## Architectural mental model

`graphics1` is a single-window macOS SwiftUI app with no persistence, no networking, and no third-party dependencies. Two source files carry the app: `graphics1App.swift` owns the scene, the ⌘D debug `CommandMenu`, and a one-flag `AppState`; `ContentView.swift` owns everything else — the `Inertia` tuning/maths enum, the `Item` model, drawing, gestures, hit testing, the inertia loop, and the button bar.

The defining choice is unchanged: shapes draw *immediately* into one `Canvas`, so SwiftUI provides no per-item views, no hit testing, and no gesture attachment — all three are hand-rolled (`Item.contains(_:)`, `itemIndex(at:)`, one `DragGesture` resolving its target from `startLocation`). What has changed since the last audit is that the *pure* parts of that machinery have been extracted and tested: `Inertia.decay(dt:)` is a covered pure function, `Item`'s geometry (including the new arithmetic hit test) is held to the drawn shape by `containsAgreesWithTheShapeItDraws`, and the UI tests cover launch, click-to-redraw, and drag end-to-end via calibrated screenshot comparison. The remaining structural gap is the part still fused to the view: the gesture's pick/preview/commit stages and the timer loop itself (F6), which is also what keeps selection state unreachable from the `App` scene (#39).

One subtlety worth carrying in your head: hit testing and drawing used to share one `CGAffineTransform` and could not disagree; `contains` now derives the inverse rotation by hand for speed, so they *can* — a sign flip would make grabbing a mirror image of what's drawn. `ItemTests.containsAgreesWithTheShapeItDraws` is the single test holding them together. My model matches `README.md`, `docs/design.md`, and `CLAUDE.md`; all three are accurate as of `241eff2`.

---

## Findings

Repeat-run mode. F1–F29 keep their original IDs; the Phase 1 scan (live doc, committed review docs, commit messages across all branches) found F29 as the highest ID ever minted, so new findings start at **F30**.

### Resolved since `2f73d1f`

| ID | Category | Severity | Resolution |
|----|----------|----------|------------|
| F1 | Correctness & memory safety | High | RESOLVED — `#Preview` injects `AppState` (`d39e19c`); `graphics1/ContentView.swift:366-369` |
| F2 | Correctness & memory safety | Medium | RESOLVED — timer registered via `RunLoop.main.add(_:forMode: .common)` (`55fbb40`); `graphics1/ContentView.swift:354` |
| F3 | Correctness & memory safety | Medium | RESOLVED — `stopInertia` wired to `.onDisappear` (`55fbb40`); `graphics1/ContentView.swift:280` |
| F4 | Correctness & memory safety | Medium | RESOLVED — the step integrates against measured `dt` with `Inertia.decay(dt:)` (`55fbb40`); `graphics1/ContentView.swift:316-321` |
| F5 | Documentation drift | Medium | RESOLVED — ProMotion claim corrected in both docs (`e8b905c`) |
| F9 | Test debt | Medium | RESOLVED — vacuous `example()` stub deleted (`700f8d6`) |
| F10 | Test debt | Medium | RESOLVED — `ItemTests.swift` covers geometry incl. the box-but-not-ellipse case (`496e0ec`) |
| F11 | Test debt | Low | RESOLVED — UI test stubs replaced with launch/click/drag coverage (`241eff2`) |
| F12 | UX & CLI ergonomics | Medium | RESOLVED — selected item stroked in `Item.selectionColor` (`2dbc13e`); but see NEW F33 |
| F13 | UX & CLI ergonomics | Medium | RESOLVED — button bar moved to its own `VStack` row (`de0a710`) |
| F16 | UX & CLI ergonomics | Low | RESOLVED — C/[/]/0 shortcuts with `.help` tooltips (`e30448e`) |
| F17 | Idiom debt | Medium | RESOLVED — `Color.random` is now a function (`2b728c1`) |
| F18 | Idiom debt | Medium | RESOLVED — unused `size` parameter is now `_` (`86593e7`) |
| F19–F21 | Idiom debt | Medium | RESOLVED — swiftformat applied (`86593e7`); lint now clean |
| F22 | Idiom debt | Medium | RESOLVED — `dotAtPoint` became `Item.dot(at:radius:)` (`2dbc13e`) |
| F23 | Consistency rot | Low | RESOLVED — debug overlay unified on `debugColor` (`2dbc13e`); `graphics1/ContentView.swift:141,144` |
| F24 | Consistency rot | Low | RESOLVED — `canvasCenter` marked `private` (`26c1665`) |
| F25 | Consistency rot | Medium | RESOLVED — constants hoisted onto the `Inertia` enum (`55fbb40`); covered by `InertiaTests.swift` |
| F26 | Dependency & config debt | Low | RESOLVED — unused file-access entitlement removed (`a5b1246`) |
| F27 | Dependency & config debt | Low | RESOLVED — dead `.gitignore` rules dropped (`425ce97`) |
| F28 | Dependency & config debt | Low | RESOLVED — `.swift-version` added (`bf35133`) |
| F29 | Performance & resource hygiene | Low | RESOLVED — `contains` is arithmetic, no `Path` allocation (`7e1d9e7`), with the agreement test the rewrite required |

### Open

| ID | Status | Category | File:Line | Severity | Effort | Description | Recommendation |
|----|--------|----------|-----------|----------|--------|-------------|----------------|
| F6 | OPEN (updated) | Architectural decay / Test debt | `graphics1/ContentView.swift:176-208, 307-356` | Medium | M | Partially addressed since last audit: `Inertia`'s maths and `Item`'s geometry are extracted and unit-tested, and the UI tests now cover the end-to-end path. What remains fused to the view is the gesture's pick/preview/commit flow and the inertia timer loop, which have only screenshot-level coverage — and the same coupling keeps `items`/`selectedItem` unreachable from the `App` scene, blocking the menu-bar commands ([#39](https://github.com/PeteRichardson/graphics1/issues/39)). Tracked as [#8](https://github.com/PeteRichardson/graphics1/issues/8). | Extract a simulation/store type owning `items`, `selectedItem`, `step(dt:held:)`, and `itemIndex(at:)`; `ContentView` renders it. One change unblocks unit tests for the loop *and* #39. |
| F7 | OPEN | Architectural decay | `graphics1/ContentView.swift:160,163` | Medium | M | `selectedItem: Int` and `draggedItem: Int?` are array indices; they silently retarget if items are ever added, removed, or reordered. Still latent — no such UI exists. Tracked as [#1](https://github.com/PeteRichardson/graphics1/issues/1). | `Item: Identifiable` with a stable id; key selection and drag off the id. |
| F8 | OPEN | Architectural decay | `graphics1/ContentView.swift:56` | Low | M | `Item` still mixes geometry, appearance, and simulation state (`velocity`). Tracked as [#9](https://github.com/PeteRichardson/graphics1/issues/9). | Fold into F6's extraction — the simulation type owns velocity keyed by item id. |
| F14 | OPEN | UX & CLI ergonomics | `graphics1/ContentView.swift:181-190` | Low | S | A drag starting on empty canvas still resolves no item and silently does nothing. | Becomes canvas panning when [#2](https://github.com/PeteRichardson/graphics1/issues/2) lands; until then a hover cursor change over shapes is the cheap mitigation. |
| F15 | OPEN (updated) | UX & CLI ergonomics | `graphics1/ContentView.swift:211-225` | Low | M | Canvas-drawn shapes still have no accessibility representation — VoiceOver sees an empty rectangle. The cost is no longer hypothetical: it is the stated reason ([#15](https://github.com/PeteRichardson/graphics1/issues/15), and the class comment in `graphics1UITests/graphics1UITests.swift:10-30`) the UI tests must compare screenshots against a measured noise floor rather than asserting which shape ended up where. | `Canvas` supports `accessibilityChildren`; adding it fixes assistive tech and gives XCUITest something to query, simplifying the UI tests as a side effect. |
| F30 | NEW | Idiom debt | `graphics1/graphics1App.swift:10-12`, `graphics1/ContentView.swift:161` | Medium | S | `AppState` is `ObservableObject` with `@Published`, consumed via `@EnvironmentObject`. On a macOS 15.5 target the idiom is the `@Observable` macro with `@Environment` — finer-grained invalidation, no Combine dependency (which `CLAUDE.md`'s style rules say to avoid). True maintenance severity Low; ranked Medium per the idiom floor. | `@Observable class AppState`, hold it in `@State` on the `App`, inject with `.environment(appState)`, read with `@Environment(AppState.self)`. The `CommandMenu` toggle keeps working: `$appState.debug` projects through `@State`'s `Binding` via dynamic member lookup. |
| F31 | NEW | Idiom debt | `graphics1/ContentView.swift:285-287` | Medium | S | `itemIndex(at:)` hand-rolls `items.indices.reversed().first { items[$0].contains(point) }` where the standard library has the exact operation: `items.lastIndex(where:)`. The stdlib form also states the intent — "topmost = last drawn" — without the reversed-indices detour. True maintenance severity trivial; ranked Medium per the idiom floor. | `items.lastIndex { $0.contains(point) }`, keeping the doc comment about z-order. |
| F32 | NEW | UX & CLI ergonomics / Data integrity & robustness | `graphics1/ContentView.swift:267-276` | Medium | S | The Center button repositions the selected item but leaves its `velocity` intact, so centering a coasting shape teleports it to the middle and it immediately flies off again. The button was added *for* runaway flings (commit `62b1029`: "a 'center' button for when it goes offscreen"), and that is precisely the case where the shape still has velocity. Grabbing an item zeroes its velocity (`:186`); the only other recovery affordance doesn't. | Add `items[selectedItem].velocity = .zero` to the Center action. |
| F33 | NEW | UX & CLI ergonomics | `graphics1/ContentView.swift:152, 54, 159` | Low | S | `Item.selectionColor` is `.accentColor`, the default macOS accent is blue, and the item selected at launch is the blue oval — so in the app's default state the selection outline is blue-on-blue and nearly invisible. The affordance F12 added disappears exactly where a first-time user looks for it. | Give the stroke contrast independent of the fill: a two-pass outline (wider `.white`/`.primary` stroke under the accent stroke), or stroke in `.primary`. |
| F34 | NEW | UX & CLI ergonomics | `graphics1/ContentView.swift:40-46` | Low | S | `Color.random()` draws uniformly from 13 colors including the current one, so Random Color / <kbd>C</kbd> visibly does nothing ~1 time in 13. A button that intermittently no-ops reads as a bug. | Exclude the item's current color: pass it in and draw from `all.filter { $0 != current }`. |
| F35 | NEW | Documentation drift | `AGENTS.md` (untracked, repo root) | Low | S | `AGENTS.md` is a verbatim copy of `CLAUDE.md` — the only diff is the title and audience line ("guidance to Codex"). `CLAUDE.md` is updated in most feature commits, so a manual copy drifts immediately; and untracked, it is invisible to review. Two parallel sources of agent truth is the same defect class as F5. | Decide its fate: commit it as a symlink to `CLAUDE.md` (the common convention — both tools follow symlinks), or gitignore it and generate it. Don't hand-maintain two copies. |
| F36 | NEW | Architectural decay | `graphics1/ContentView.swift:1-369` | Low | S | The file has grown 55% since the last audit (238 → 369 lines) and now holds four separable units: the `Inertia` enum, the `Color` extension, `Item` + its constants extension, and `ContentView`. The test targets already split along exactly these seams (`InertiaTests.swift`, `ItemTests.swift`). Not a god file yet; this is trajectory, not crisis. | Move `Item` (+ its extension) and `Inertia` into `Item.swift` and `Inertia.swift`. Pure file moves, no API changes. |
| F37 | NEW | Idiom debt | `graphics1/graphics1App.swift:15` | Medium | S | `struct graphics1App` is a lowercase type name — Swift's API Design Guidelines require UpperCamelCase for types, and this is the kind of thing a fluent Swift reader trips on every visit. Xcode template output derived from the project name, not an authored choice. Renaming only the struct is safe; nothing else references it. True maintenance severity trivial; ranked Medium per the idiom floor. | Rename to `Graphics1App`. The `@main` attribute doesn't care, and the target/product name is unaffected. |
| F38 | NEW | Test debt | `graphics1UITests/graphics1UITests.swift:164, 197` | Low | S | Both canvas tests park the pointer with `hover()` on a bar button — and those buttons now carry `.help` tooltips (added the same day, `e30448e`). A tooltip materializing between two captured frames is the same artifact class as a moved cursor, which this suite was specifically rebuilt to exclude. Probably saved today by click-suppression and capture speed, but the interaction is luck, not design. | Park on an inert coordinate instead — e.g. `app.windows.firstMatch.coordinate(withNormalizedOffset: .init(dx: 0.02, dy: 0.02)).hover()` — so nothing under the pointer can render. |

---

## Top 5 — if you fix nothing else

### 1. Make Center actually rescue a flung shape (F32)

One line, and the app's only recovery affordance starts working in the scenario it was built for:

```diff
 Button(action: {
+    items[selectedItem].velocity = .zero
     items[selectedItem].position = CGPoint(
         x: canvasCenter.x - items[selectedItem].width / 2,
         y: canvasCenter.y - items[selectedItem].height / 2
     )
 }) {
```

### 2. Extract the simulation/store (F6, unblocks F7, F8, #39)

Unchanged in substance from the last audit, but it now blocks a *feature* (#39's menu-bar commands need `selectedItem` outside the view), which changes its priority. Sketch:

```swift
@Observable final class ShapeStore {
    var items: [Item]
    var selectedItem: Int
    func step(dt: TimeInterval, held: Int?) { /* moved from startInertia's closure */ }
    func itemIndex(at point: CGPoint) -> Int? { items.lastIndex { $0.contains(point) } }
}
```

`ContentView` keeps the gesture and the `Timer`, but each tick calls `store.step(dt:held:)` — the loop body becomes a pure, testable function, and a `CommandMenu` can reach the store through the environment. Doing this as `@Observable` also subsumes F30's migration.

### 3. Migrate `AppState` to `@Observable` (F30)

Small, self-contained, and it's the pattern #2 above should be built on — do it first as the warm-up:

```diff
-class AppState: ObservableObject {
-    @Published var debug: Bool = false
+@Observable
+class AppState {
+    var debug: Bool = false
 }
```

with `@State private var appState = AppState()`, `.environment(appState)`, and `@Environment(AppState.self)` in `ContentView`.

### 4. Give the selection outline contrast (F33)

In `Item.draw`, stroke twice so the outline reads against any fill, including blue-on-blue:

```swift
if selected {
    ctx.stroke(rotatedItemPath, with: .color(.white), lineWidth: Item.selectionLineWidth + 2)
    ctx.stroke(rotatedItemPath, with: .color(Item.selectionColor), lineWidth: Item.selectionLineWidth)
}
```

### 5. Stop hand-maintaining two agent docs (F35)

```sh
rm AGENTS.md && ln -s CLAUDE.md AGENTS.md && git add AGENTS.md
```

Both Claude Code and Codex follow symlinks; one source of truth, zero drift.

---

## Quick wins

Low effort × Medium-or-higher severity:

- [ ] **F32** — zero velocity in the Center action (one line)
- [ ] **F30** — `AppState` → `@Observable`
- [ ] **F31** — `itemIndex(at:)` → `items.lastIndex(where:)`
- [ ] **F37** — `graphics1App` → `Graphics1App`

Low severity but equally cheap while you're in there: F33 (outline contrast), F34 (exclude current color), F35 (symlink), F38 (inert pointer parking).

---

## Things that look bad but are actually fine

- **`Inertia.tickInterval` (1/60) and `Inertia.referenceRate` (60) both encode "60"** and look like the duplicated-constant bug F25 flagged. They are deliberately independent: one is the timer's requested cadence, the other is the baseline `friction` was tuned against. Changing the tick rate must *not* change the feel — that independence is the whole point of `decay(dt:)`, and `InertiaTests.decayDependsOnElapsedTimeNotTickCount` asserts it.
- **`for i in items.indices` with subscript mutation** in the timer loop (`ContentView.swift:324-343`) still looks like a C-style loop. It remains the idiomatic way to mutate value-type array elements in place; `for item in items` yields copies. (F31 flags `itemIndex` — that one *reads*, so `lastIndex(where:)` applies; the mutating loop is different.)
- **`Thread.sleep(forTimeInterval: 3)` in `testDraggingAnOvalMovesIt`** (`graphics1UITests.swift:195`) is the kind of hard sleep test guides warn about. Here it's right: the fling physically needs wall-clock time to coast to rest, and there is no element to hang an expectation on because the canvas exposes none (F15). An expectation-based wait would be dressing the same sleep in more code.
- **`zip(a, b).lazy.filter { $0 != $1 }.count` over ~23.7M bytes per comparison** (`graphics1UITests.swift:75`) looks like an accidental O(n) walk of a huge buffer. It is a deliberate one — four comparisons per test at ~100ms each, versus the multi-second app launch each test already pays.
- **`velocity: CGSize`** — a size type holding a vector reads as semantic misuse, but `DragGesture.Value.translation` *is* a `CGSize`, so a custom vector type would add conversion noise at every boundary for no behavioral gain.
- **Rebuilding `transform` on every draw and hit test** — carried from the last audit; caching it would trade a few arithmetic ops for a staleness invariant.
- **`all.randomElement() ?? .black`** — carried; the alternative is a force-unwrap.
- **`Item.dot` being internal rather than private** — documented at the declaration (`ContentView.swift:111-112`): it's internal so `ItemTests` can reach it. Deliberate, not drift.
- **`Item`'s default property values are never used bare** — carried; they keep the struct constructible in tests without arguments, and `ItemTests.item(rotatedBy:)` now actually leans on them.
- **`Button(action:) { label }` rather than trailing-closure `Button { } label: { }`** — both are idiomatic; the file is internally consistent. Not worth churn.

---

## Open questions for the maintainer

- **Is `AGENTS.md` an experiment or a commitment?** (F35) It's untracked and byte-identical to `CLAUDE.md` today. If you're trialing Codex, a symlink commits you to nothing; if it was a one-off test, delete it before it silently rots.
- **Is the add/remove-shapes feature ever coming?** F7 and F8 remain latent-only because the scene is fixed at two hardcoded ovals. Issues #1 and #9 stay correctly parked until that answer changes.
- **Is `debugColor` meant to become per-item configurable?** Carried from the last audit and still unresolved: it's now used consistently (F23 fixed that), but nothing ever sets it to anything but the default. If no plan exists, it's a deletable property.
- **Is CI worth setting up now that the suites are real?** The unit tests would run anywhere. The UI tests are the question: the screenshot thresholds self-calibrate per run, which was designed with alien environments in mind, but that design is unproven off this machine. A CI job running `graphics1Tests` only would be the low-risk start.
- **Does the `@Observable` migration (F30) fit the learning goals?** The repo deliberately hand-rolls things for pedagogy. If `ObservableObject` is intentional for compatibility with older learning material, say so in `CLAUDE.md` and F30 closes as won't-fix — but note the house style already bans Combine, which is in tension with keeping it.

---

## Appendix — tooling

| Tool | Status | Result |
|------|--------|--------|
| `xcodebuild` (via Xcode BuildProject, incl. test targets) | ✅ ran | Clean. Zero project warnings; the three `appintentsmetadataprocessor` lines are toolchain noise. |
| `swiftformat --lint` (with `.swift-version` 5.0) | ✅ ran | **0/6 files require formatting** — down from 18 violations at the last audit. F19–F21/F28 confirmed resolved. |
| `gh` (labels, issues) | ✅ ran | `category:`/`severity:`/`effort:` label vocabulary matches this report's; 6 open issues, all mapped to findings above. |
| `swiftlint` | ❌ not installed | Not installed globally without permission. Carried from last audit. |
| `periphery` | ❌ not installed | Manual inspection found no dead code; low value at this size. |
| Dependency audit | N/A | Still no SwiftPM manifest, packages, or third-party code. |

---

## Document history

| Date | Change |
|------|--------|
| 2026-08-05 | Initial audit against `2f73d1f`. 29 findings, F1–F29. |
| 2026-09-16 | Repeat run against `241eff2`. 24 findings marked RESOLVED; F6/F15 updated; 9 new findings F30–F38. |
