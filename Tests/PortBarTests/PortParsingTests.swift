import Testing

@testable import PortBar

struct PortParsingTests {
    @Test func parsesIPv4Line() {
        let line = Substring("node      4620 amir   17u  IPv4 0xabc      0t0  TCP 127.0.0.1:8080 (LISTEN)")
        let parsed = PortScanner.parseLsofLine(line)
        #expect(parsed?.pid == 4620)
        #expect(parsed?.command == "node")
        #expect(parsed?.port == 8080)
    }

    @Test func parsesWildcardLine() {
        let line = Substring("Python    2444 amir   17u  IPv6 0xdef      0t0  TCP *:3000 (LISTEN)")
        #expect(PortScanner.parseLsofLine(line)?.port == 3000)
        #expect(PortScanner.parseLsofLine(line)?.command == "Python")
    }

    @Test func parsesIPv6BracketLine() {
        let line = Substring("ollama    5796 amir   3u   IPv6 0x123      0t0  TCP [::1]:11434 (LISTEN)")
        #expect(PortScanner.parseLsofLine(line)?.port == 11434)
    }

    @Test func rejectsMalformedLines() {
        #expect(PortScanner.parseLsofLine(Substring("")) == nil)
        #expect(PortScanner.parseLsofLine(Substring("not enough fields here")) == nil)
        // header row has a non-numeric PID column
        #expect(
            PortScanner.parseLsofLine(Substring("COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME")) == nil)
    }
}
