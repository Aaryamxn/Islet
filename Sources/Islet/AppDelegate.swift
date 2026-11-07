import AppKit
import SwiftUI
import Combine
import ServiceManagement

final class IslandModel: ObservableObject {
    @Published var expanded = false
    @Published var tab = 0
    var notchW: CGFloat = 190, notchH: CGFloat = 32
}

final class IslandPanel: NSPanel { override var canBecomeKey: Bool { true } }

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = IslandModel(), system = SystemState(), spotify = SpotifyController(), cal = CalendarModel(), ex = ExtrasState()
    var panel: IslandPanel!, bag = Set<AnyCancellable>(), status: NSStatusItem!

    func applicationDidFinishLaunching(_ n: Notification) {
        panel = IslandPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.level = .mainMenu + 3
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        let root = IslandView().environmentObject(model).environmentObject(system).environmentObject(spotify).environmentObject(cal).environmentObject(ex)
        panel.contentView = NSHostingView(rootView: root)
        layout(); panel.orderFrontRegardless()

        Publishers.MergeMany(model.objectWillChange.map { _ in () }, system.objectWillChange.map { _ in () }, ex.objectWillChange.map { _ in () }, spotify.objectWillChange.map { _ in () })
            .sink { [weak self] in DispatchQueue.main.async { self?.layout() } }.store(in: &bag)
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in self?.layout() }

        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        status.button?.image = NSImage(systemSymbolName: "capsule.fill", accessibilityDescription: "Islet")
        let m = NSMenu()
        m.addItem(withTitle: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "").target = self
        m.addItem(.separator())
        m.addItem(withTitle: "Quit Islet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        status.menu = m
    }

    @objc func toggleLogin(_ s: NSMenuItem) {
        let svc = SMAppService.mainApp
        if svc.status == .enabled { try? svc.unregister(); s.state = .off } else { try? svc.register(); s.state = .on }
    }

    var hasActivity: Bool { system.mic || system.camera || system.recording || system.caps || spotify.playing || ex.hud != nil || ex.timerRunning }

    func layout() {
        guard let s = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return }
        if s.safeAreaInsets.top > 0, let l = s.auxiliaryTopLeftArea, let r = s.auxiliaryTopRightArea {
            model.notchW = s.frame.width - l.width - r.width; model.notchH = s.safeAreaInsets.top
        } else { model.notchW = 170; model.notchH = 30 }
        let w: CGFloat = model.expanded ? 500 : model.notchW + (hasActivity ? 190 : 20)
        let h: CGFloat = model.expanded ? 230 : model.notchH + 4
        let f = NSRect(x: s.frame.midX - w / 2, y: s.frame.maxY - h, width: w, height: h)
        if model.expanded { apply(f) }
        else { DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in if self?.model.expanded == false { self?.apply(f) } } }
    }
    func apply(_ f: NSRect) { if panel.frame != f { panel.setFrame(f, display: true) } }
}
