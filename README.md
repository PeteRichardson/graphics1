<!-- 🖊 TODO: Add a logo to docs/images/logo.png and uncomment:
<p align="center">
  <img src="docs/images/logo.png" alt="graphics1 logo" width="200">
</p>
-->

<!-- 🖊 Badges omitted deliberately: this repo has no CI workflow, no releases,
     and no LICENSE file, so CI/version/license badges would all render broken.
     Add them once those exist. -->

# graphics1

> _A macOS sandbox for pushing ellipses around a canvas._

`graphics1` is a small SwiftUI app for experimenting with 2D graphics on macOS:
it draws shapes into a `Canvas`, rotates them, drags them, and lets them coast
to a stop with momentum and friction. It exists to work out how immediate-mode
drawing, manual hit testing, and hand-rolled physics fit together in SwiftUI —
the kind of thing that is easier to learn by building than by reading. It is a
learning sandbox rather than a shipping product: there is no persistence, no
document model, and the scene is two hardcoded ovals rebuilt on every launch.

> **Status:** Experimental / learning sandbox — expect half-finished code paths
> and no API stability.
<!-- 🖊 TODO: Confirm status. Alternatives:
> **Status:** Active development — behavior may change at any time.
> **Status:** Maintenance mode — no new features; bug fixes only.
-->

---

## Table of Contents

- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Controls](#controls)
- [Things to Try](#things-to-try)
- [Development](#development)
- [Architecture](#architecture)
- [Known Limitations](#known-limitations)
- [Contributing](#contributing)
- [License](#license)

---

## Features

- **Independent dragging with real hit testing** — every shape is drawn into a
  single `Canvas`, so there are no per-item views and no hit testing for free.
  Grabbing a shape tests the click against its *rotated* path, so an oval is
  grabbable exactly where it looks like it is, not where its unrotated bounding
  box happens to sit.
- **Per-item momentum** — release a drag and the shape keeps going, slowing
  under friction. Each shape carries its own velocity, so several can coast at
  once, and grabbing a moving one stops it dead.
- **Velocity measured from actual gesture timings** — a slow drag releases
  gently, a flick throws hard, and pausing before you let go drops the shape
  where it is.
- **Rotation about the shape's own center**, applied as a draw-time transform
  so repeated rotation never accumulates drift.
- **A debug overlay on ⌘D** that strokes each shape's rotated bounding box and
  marks its center.

---

## Prerequisites

- **macOS 15.5** or later — the deployment target
- **Xcode** with the macOS 15.5 SDK, including the command-line tools if you
  intend to build from the terminal

No third-party dependencies. The project links only SwiftUI and the system
frameworks it brings in; there is no SwiftPM manifest and no package references
in the Xcode project.

---

## Installation

There are no releases or pre-built binaries. Build from source:

```sh
git clone https://github.com/PeteRichardson/graphics1.git
cd graphics1
xcodebuild -project graphics1.xcodeproj -scheme graphics1 -destination 'platform=macOS' build
```

The project is configured with an in-repo DerivedData directory, so the built
app lands at `Build/graphics1/Build/Products/Debug/graphics1.app` rather than
in `~/Library/Developer/Xcode/DerivedData`. `Build/` is gitignored.

---

## Quick Start

<!-- 🖊 TODO: Add a screenshot or GIF here — by far the highest-ROI addition to
     this README, since the whole point of the app is visual. Record the window,
     drag an oval, fling it, and toggle ⌘D to show the debug overlay.
<p align="center">
  <img src="docs/images/demo.gif" alt="graphics1 demo" width="700">
</p>
-->

```sh
open Build/graphics1/Build/Products/Debug/graphics1.app
```

Or just hit Run in Xcode.

You get a window with two ovals — one blue, one green — and a row of buttons
along the bottom. Drag either oval and let go mid-motion: it keeps traveling and
coasts to a stop. The other one stays put.

---

## Controls

### Mouse

| Action | Result |
|--------|--------|
| Drag an oval | Moves that oval, and selects it for the button bar |
| Release mid-drag | Throws it, with speed taken from the end of your drag |
| Grab a coasting oval | Stops it immediately |
| Drag empty canvas | Nothing — see [Known Limitations](#known-limitations) |

### Buttons

| Button | Key | Result |
|--------|-----|--------|
| **Random Color** | <kbd>C</kbd> | Repaints the selected oval in a random color |
| **Rotate Left** | <kbd>[</kbd> | Rotates the selected oval 15° counter-clockwise |
| **Rotate Right** | <kbd>]</kbd> | Rotates the selected oval 15° clockwise |
| **Center** | <kbd>0</kbd> | Moves the selected oval to the center of the canvas |

All four act on the most recently clicked oval, which defaults to the blue one
at launch. The selected oval is outlined in the accent colour.

The keys are unmodified rather than ⌘-prefixed — these act on the selected shape
while your hands are already on the canvas, and there is no text entry anywhere in
the app for a bare letter to collide with. Rotating 90° is <kbd>]</kbd> six times
rather than six clicks. Each button's tooltip names its key, since a bare
`.keyboardShortcut` on a button is otherwise invisible.

### Menu

| Shortcut | Menu item | Result |
|----------|-----------|--------|
| **⌘D** | Debug → Show Debug Info | Toggles the debug overlay: strokes each shape's rotated bounding box and dots its center |

---

## Things to Try

Rotate an oval well off-axis with **Rotate Right**, then turn on **⌘D** to see
its bounding box. Now try to grab the oval just inside a corner of that box but
outside the ellipse itself — it won't pick up, because hit testing follows the
rotated shape rather than the box.

Fling one oval hard and, while it is still coasting, grab and fling the other.
Both animate independently off the same timer.

---

## Development

All commands run from the repo root. There is a single scheme, `graphics1`.

```sh
# Build
xcodebuild -project graphics1.xcodeproj -scheme graphics1 -destination 'platform=macOS' build

# Run all tests
xcodebuild -project graphics1.xcodeproj -scheme graphics1 -destination 'platform=macOS' test

# Run a single test target
xcodebuild -project graphics1.xcodeproj -scheme graphics1 -destination 'platform=macOS' test -only-testing:graphics1Tests
```

The test targets are `graphics1Tests` (Swift Testing) and `graphics1UITests`
(XCTest/XCUITest). `graphics1Tests` covers `Inertia.decay(dt:)` and `Item`'s
geometry helpers. The UI tests cover launch, the button bar, that a button
click redraws the canvas, and that dragging an oval moves it — the paths no
unit test can reach, since they live on the view.

Source lives in `graphics1/`, across two files: `graphics1App.swift` (entry
point, window, debug menu) and `ContentView.swift` (the shape model, drawing,
gestures, and physics).

Commits follow [Conventional Commits](https://www.conventionalcommits.org/)
with a short lowercase subject.

---

## Architecture

See [`docs/design.md`](docs/design.md) for the full write-up: how a drag flows
through picking, live preview, and commit-and-coast; why everything is drawn
into one `Canvas` and what that costs; and the reasoning behind the drawing
model. [`CLAUDE.md`](CLAUDE.md) covers the same ground more tersely, oriented
toward making changes.

---

## Known Limitations

- **The canvas cannot pan or zoom.** Dragging the background does nothing, and
  a hard enough throw sends a shape somewhere only the **Center** button can
  retrieve it — nothing constrains shapes to the visible area.
  ([#2](https://github.com/PeteRichardson/graphics1/issues/2))
- **Shapes are tracked by array index**, which will break as soon as the app
  can add, remove, or reorder them. Latent today, since it cannot.
  ([#1](https://github.com/PeteRichardson/graphics1/issues/1))
- **Momentum is not synchronised to the display.** The simulation runs on a
  `Timer` rather than a `CADisplayLink`, so its ticks are not aligned to vsync
  and motion can judder on a high-refresh display. Speed is unaffected — the
  step integrates against measured elapsed time.
- **Ellipses only.** The shape model hardcodes `Path(ellipseIn:)`.
- **The scene is hardcoded.** Two ovals, fixed positions, no way to add or
  delete shapes and no persistence between launches.
- **Thin test coverage.** `Inertia.decay(dt:)` and `Item`'s geometry helpers
  are unit tested. The simulation loop and gesture handling can't be, because
  they live on the view — the UI tests reach them by driving the app and
  comparing screenshots, which proves the canvas *changed* but not what it
  drew. Asserting on the shapes themselves needs them to have an accessibility
  representation first ([#15](https://github.com/PeteRichardson/graphics1/issues/15)).

---

## Contributing

This is a personal practice repo, so there is no contribution process to speak
of — but issues and observations are welcome. Before starting anything
substantial, open an issue.

```sh
git clone https://github.com/PeteRichardson/graphics1.git
cd graphics1
xcodebuild -project graphics1.xcodeproj -scheme graphics1 -destination 'platform=macOS' test
```

---

## License

<!-- 🖊 TODO: This repo is public but has no LICENSE file, which means default
     copyright applies — nobody may legally reuse the code. If that is not what
     you want, add a license (MIT is the usual choice for a practice repo) and
     replace this section with:

Licensed under the **MIT License** — see [LICENSE](LICENSE) for details.
-->

No license file is present, so all rights are reserved by default.
