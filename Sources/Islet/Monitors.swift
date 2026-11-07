import AppKit
import CoreAudio
import CoreMediaIO
import Combine

/// Mic, camera, screen-recording and caps-lock state.
final class SystemState: ObservableObject {
    @Published var mic = false
    @Published var camera = false
    @Published var recording = false
    @Published var caps = false
    private var fast: Timer?, slow: Timer?

    init() {
        fast = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            let c = CGEventSource.flagsState(.combinedSessionState).contains(.maskAlphaShift)
            if self?.caps != c { self?.caps = c }
        }
        slow = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.poll() }
        poll()
    }

    private func poll() {
        let m = Self.micRunning(), c = Self.cameraRunning(), r = Self.screenRecording()
        if mic != m { mic = m }
        if camera != c { camera = c }
        if recording != r { recording = r }
    }

    static func micRunning() -> Bool {
        var dev = AudioObjectID(0), size = UInt32(MemoryLayout<AudioObjectID>.size)
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &dev) == noErr else { return false }
        var run: UInt32 = 0; size = 4
        a.mSelector = kAudioDevicePropertyDeviceIsRunningSomewhere
        AudioObjectGetPropertyData(dev, &a, 0, nil, &size, &run)
        return run != 0
    }

    static func cameraRunning() -> Bool {
        var a = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
        var size: UInt32 = 0
        let sys = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(sys, &a, 0, nil, &size) == 0 else { return false }
        var ids = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(sys, &a, 0, nil, size, &used, &ids) == 0 else { return false }
        for d in ids {
            var p = CMIOObjectPropertyAddress(mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain))
            var r: UInt32 = 0, u: UInt32 = 0
            if CMIOObjectGetPropertyData(d, &p, 0, nil, 4, &u, &r) == 0, r != 0 { return true }
        }
        return false
    }

    /// Best-effort: macOS has no public API, so we look for the system capture UI's stop control.
    static func screenRecording() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else { return false }
        return list.contains {
            let owner = ($0[kCGWindowOwnerName as String] as? String) ?? ""
            let name = ($0[kCGWindowName as String] as? String) ?? ""
            return owner == "screencaptureui" || (owner == "Control Center" && name.localizedCaseInsensitiveContains("record"))
        }
    }
}
