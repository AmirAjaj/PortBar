import Testing

@testable import PortBar

struct UpdateCheckerTests {
    @Test func detectsNewerVersions() {
        #expect(UpdateChecker.isNewer("0.2.0", than: "0.1.0"))
        #expect(UpdateChecker.isNewer("0.1.1", than: "0.1.0"))
        #expect(UpdateChecker.isNewer("1.0.0", than: "0.9.9"))
        #expect(UpdateChecker.isNewer("0.10.0", than: "0.9.0"))  // numeric, not lexicographic
    }

    @Test func ignoresSameOrOlderVersions() {
        #expect(!UpdateChecker.isNewer("0.1.0", than: "0.1.0"))
        #expect(!UpdateChecker.isNewer("0.1.0", than: "0.2.0"))
        #expect(!UpdateChecker.isNewer("0.9.0", than: "0.10.0"))
    }
}
