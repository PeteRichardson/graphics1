# graphics1 — Design Document

*Last updated: 2026-08-04*

---

## Overview

`graphics1` is a small macOS SwiftUI application for experimenting with 2D
graphics: drawing shapes into a `Canvas`, rotating them, dragging them
around, and letting them coast to a stop with momentum. Its only user is
its author, and its purpose is learning rather than shipping — it is a
sandbox for working out how immediate-mode drawing, gesture handling, and
simple physics fit together in SwiftUI.

That framing matters for reading the rest of this document. Where a
production app would reach for the most general solution, this codebase
deliberately takes the most direct one, and several structures exist
because they were interesting to build rather than because the problem
demanded them.

## Goals and Non-Goals

**Goals:**

- Explore immediate-mode drawing with SwiftUI's `Canvas`
- Work out gesture handling and hit testing when there are no per-item views
- Implement momentum and friction by hand, rather than via SwiftUI animation
- Keep the whole thing small enough to read in one sitting

**Non-Goals:**

- Shipping to users, or supporting any platform other than macOS
- Persistence — the scene is rebuilt from hardcoded values on every launch
- A general scene graph, grouping, or nesting of shapes
- Any shape other than an ellipse (the model assumes one)
- Performance work; the item count is two

---

## Architecture

The application is two source files, and the split between them is by
scope rather than by layer. `graphics1App.swift` owns everything global —
the `@main` entry point, the window, the menu bar, and the app-wide debug
flag. `ContentView.swift` owns everything else: the shape model, drawing,
gestures, physics, and the button bar.

There is no view-model layer and no separation between model and view.
`Item` is a struct that knows how to draw itself, and `ContentView` holds
the array of them in `@State`. For a project this size that is a
reasonable trade; the cost is that the interaction logic is only reachable
through the view, which is the main thing standing between this codebase
and having tests.

### Components

**`AppState`** is an `ObservableObject` with a single `@Published var
debug: Bool`. It exists as an observable object rather than as
`@State` on `ContentView` because the toggle that drives it lives in a
`CommandMenu` in the `App` scene — outside the view hierarchy, and so
unable to reach `ContentView`'s own state. Injecting it through
`.environmentObject` lets the menu item and the canvas share one flag.
It is bound to ⌘D.

**`Item`** is the drawing model: a plain struct holding a `position`, a
`width`/`height`, a `rotation`, two colors, and a `velocity`. Two
conventions in it are worth internalizing before touching the code.

First, `position` is the *origin* of the bounding box — its top-left
corner — not its center. Anything that needs the center goes through the
`center` computed property, and the "Center" button has to subtract half
the item's size by hand. This is the single most common source of
off-by-half-a-shape confusion in the codebase.

Second, rotation is never baked into the item's path. `Item.path` is
always the *unrotated* ellipse, and the `transform` property builds the
rotation fresh — translate to center, rotate, translate back. Drawing and
hit testing both apply that same transform to that same path, which is
what keeps the two from drifting apart: an item is grabbable exactly where
it appears.

**`ContentView`** renders every item into a single `Canvas` inside a
`GeometryReader`, with the button bar overlaid via a `ZStack` aligned to
the bottom so it sits in front. It holds the item array, the selection and
drag indices, the inertia timer, and the drag-velocity bookkeeping.

### Data Flow

The interesting path through the system is a drag, and it runs in three
stages through a single `DragGesture` attached to the `Canvas`.

Because everything is drawn into one canvas rather than composed from
per-item views, there is nothing for a gesture to attach to per item —
so the first stage is *picking*. On the gesture's first `onChanged`,
`itemIndex(at:)` walks the array in reverse (later items draw on top, so
reverse order finds the topmost first) and asks each item whether its
rotated path contains the drag's start location. The winner is stashed in
`draggedItem` and mirrored into `selectedItem`, so the button bar follows
whatever you last touched. A drag beginning on empty canvas finds nothing
and does nothing.

The second stage is *preview*. Rather than writing to the model on every
gesture event, the canvas adds a `@GestureState` drag offset to a
throwaway *copy* of the dragged item's position at draw time. The item
appears to follow the cursor while the underlying model sits still, and
because `@GestureState` resets itself when a gesture ends, there is no
cleanup to forget. Only the item matching `draggedItem` receives the
offset — applying it to every item is precisely the bug that made all
shapes move together.

The third stage is *commit and coast*. On release, the translation is
written into the real position and `startInertia()` takes over: a single
60 Hz `Timer` advances every item that still has velocity, multiplies each
velocity by 0.92 per tick, and zeroes an item once it drops below 0.5
points per second. The timer skips whichever item is currently held, so
grabbing a coasting shape stops it dead, and it invalidates itself once
nothing is moving.

---

## Key Design Decisions

**Immediate-mode `Canvas` instead of a view per shape.** This is the
decision the rest of the architecture follows from. Drawing into one
canvas means shapes cost nothing in view-hierarchy terms and the drawing
code is explicit and easy to reason about. The price is that SwiftUI's
gesture and hit-testing machinery no longer applies — there are no views
to attach gestures to and no automatic notion of what was clicked — so
hit testing had to be written by hand, and selection has to be tracked
manually. An earlier abandoned attempt tried to keep per-item views inside
the `Canvas` closure for their gestures; that cannot work, because
`Canvas`'s content builder does not render views.

