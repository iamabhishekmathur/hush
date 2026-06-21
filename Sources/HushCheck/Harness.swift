import Foundation

/// Tiny Foundation-only assertion harness so the self-test runs without Xcode
/// or XCTest (Command Line Tools only). Each `check*` records a pass/fail.
final class Harness {
    private(set) var checks = 0
    private(set) var failures = 0
    private var suiteName = ""

    func suite(_ name: String, _ body: () -> Void) {
        suiteName = name
        print("• \(name)")
        body()
    }

    func check(_ cond: Bool, _ msg: String, line: UInt = #line) {
        checks += 1
        if cond {
            print("    ✓ \(msg)")
        } else {
            failures += 1
            print("    ✗ \(msg)   [\(suiteName):\(line)]")
        }
    }

    func equal<T: Equatable>(_ a: T, _ b: T, _ msg: String, line: UInt = #line) {
        check(a == b, "\(msg) (got \(a), want \(b))", line: line)
    }

    func ge<T: Comparable>(_ a: T, _ b: T, _ msg: String, line: UInt = #line) {
        check(a >= b, "\(msg) (\(a) ≥ \(b))", line: line)
    }

    func le<T: Comparable>(_ a: T, _ b: T, _ msg: String, line: UInt = #line) {
        check(a <= b, "\(msg) (\(a) ≤ \(b))", line: line)
    }

    func gt<T: Comparable>(_ a: T, _ b: T, _ msg: String, line: UInt = #line) {
        check(a > b, "\(msg) (\(a) > \(b))", line: line)
    }

    func approx(_ a: Double, _ b: Double, _ tol: Double, _ msg: String, line: UInt = #line) {
        check(abs(a - b) <= tol, "\(msg) (\(a) ≈ \(b))", line: line)
    }

    func summarize() -> Int {
        print("")
        if failures == 0 {
            print("PASS — \(checks) checks")
            return 0
        }
        print("FAIL — \(failures)/\(checks) checks failed")
        return 1
    }
}
