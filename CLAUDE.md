# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

`graphics1` is a small macOS SwiftUI practice app for experimenting with 2D graphics: drawing shapes into a `Canvas`, rotating them, dragging them, and applying inertia. It is a learning sandbox, not a shipping product — expect experimental/half-finished code paths.

Repo root: `/Users/pete/practice/swift/graphics1`. Sources live in `graphics1/`. Note that Xcode is configured with an in-repo DerivedData directory at `Build/` (gitignored) — if a shell session starts inside `Build/graphics1`, that's build output, not source.

## Commands

All commands run from the repo root. There is a single scheme, `graphics1`; the test targets are `graphics1Tests` (Swift Testing) and `graphics1UITests` (XCTest/XCUITest).

```bash
# Build
xcodebuild -project graphics1.xcodeproj -scheme graphics1 -destination 'platform=macOS' build

# Run all tests
xcodebuild -project graphics1.xcodeproj -scheme graphics1 -destination 'platform=macOS' test

# Run a single test target / class / method
xcodebuild ... test -only-testing:graphics1Tests
xcodebuild ... test -only-testing:graphics1UITests/graphics1UITests/testExample

# Run the app
open Build/graphics1/Build/Products/Debug/graphics1.app   # or just run from Xcode
```

Targets macOS 15.5, Swift 5 language mode, bundle id `com.peterichardson.graphics1`. App Sandbox is on (see `graphics1/graphics1.entitlements`).

Formatting is checked with `swiftformat graphics1 graphics1Tests graphics1UITests --lint` (point it at the source directories, not `.` — the in-repo `Build/` directory contains generated Swift that will fail the lint). The `.swift-version` file at the repo root exists solely so swiftformat doesn't disable its version-gated rules; keep it in step with `SWIFT_VERSION` in the project file.

## Architecture

Three files carry everything:

- **`graphics1/graphics1App.swift`** — `@main` entry point. Owns `AppState` (an `ObservableObject` with a single `debug` flag) as a `@StateObject`, injects it into the environment, and exposes a `Debug` command menu with a ⌘D toggle for `debug`. Global UI chrome (menus, window config) belongs here.

- **`graphics1/ContentView.swift`** — everything else: the `Item` model, drawing, gestures, inertia, and the button bar.

- **`graphics1Tests` / `graphics1UITests`** — `InertiaTests.swift` covers the time-stepping maths and `ItemTests.swift` covers `Item`'s geometry helpers. No stubs remain in the unit target; `graphics1UITests` is still Xcode-generated stubs.

### The drawing model

`Item` is a plain struct holding `position` (its bounding box's *origin*, not its center), `width`/`height`, `rotation`, colors, and its current `velocity`. Two things to keep straight when touching it:

- `position` is the top-left of the bounding box. Anything that wants the center uses the `center` computed property (`boundingBox.midX`/`midY`); the "Center" button still subtracts half the size by hand.
- Rotation is applied as a `CGAffineTransform` from the `transform` property (translate to center → rotate → translate back), not stored in the path. `Item.path` is always the unrotated ellipse, and drawing and hit testing both apply `transform` to it.

`Item.draw(in:debug:)` fills the rotated path and, when `debug` is set, additionally strokes the rotated bounding box and dots the center. New debug visuals go behind that same flag so ⌘D controls them.

`Item.contains(_:)` hit-tests a point against the *rotated* ellipse, so grabbing an item matches what's actually drawn.

### Rendering and interaction

`ContentView` renders all items into one `Canvas` inside a `GeometryReader`, with a button bar overlaid via `ZStack` (aligned to the bottom) so it sits in front of the canvas.

A single `DragGesture` on the `Canvas` handles all items; there are no per-item views to attach gestures to. It works in three parts:

- **Pick** — on the gesture's first `onChanged`, `itemIndex(at: value.startLocation)` returns the topmost item under the cursor (the array is walked in reverse, since later items draw on top). That index is stashed in `@State draggedItem` and mirrored into `selectedItem`, so the button bar acts on whatever you last touched. A drag starting on empty canvas leaves `draggedItem` nil and does nothing.
- **Live preview** — a `@GestureState dragOffset` is added to a *copy* of the dragged item's position at draw time, so the drag is visible without mutating state; the offset resets automatically when the gesture ends. Only the item matching `draggedItem` gets the offset — applying it to every item is what used to make all of them move together.
- **Commit + inertia** — `onEnded` writes the translation into `items[i].position` and calls `startInertia()`.

Velocity is per-item (`Item.velocity`) and measured in `trackVelocity(_:)` by differencing each event's translation and timestamp against the previous one, exponentially smoothed. Don't try to derive it from `value.time` alone.

`startInertia()` runs a single `Timer` that advances *every* item with velocity, skipping whichever one is currently held, and invalidates itself when nothing is moving. Three details matter if you touch it:

- **It integrates against measured elapsed time**, not a fixed step. `Timer` coalesces late fires rather than catching up, so assuming `1/60`s per tick made motion slow down whenever the main thread was busy. Distance is `velocity * dt`, and friction is `Inertia.decay(dt:)` rather than a flat per-tick multiply.
- **The timer is registered in `.common` run-loop modes**, via `RunLoop.main.add(_:forMode:)` rather than `Timer.scheduledTimer`. A default-mode timer stops firing during a live window resize or while a menu is open, which froze coasting items mid-flight.
- **`stopInertia()` is wired to `.onDisappear`**, since the timer's closure otherwise outlives the view that owns it.

All tuning constants live on the `Inertia` enum (`friction`, `restThreshold`, `tickInterval`, `referenceRate`, `velocitySmoothing`) rather than as inline literals. `Inertia.decay(dt:)` is a pure function and is covered by `graphics1Tests/InertiaTests.swift`, as `Item`'s geometry is by `ItemTests.swift`. The simulation *loop* and the gesture handling are not — those live on the view and still require driving the UI.

`selectedItem` drives the button bar, and the selected item is stroked in `Item.selectionColor` by `Item.draw(in:debug:selected:)`. The outline traces the rotated ellipse rather than the bounding box, so it reads as the shape rather than as a box, and it is drawn after the fill so it is never painted over. It is *not* gated on the debug flag — it is a selection affordance, not a debug visual.

`canvasCenter` is assigned from `geo.size` via `onChange(of:initial:)`. The `initial: true` matters — without it the value stays `.zero` until the window is resized and the "Center" button throws the item off-screen.

## Conventions

Commits follow Conventional Commits (`feat:`, `style:`, ...) with a short lowercase subject.
