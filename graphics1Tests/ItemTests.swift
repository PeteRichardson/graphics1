//
//  ItemTests.swift
//  graphics1Tests
//
//  Covers Item's pure geometry helpers.
//

import Foundation
@testable import graphics1
import SwiftUI
import Testing

struct ItemTests {
    /// The debug centre dot must be centred on the point it is given — an
    /// easy thing to get wrong when the rect is built from corner offsets.
    @Test func dotIsCentredOnItsPoint() {
        let point = CGPoint(x: 100, y: 50)
        let box = Item.dot(at: point, radius: 3).boundingRect
        #expect(abs(box.midX - point.x) < 1e-9)
        #expect(abs(box.midY - point.y) < 1e-9)
    }

    /// Radius, not diameter — the rect is 2r on a side.
    @Test func dotDiameterIsTwiceItsRadius() {
        let box = Item.dot(at: .zero, radius: 4).boundingRect
        #expect(abs(box.width - 8) < 1e-9)
        #expect(abs(box.height - 8) < 1e-9)
    }

    /// A zero radius should collapse to the point rather than misbehave.
    @Test func zeroRadiusCollapsesToThePoint() {
        let point = CGPoint(x: -7, y: 12)
        let box = Item.dot(at: point, radius: 0).boundingRect
        #expect(box.width == 0)
        #expect(box.height == 0)
        #expect(abs(box.midX - point.x) < 1e-9)
        #expect(abs(box.midY - point.y) < 1e-9)
    }

    // MARK: - Geometry

    /// The item every hit-test case below is built from.
    ///
    /// Default size, so the bounding box is (100, 100, 200, 100): centred on
    /// (200, 150) with semi-axes of 100 across and 50 down. Every point in
    /// these tests is chosen against those numbers.
    private static func item(rotatedBy angle: Angle) -> Item {
        Item(position: CGPoint(x: 100, y: 100), rotation: angle)
    }

    private static let centre = CGPoint(x: 200, y: 150)

    @Test func boundingBoxIsOriginPlusSize() {
        let box = Self.item(rotatedBy: .zero).boundingBox
        #expect(box == CGRect(x: 100, y: 100, width: 200, height: 100))
    }

    @Test func centreIsTheMiddleOfTheBoundingBox() {
        #expect(Self.item(rotatedBy: .zero).center == Self.centre)
    }

    /// Rotation is about the item's own centre, so the centre is a fixed
    /// point of the transform at any angle.
    @Test func transformLeavesTheCentreWhereItIs() {
        for degrees in [0.0, 30, 45, 90, 180, -45] {
            let moved = Self.centre.applying(Self.item(rotatedBy: .degrees(degrees)).transform)
            #expect(abs(moved.x - Self.centre.x) < 1e-9)
            #expect(abs(moved.y - Self.centre.y) < 1e-9)
        }
    }

    @Test func centreIsInsideAtEveryRotation() {
        for degrees in [0.0, 45, 90, 180] {
            #expect(Self.item(rotatedBy: .degrees(degrees)).contains(Self.centre))
        }
    }

    @Test func aDistantPointIsOutsideAtEveryRotation() {
        let far = CGPoint(x: 400, y: 150) // 200pt from centre; the long semi-axis is 100
        for degrees in [0.0, 45, 90, 180] {
            #expect(!Self.item(rotatedBy: .degrees(degrees)).contains(far))
        }
    }

    /// The case that distinguishes a real hit test from `boundingBox.contains`.
    ///
    /// (295, 195) sits inside the bounding box — 5pt in from its bottom-right
    /// corner — but (95/100)² + (45/50)² = 1.71 > 1, so it is outside the
    /// ellipse. A naive box test would call this a hit.
    @Test func aBoundingBoxCornerIsNotInsideTheEllipse() {
        let item = Self.item(rotatedBy: .zero)
        let corner = CGPoint(x: 295, y: 195)

        #expect(item.boundingBox.contains(corner)) // inside the box...
        #expect(!item.contains(corner)) // ...but not the shape
    }

    /// The strongest evidence that `transform` is actually applied: at 90° the
    /// long and short axes swap, so these two points swap membership.
    ///
    /// (200, 240) is 90pt below the centre — outside the 50pt vertical
    /// semi-axis unrotated, inside the 100pt one when the ellipse is turned on
    /// its side. (290, 150) is 90pt to the right and does the reverse.
    ///
    /// Both hold whichever direction the rotation is applied in, since ±90°
    /// puts the long axis on the y-axis either way.
    @Test func rotatingNinetyDegreesSwapsWhichPointsAreInside() {
        let upright = Self.item(rotatedBy: .zero)
        let onItsSide = Self.item(rotatedBy: .degrees(90))

        let below = CGPoint(x: 200, y: 240)
        let beside = CGPoint(x: 290, y: 150)

        #expect(!upright.contains(below))
        #expect(onItsSide.contains(below))

        #expect(upright.contains(beside))
        #expect(!onItsSide.contains(beside))
    }

