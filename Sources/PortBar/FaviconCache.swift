import AppKit
import Foundation

/// Tiny in-memory favicon cache for repository remote hosts.
@MainActor
final class FaviconCache: ObservableObject {
    @Published private(set) var images: [String: NSImage] = [:]

    private var loadingHosts = Set<String>()
    private var failedHosts = Set<String>()

    func image(for host: String?) -> NSImage? {
        guard let host else { return nil }
        return images[host]
    }

    func load(host: String?) async {
        guard let host, images[host] == nil, !loadingHosts.contains(host), !failedHosts.contains(host) else {
            return
        }

        loadingHosts.insert(host)
        defer { loadingHosts.remove(host) }

        let urls = faviconURLs(for: host)
        guard !urls.isEmpty else {
            failedHosts.insert(host)
            return
        }

        for url in urls {
            if let image = await fetchImage(from: url) {
                image.size = NSSize(width: 18, height: 18)
                images[host] = image
                return
            }
        }

        failedHosts.insert(host)
    }

    private func fetchImage(from url: URL) async -> NSImage? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        request.cachePolicy = .returnCacheDataElseLoad

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<400).contains(http.statusCode) else {
                return nil
            }
            return NSImage(data: data)
        } catch {
            return nil
        }
    }

    private func faviconURLs(for host: String) -> [URL] {
        [
            "https://www.google.com/s2/favicons?sz=64&domain_url=https://\(host)",
            "https://\(host)/favicon.ico",
            "https://\(host)/apple-touch-icon.png",
        ]
        .compactMap(URL.init(string:))
    }
}
