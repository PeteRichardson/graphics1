//
//  InertiaTests.swift
//  graphics1Tests
//
//  Covers the time-stepping maths behind drag-release inertia.
//

import Foundation
@testable import graphics1
import Testing

struct InertiaTests {
    /// One reference tick must decay by exactly the tuned friction constant,
    /// so the time-based form preserves the original feel.
    @Test func decayOverOneReferenceTickEqualsFriction() {
        let dt = 1.0 / Inertia.referenceRate
        #expect(abs(Inertia.decay(dt: dt) - Inertia.friction) < 1e-9)
    }

    /// Two ticks' worth of elapsed time compounds, rather than decaying once.
    @Test func decayCompoundsOverMultipleTicks() {
        let dt = 1.0 / Inertia.referenceRate
        let expected = Inertia.friction * Inertia.friction
        #expect(abs(Inertia.decay(dt: dt * 2) - expected) < 1e-9)
    }

    /// A tick that arrives with no elapsed time must not slow the item.
    @Test func zeroElapsedTimeRetainsAllVelocity() {
        #expect(Inertia.decay(dt: 0) == 1)
    }

    /// The point of the whole change: a given span of real time produces the
    /// same total decay no matter how many ticks it was divided into. The
    /// previous fixed-timestep form failed this — it decayed per tick, so a
    /// stalled or throttled timer made items coast further than wall-clock
    /// time warranted.
    @Test func decayDependsOnElapsedTimeNotTickCount() {
        func totalDecayOverOneSecond(ticks: Int) -> CGFloat {
            let dt = 1.0 / Double(ticks)
            return (0 ..< ticks).reduce(CGFloat(1)) { acc, _ in acc * Inertia.decay(dt: dt) }
        }
        let at60 = totalDecayOverOneSecond(ticks: 60)
        let at120 = totalDecayOverOneSecond(ticks: 120)
        let at17 = totalDecayOverOneSecond(ticks: 17) // a badly stalled timer

        #expect(abs(at60 - at120) < 1e-6)
        #expect(abs(at60 - at17) < 1e-6)
    }

    /// Distance is velocity times elapsed time, integrated tick by tick.
    ///
    /// This is a first-order integrator over a decaying curve, so a coarser
    /// timestep overshoots and the answer is only exact in the limit — 60 and
    /// 120 ticks genuinely differ by ~2 points over one second. The property
    /// worth asserting is therefore convergence, not equality: halving the
    /// step should roughly halve the error against the analytic integral.
    @Test func distanceIntegrationConvergesAsTimestepShrinks() {
        let initialSpeed: CGFloat = 500 // pts/sec

        func distanceOverOneSecond(ticks: Int) -> CGFloat {
            let dt = 1.0 / Double(ticks)
            var velocity = initialSpeed
            var travelled: CGFloat = 0
            for _ in 0 ..< ticks {
                travelled += velocity * CGFloat(dt)
                velocity *= Inertia.decay(dt: dt)
            }
            return travelled
        }

        // Analytic: integral over [0,1] of v0 * friction^(referenceRate * t) dt
        let k = log(Double(Inertia.friction)) * Inertia.referenceRate
        let exact = CGFloat(Double(initialSpeed) * (exp(k) - 1) / k)

        let error60 = abs(distanceOverOneSecond(ticks: 60) - exact)
        let error120 = abs(distanceOverOneSecond(ticks: 120) - exact)
        let error240 = abs(distanceOverOneSecond(ticks: 240) - exact)

        #expect(error120 < error60)
        #expect(error240 < error120)
        #expect(error240 < 1.5) // converging on the analytic value, not drifting
    }
}
