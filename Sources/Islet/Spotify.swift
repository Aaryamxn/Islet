import AppKit
import Combine

final class SpotifyController: ObservableObject {
    @Published var running = false
    @Published var playing = false
    @Published var title = ""
    @Published var artist = ""
    @Published var position = 0.0
    @Published var duration = 1.0
    @Published var art: NSImage?
    private var artURL = "", timer: Timer?
    private let q = DispatchQueue(label: "spotify")

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    private func script(_ s: String) -> String? {
        var err: NSDictionary?
        return NSAppleScript(source: s)?.executeAndReturnError(&err).stringValue
    }

    private func poll() {
        let up = !NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client").isEmpty
        guard up else { if running { running = false; playing = false }; return }
        q.async { [weak self] in
            let s = """
            tell application "Spotify"
              if player state is stopped then return ""
              return (name of current track) & "|" & (artist of current track) & "|" & (player state as string) & "|" & (player position as string) & "|" & ((duration of current track) as string) & "|" & (artwork url of current track)
            end tell
            """
            guard let out = self?.script(s), !out.isEmpty else { return }
            let p = out.components(separatedBy: "|")
            guard p.count >= 6 else { return }
            let num = { (x: String) in Double(x.replacingOccurrences(of: ",", with: ".")) ?? 0 }
            DispatchQueue.main.async {
                guard let self else { return }
                self.running = true
                self.title = p[0]; self.artist = p[1]; self.playing = p[2] == "playing"
                self.position = num(p[3]); self.duration = max(num(p[4]) / 1000, 1)
                if p[5] != self.artURL, let u = URL(string: p[5]) {
                    self.artURL = p[5]
                    URLSession.shared.dataTask(with: u) { d, _, _ in
                        if let d, let img = NSImage(data: d) { DispatchQueue.main.async { self.art = img } }
                    }.resume()
                }
            }
        }
    }

    func cmd(_ c: String) { q.async { [weak self] in _ = self?.script("tell application \"Spotify\" to \(c)"); DispatchQueue.main.async { self?.poll() } } }
    func toggle() { playing.toggle(); cmd("playpause") }
    func next() { cmd("next track") }
    func prev() { cmd("previous track") }
    func seek(_ f: Double) { position = f * duration; cmd("set player position to \(f * duration)") }
    func open() { NSWorkspace.shared.launchApplication("Spotify") }
}
