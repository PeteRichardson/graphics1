# graphics1 — Design Document

*Last updated: 2026-08-05*

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
rotation fresh — translate to center, rotate, translate back. Drawing
applies that transform to that path.

Hit testing used to as well, and that shared transform was what kept the
two from drifting apart. `contains` now takes a shortcut instead: it
rotates the *point* backwards into the item's own frame and evaluates the
ellipse equation directly, so a drag event costs arithmetic rather than a
`Path` allocation per item. The saving is irrelevant at two items and the
review said as much — it was taken because the geometry had by then been
covered by tests, not because the allocation hurt.

The cost is that the two derivations are now independent, so they *can*
drift: a sign error in the inverse rotation would make items grabbable at
the mirror image of where they are drawn, and the app would look correct
while feeling broken. `ItemTests.containsAgreesWithTheShapeItDraws` exists
to make that impossible to merge — it compares the two definitions across
a grid of points at 24 rotations, and it is the only test that catches a
sign flip.

**`ContentView`** renders every item into a single `Canvas` inside a
`GeometryReader`, with the button bar as a sibling row beneath it in a
`VStack`. It holds the item array, the selection and drag indices, the
inertia timer, and the drag-velocity bookkeeping.

The bar was originally overlaid in front of the canvas via a `ZStack`,
which cost more than it looked like it did: buttons are hit-testable
views, so a shape resting under one could not be grabbed at all — the
click was consumed by the button and `itemIndex(at:)` never ran. Since
the canvas has no panning, a shape parked there was reachable only via
the Center button. Giving the bar its own row means the canvas stops
where the bar starts, and every point the canvas draws on is a point it
can be grabbed at.

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
`Timer` advances every item that still has velocity and zeroes an item once
it drops below the rest threshold. The timer skips whichever item is
currently held, so grabbing a coasting shape stops it dead, and it
invalidates itself once nothing is moving.

Each tick measures how much time has actually elapsed rather than assuming
its nominal interval, so distance is `velocity * dt` and friction is
`Inertia.decay(dt:)` — the tuned per-tick constant raised to the number of
reference ticks that `dt` covers. `Timer` coalesces late fires instead of
catching up, so a fixed step would have made motion slow down whenever the
main thread was busy. The timer is registered in `.common` run-loop modes,
without which it stops firing during a live window resize or an open menu,
and `stopInertia()` tears it down on `.onDisappear`. All the tuning
constants live on the `Inertia` enum.

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
of this project that was interesting to write. The trade-off is that
`Timer` is wall-clock scheduled rather than display-linked, so its ticks
are not aligned to vsync and motion can judder on a high-refresh display.
It does *not* affect speed: the step integrates against measured elapsed
time, so a given span of real time produces the same motion whatever the
tick cadence. `CADisplayLink` is the alternative that would remove the
judder, at the cost of the explicit loop being the point of the exercise.

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
- [ ] **The simulation is not display-synchronised.** `Timer` is
      wall-clock scheduled rather than vsync-aligned, so motion can judder
      on a high-refresh display even though its *speed* is now correct.
      `CADisplayLink` would fix it.
- [ ] **The gesture handling and simulation loop have only end-to-end
      coverage.** `Item`'s pure geometry — `contains`, `transform`, `center`,
      `boundingBox` — and `Inertia.decay(dt:)` are unit tested in
      `graphics1Tests/`. The drag gesture, the pick/preview/commit flow, and
      the simulation loop are embedded in the view and cannot be, so
      `graphics1UITests/` reaches them by driving the real app and comparing
      screenshots. That proves a drag moves *something* on the canvas; it
      cannot assert which shape ended up where, because `Canvas`-drawn content
      has no accessibility representation to query. Asserting on positions
      needs either that representation or the extraction.
- [ ] **`Item` assumes an ellipse.** `path` hardcodes `Path(ellipseIn:)`,
      so adding a second shape kind means either a shape enum or turning
      `Item` into a protocol.

---

## Document History

| Date | Change |
|------|--------|
| 2026-08-04 | Initial document generated from codebase |
| 2026-08-05 | Corrected the momentum/refresh-rate claim; folded in the timer fixes from #30 |
| 2026-08-05 | Selection is now visible; `dotAtPoint` moved onto `Item` (#13, #22, #23) |
| 2026-08-05 | `Item`'s hit-test geometry covered by tests (#11) |
| 2026-08-05 | Button bar moved out of the `ZStack` overlay into its own row (#14) |
| 2026-08-05 | `contains` became arithmetic rather than a `Path` hit test (#28) |
| 2026-08-05 | UI test stubs replaced with real launch/click/drag coverage (#12) |
