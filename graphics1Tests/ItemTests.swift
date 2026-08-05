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
}
