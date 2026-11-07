import SwiftUI
import AppKit
import IOKit.ps
import IOBluetooth
import AudioToolbox
import CoreAudio

struct HUD: Equatable { var icon: String; var text: String; var value: Double?; var color: Color }

/// Battery, volume/brightness HUD, Bluetooth connect alerts, focus timer.
final class ExtrasState: ObservableObject {
    @Published var battery = 100
    @Published var charging = false
    @Published var plugged = false
    @Published var hud: HUD?
    @Published var timerTotal = 25 * 60
    @Published var timerLeft = 25 * 60
    @Published var timerRunning = false
    private var lastVol: Float = -1, lastBri: Float = -1, lastPlug: Bool?, btSeen: Set<String>?
    private var hudTask: DispatchWorkItem?

    init() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.pollLevels() }
        Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.slowPoll() }
        slowPoll()
    }

    func show(_ h: HUD, for s: Double = 2) {
        hud = h; hudTask?.cancel()
        let t = DispatchWorkItem { [weak self] in self?.hud = nil }
        hudTask = t; DispatchQueue.main.asyncAfter(deadline: .now() + s, execute: t)
    }

    // MARK: volume + brightness
    private func pollLevels() {
        let (v, muted) = Self.volume()
        if v >= 0 {
            if lastVol >= 0, abs(v - lastVol) > 0.001 { show(HUD(icon: muted || v == 0 ? "speaker.slash.fill" : v < 0.4 ? "speaker.wave.1.fill" : "speaker.wave.3.fill", text: "Volume", value: Double(v), color: .white), for: 1.5) }
            lastVol = v
        }
        if let b = Self.brightness() {
            if lastBri >= 0, abs(b - lastBri) > 0.001 { show(HUD(icon: "sun.max.fill", text: "Brightness", value: Double(b), color: .yellow), for: 1.5) }
            lastBri = b
        }
    }

    static func volume() -> (Float, Bool) {
        var dev = AudioObjectID(0), size = UInt32(4)
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &dev) == noErr else { return (-1, false) }
        var vol: Float32 = 0; size = 4
        a = AudioObjectPropertyAddress(mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume, mScope: kAudioDevicePropertyScopeOutput, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &vol) == noErr else { return (-1, false) }
        var mute: UInt32 = 0; size = 4
        a.mSelector = kAudioDevicePropertyMute
        AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &mute)
        return (vol, mute != 0)
    }

    private typealias BriFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private static let briFn: BriFn? = {
        guard let h = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
              let s = dlsym(h, "DisplayServicesGetBrightness") else { return nil }
        return unsafeBitCast(s, to: BriFn.self)
    }()
    static func brightness() -> Float? {
        var b: Float = 0
        guard let f = briFn, f(CGMainDisplayID(), &b) == 0 else { return nil }
        return b
    }

    // MARK: battery, bluetooth, timer
    private func slowPoll() {
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for ps in list {
                guard let d = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] else { continue }
                battery = d[kIOPSCurrentCapacityKey] as? Int ?? battery
                charging = d[kIOPSIsChargingKey] as? Bool ?? false
                plugged = (d[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue
            }
            if let lp = lastPlug, lp != plugged {
                show(HUD(icon: plugged ? "bolt.fill" : "battery.50percent", text: "\(battery)%", value: nil, color: plugged ? .green : .white), for: 2.5)
            }
            lastPlug = plugged
        }
        let names = Set((IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []).filter { $0.isConnected() }.compactMap { $0.name })
        if let seen = btSeen, let new = names.subtracting(seen).first {
            let low = new.lowercased()
            show(HUD(icon: low.contains("airpods") ? "airpodspro" : low.contains("mouse") ? "computermouse.fill" : low.contains("keyboard") ? "keyboard.fill" : "headphones", text: new, value: nil, color: .blue), for: 3)
        }
        btSeen = names

        if timerRunning {
            timerLeft -= 1
            if timerLeft <= 0 {
                timerRunning = false; timerLeft = timerTotal
                NSSound(named: "Glass")?.play()
                show(HUD(icon: "checkmark.circle.fill", text: "Focus done", value: nil, color: .green), for: 4)
            }
        }
    }

    func setMinutes(_ m: Int) { timerRunning = false; timerTotal = m * 60; timerLeft = m * 60 }
    func startPause() { timerRunning.toggle() }
    func reset() { timerRunning = false; timerLeft = timerTotal }
}