**Rotation as a draw-time transform rather than transformed geometry.**
Storing the unrotated path and rebuilding the transform on demand keeps
one source of truth for the shape. Rotating an item is a change to a
single `Angle`, with no accumulated floating-point drift from repeated
transformation, and hit testing gets to reuse the exact transform that
drawing used.

**Preview-copy dragging rather than mutating on every event.** Writing
each gesture event straight into the model works, but it makes the model
churn continuously during a drag and makes cancellation messy.
`@GestureState` gives the live feedback for free and resets on its own.

**Hand-rolled physics on a `Timer` rather than SwiftUI animation.**
Friction-based momentum with a variable initial velocity is awkward to
express as a SwiftUI animation curve, and the explicit loop is the part
of this project that was interesting to write. The trade-off is a fixed
60 Hz assumption hardcoded into the per-tick divisor, which does not track
the actual display refresh rate.

**Velocity measured from real event timings.** An earlier implementation
derived the fling speed from `value.time.timeIntervalSince(value.time
.advanced(by: -0.1))`, which is the constant `0.1` regardless of the
drag, making the throw speed simply the total translation times ten — so
a long slow drag threw as hard as a flick. Velocity is now differenced
between consecutive gesture events with 0.7 exponential smoothing, so
pausing before release drops the item gently.

---

## External Dependencies

None. The project links only SwiftUI and the system frameworks it brings
in; there is no SwiftPM manifest and no package references in the Xcode
project. Everything, including the momentum simulation, is written
directly against the standard library and SwiftUI.

---

## Data Model

The entire model is one struct and one array. `ContentView` holds
`items: [Item]`, seeded with two hardcoded ellipses, plus `selectedItem:
Int` (what the buttons act on) and `draggedItem: Int?` (what the current
gesture is moving, `nil` when nothing is grabbed). There are no
relationships between items — no grouping, ordering beyond array position,
or parent/child links. Array order *is* z-order: later items draw on top,
which is why hit testing walks it in reverse.

Both selection and drag are stored as array indices, which is safe only
because nothing can currently add, delete, or reorder items. See Open
Questions.

---

## Configuration and Environment

There is nothing to configure — no environment variables, config files, or
launch flags. The scene is hardcoded in `ContentView`'s initializer, and
the only runtime setting is the debug overlay, toggled with ⌘D and held in
`AppState`.

Building requires Xcode with a macOS 15.5 SDK. The project uses Swift 5
language mode, has App Sandbox enabled via `graphics1.entitlements`, and
is configured with an in-repo DerivedData directory at `Build/` (which is
gitignored — if a shell lands in `Build/graphics1`, that is build output,
not source). Build and test commands are in `CLAUDE.md`.

---

## Open Questions

- [ ] **Selection is invisible.** `selectedItem` decides which shape the
      four buttons affect, but nothing on screen indicates which one it
      is. Clicking a shape selects it silently, so the buttons appear to
      act at random until you know the rule.
- [ ] **Items are tracked by array index.** `selectedItem` and
      `draggedItem` are positions in the array, which stop meaning
      anything the moment items can be added, removed, or reordered.
      Filed as [issue #1](https://github.com/PeteRichardson/graphics1/issues/1)
      — currently latent, since no such UI exists.
- [ ] **The canvas cannot pan.** Items flung with momentum coast off-screen
      with no way to follow them; the Center button is the only way back,
      and it teleports the shape rather than moving the viewport. Filed as
      [issue #2](https://github.com/PeteRichardson/graphics1/issues/2).
- [ ] **Nothing constrains items to the canvas.** There is no clamping or
      edge collision, so a hard enough throw sends a shape into
      coordinates from which only the Center button can retrieve it.
- [ ] **The inertia timer outlives the view.** `inertiaTimer` is
      invalidated when motion stops, but not when `ContentView`
      disappears. With a single window that never happens, so it is
      currently harmless — but it would leak if the app grew a second
      window or a sheet.
- [ ] **The 60 Hz tick is an assumption, not a measurement.** The physics
      step divides by a hardcoded 60 rather than by elapsed time or the
      display's actual refresh rate, so momentum runs at a different speed
      on a 120 Hz ProMotion display than on a 60 Hz one.
- [ ] **There are no tests.** Both test targets contain only Xcode's
      generated stubs. `Item` is the readily testable part — `contains`,
      `transform`, and `center` are pure functions of the struct — but the
      gesture and physics logic is embedded in the view and cannot be
      exercised without either a UI test or extracting it.
- [ ] **`Item` assumes an ellipse.** `path` hardcodes `Path(ellipseIn:)`,
      so adding a second shape kind means either a shape enum or turning
      `Item` into a protocol.

---

## Document History

| Date | Change |
|------|--------|
| 2026-08-04 | Initial document generated from codebase |