    /// At 45° the long axis lies along one diagonal. Both diagonal points are
    /// outside when upright — (63.6/100)² + (63.6/50)² = 2.02 — and exactly
    /// one is inside once tilted.
    ///
    /// Asserting "exactly one" rather than naming which keeps this independent
    /// of the rotation's sign convention, which SwiftUI's flipped y-axis makes
    /// easy to get backwards.
    @Test func rotatingFortyFiveDegreesTiltsTheEllipseOntoADiagonal() {
        let offset = 90 / 2.0.squareRoot() // 90pt along a diagonal
        let downRight = CGPoint(x: Self.centre.x + offset, y: Self.centre.y + offset)
        let upRight = CGPoint(x: Self.centre.x + offset, y: Self.centre.y - offset)

        let upright = Self.item(rotatedBy: .zero)
        #expect(!upright.contains(downRight))
        #expect(!upright.contains(upRight))

        let tilted = Self.item(rotatedBy: .degrees(45))
        #expect(tilted.contains(downRight) != tilted.contains(upRight))
    }

    /// `position` is the bounding box's origin, so moving the item moves the
    /// hit region with it rather than leaving it behind.
    @Test func movingTheItemMovesItsHitRegion() {
        let moved = Item(position: CGPoint(x: 500, y: 500))
        #expect(!moved.contains(Self.centre))
        #expect(moved.contains(CGPoint(x: 600, y: 550))) // its own centre
    }

    // MARK: - Agreement with the drawn shape

    /// How far `point` sits from the item's centre, as a multiple of the
    /// ellipse's own radius in that direction: < 1 inside, 1 on the edge.
    ///
    /// Deliberately derived a *different* way from `Item.contains` — this asks
    /// `CGAffineTransform` for the inverse rather than hand-rolling one — so it
    /// is an independent opinion rather than a restatement of the code
    /// under test.
    private static func normalisedRadius(of point: CGPoint, in item: Item) -> CGFloat {
        let local = point.applying(item.transform.inverted())
        let dx = (local.x - item.center.x) / (item.width / 2)
        let dy = (local.y - item.center.y) / (item.height / 2)
        return (dx * dx + dy * dy).squareRoot()
    }

    /// `contains` must agree with the path the item actually draws.
    ///
    /// This is the load-bearing test for the arithmetic hit test. `contains`
    /// used to be `path.applying(transform).contains(point)` — literally the
    /// shape `draw(in:debug:selected:)` renders, sharing one `transform`, so
    /// the two could not disagree. Deriving the inverse rotation by hand
    /// reintroduces that possibility: flip a sign and hit testing becomes a
    /// mirror image of what is on screen.
    ///
    /// None of the other rotation tests catch that. They assert sign-agnostic
    /// properties on purpose (±90° both put the long axis on the y-axis; the
    /// 45° case asserts only that *one* diagonal is inside), so a sign flip
    /// passes every one of them. Verified by mutation: inverting the sign
    /// convention leaves the rest of this suite green and fails only here.
    ///
    /// Points within `boundaryBand` of the edge are skipped. Both definitions
    /// are correct there and may still disagree a fraction of a unit from the
    /// curve, which would make this flaky rather than informative.
    @Test func containsAgreesWithTheShapeItDraws() {
        let boundaryBand: CGFloat = 0.02
        var compared = 0

        // Offset off the whole-number grid so no sample lands exactly on the
        // curve at the axis-aligned rotations, where they otherwise would.
        for degrees in stride(from: 0.0, to: 360.0, by: 15.0) {
            let item = Self.item(rotatedBy: .degrees(degrees))
            let drawn = item.path.applying(item.transform)

            for x in stride(from: 60.3, through: 340.0, by: 7.0) {
                for y in stride(from: 10.7, through: 290.0, by: 7.0) {
                    let point = CGPoint(x: x, y: y)
                    guard abs(Self.normalisedRadius(of: point, in: item) - 1) > boundaryBand
                    else { continue }

                    compared += 1
                    #expect(
                        item.contains(point) == drawn.contains(point),
                        "hit test disagreed with the drawn path at \(point), rotation \(degrees)°"
                    )
                }
            }
        }

        // Guards against the grid silently collapsing to nothing and the test
        // passing vacuously.
        #expect(compared > 10000)
    }

    /// A degenerate item encloses nothing, rather than dividing by zero and
    /// letting a NaN decide the answer.
    @Test func aZeroSizedItemContainsNothing() {
        let flat = Item(position: CGPoint(x: 100, y: 100), height: 0, width: 200)
        #expect(!flat.contains(CGPoint(x: 200, y: 100)))

        let empty = Item(position: CGPoint(x: 100, y: 100), height: 0, width: 0)
        #expect(!empty.contains(CGPoint(x: 100, y: 100)))
    }
}
