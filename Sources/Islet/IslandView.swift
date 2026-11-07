import SwiftUI

struct IslandView: View {
    @EnvironmentObject var m: IslandModel
    @EnvironmentObject var sys: SystemState
    @EnvironmentObject var sp: SpotifyController
    @EnvironmentObject var ex: ExtrasState
    @State private var hoverTask: DispatchWorkItem?

    var active: Bool { sys.mic || sys.camera || sys.recording || sys.caps || sp.playing || ex.hud != nil || ex.timerRunning }
    var width: CGFloat { m.expanded ? 480 : m.notchW + (active ? 170 : 0) }
    var height: CGFloat { m.expanded ? 215 : m.notchH }

    var body: some View {
        ZStack(alignment: .top) {
            UnevenRoundedRectangle(bottomLeadingRadius: m.expanded ? 30 : 12, bottomTrailingRadius: m.expanded ? 30 : 12)
                .fill(.black)
            if m.expanded { ExpandedView() } else { CompactView() }
        }
        .frame(width: width, height: height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: m.expanded)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: active)
        .onHover { h in
            hoverTask?.cancel()
            let t = DispatchWorkItem { withAnimation { m.expanded = h } }
            hoverTask = t
            DispatchQueue.main.asyncAfter(deadline: .now() + (h ? 0.12 : 0.35), execute: t)
        }
    }
}

struct Indicators: View {
    @EnvironmentObject var sys: SystemState
    var body: some View {
        HStack(spacing: 8) {
            if sys.recording { Dot(icon: "record.circle.fill", color: .red) }
            if sys.camera { Dot(icon: "video.fill", color: .green) }
            if sys.mic { Dot(icon: "mic.fill", color: .orange) }
        }
    }
}

struct Dot: View {
    let icon: String, color: Color
    @State private var pulse = false
    var body: some View {
        Image(systemName: icon).font(.system(size: 12, weight: .bold)).foregroundStyle(color)
            .shadow(color: color.opacity(0.8), radius: pulse ? 6 : 1)
            .onAppear { withAnimation(.easeInOut(duration: 1).repeatForever()) { pulse = true } }
            .transition(.scale.combined(with: .opacity))
    }
}

struct EqBars: View {
    @State private var go = false
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { i in
                Capsule().fill(.green).frame(width: 2.5, height: go ? CGFloat([10, 14, 8, 12][i]) : 4)
                    .animation(.easeInOut(duration: 0.45).repeatForever().delay(Double(i) * 0.1), value: go)
            }
        }.frame(height: 14).onAppear { go = true }
    }
}

struct CompactView: View {
    @EnvironmentObject var m: IslandModel
    @EnvironmentObject var sys: SystemState
    @EnvironmentObject var sp: SpotifyController
    @EnvironmentObject var ex: ExtrasState
    var body: some View {
        HStack(spacing: 0) {
            if let h = ex.hud {
                Image(systemName: h.icon).font(.system(size: 13, weight: .bold)).foregroundStyle(h.color).padding(.leading, 14)
                Spacer(minLength: m.notchW)
                Group {
                    if let v = h.value { Text("\(Int(v * 100))").font(.system(size: 12, weight: .bold, design: .rounded)) }
                    else { Text(h.text).font(.system(size: 11, weight: .semibold)).lineLimit(1) }
                }.foregroundStyle(.white).frame(maxWidth: 80).padding(.trailing, 14)
            } else {
                Indicators().padding(.leading, 14)
                Spacer(minLength: m.notchW)
                HStack(spacing: 8) {
                    if ex.timerRunning { Text(String(format: "%d:%02d", ex.timerLeft / 60, ex.timerLeft % 60)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(.orange) }
                    if sys.caps { Image(systemName: "capslock.fill").font(.system(size: 12, weight: .bold)).foregroundStyle(.white).transition(.scale) }
                    if sp.playing { EqBars() }
                }.padding(.trailing, 14)
            }
        }.frame(height: m.notchH)
    }
}

struct ExpandedView: View {
    @EnvironmentObject var m: IslandModel
    @EnvironmentObject var sys: SystemState
    @EnvironmentObject var ex: ExtrasState
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Indicators()
                if sys.caps { Label("CAPS", systemImage: "capslock.fill").font(.system(size: 10, weight: .bold)).padding(.horizontal, 6).padding(.vertical, 2).background(.white.opacity(0.2), in: Capsule()) }
                Spacer(minLength: m.notchW)
                HStack(spacing: 8) {
                    Label("\(ex.battery)%", systemImage: ex.plugged ? "battery.100.bolt" : "battery.75").font(.system(size: 11, weight: .semibold)).foregroundStyle(ex.plugged ? .green : .white.opacity(0.7))
                    Text(Date(), style: .time).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                }
            }.frame(height: m.notchH).padding(.horizontal, 24).foregroundStyle(.white)

            Group { if m.tab == 0 { MusicView() } else if m.tab == 1 { AgendaView() } else { FocusView() } }
                .transition(.opacity)
            HStack(spacing: 18) {
                tabButton("music.note", 0); tabButton("calendar", 1); tabButton("timer", 2)
            }.padding(.bottom, 8)
        }
    }
    func tabButton(_ icon: String, _ i: Int) -> some View {
        Button { withAnimation { m.tab = i } } label: {
            Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(m.tab == i ? .white : .white.opacity(0.35))
                .padding(.horizontal, 14).padding(.vertical, 4)
                .background(m.tab == i ? .white.opacity(0.15) : .clear, in: Capsule())
        }.buttonStyle(.plain)
    }
}

struct MusicView: View {
    @EnvironmentObject var sp: SpotifyController
    var body: some View {
        if !sp.running {
            VStack(spacing: 8) {
                Image(systemName: "music.note.house").font(.largeTitle).foregroundStyle(.white.opacity(0.4))
                Button("Open Spotify") { sp.open() }.buttonStyle(.borderedProminent).tint(.green)
            }.frame(maxHeight: .infinity)
        } else {
            HStack(spacing: 14) {
                Group {
                    if let a = sp.art { Image(nsImage: a).resizable().scaledToFill() }
                    else { Color.white.opacity(0.1) }
                }.frame(width: 96, height: 96).clipShape(RoundedRectangle(cornerRadius: 14))
                 .shadow(color: .green.opacity(sp.playing ? 0.4 : 0), radius: 12)
                VStack(alignment: .leading, spacing: 4) {
                    Text(sp.title).font(.system(size: 15, weight: .bold)).lineLimit(1)
                    Text(sp.artist).font(.system(size: 12)).foregroundStyle(.white.opacity(0.6)).lineLimit(1)
                    Slider(value: Binding(get: { sp.position / sp.duration }, set: { sp.seek($0) })).tint(.green).controlSize(.mini)
                    HStack(spacing: 26) {
                        Spacer()
                        btn("backward.fill", 16) { sp.prev() }
                        btn(sp.playing ? "pause.circle.fill" : "play.circle.fill", 34) { sp.toggle() }
                        btn("forward.fill", 16) { sp.next() }
                        Spacer()
                    }
                }.foregroundStyle(.white)
            }.padding(.horizontal, 28)
        }
    }
    func btn(_ i: String, _ s: CGFloat, _ a: @escaping () -> Void) -> some View {
        Button(action: a) { Image(systemName: i).font(.system(size: s)) }.buttonStyle(.plain)
    }
}

struct AgendaView: View {
    @EnvironmentObject var cal: CalendarModel
    var days: [Date] {
        let c = Calendar.current
        let start = c.date(byAdding: .day, value: -1, to: c.startOfDay(for: Date()))!
        return (0..<7).map { c.date(byAdding: .day, value: $0, to: start)! }
    }
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(days, id: \.self) { d in
                    let sel = Calendar.current.isDate(d, inSameDayAs: cal.date)
                    Button { cal.date = d } label: {
                        VStack(spacing: 1) {
                            Text(d.formatted(.dateTime.weekday(.narrow))).font(.system(size: 9)).opacity(0.6)
                            Text(d.formatted(.dateTime.day())).font(.system(size: 13, weight: .bold, design: .rounded))
                        }.frame(width: 34, height: 36)
                         .background(sel ? Color.accentColor : .white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    }.buttonStyle(.plain)
                }
            }
            ScrollView(showsIndicators: false) {
                VStack(spacing: 5) {
                    if cal.entries.isEmpty { Text("Nothing planned 🎉").font(.system(size: 12)).opacity(0.5).padding(.top, 14) }
                    ForEach(cal.entries) { e in
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2).fill(e.color).frame(width: 3, height: 22)
                            Text(e.title).font(.system(size: 12, weight: .medium)).lineLimit(1).strikethrough(e.done)
                            Spacer()
                            Text(e.time).font(.system(size: 11)).opacity(0.5)
                            if e.isReminder {
                                Button { cal.toggle(e) } label: { Image(systemName: e.done ? "checkmark.circle.fill" : "circle") }.buttonStyle(.plain)
                            }
                        }.opacity(e.done ? 0.4 : 1)
                    }
                }
            }
        }.foregroundStyle(.white).padding(.horizontal, 28)
    }
}

struct FocusView: View {
    @EnvironmentObject var ex: ExtrasState
    var body: some View {
        HStack(spacing: 26) {
            ZStack {
                Circle().stroke(.white.opacity(0.12), lineWidth: 7)
                Circle().trim(from: 0, to: CGFloat(ex.timerLeft) / CGFloat(max(ex.timerTotal, 1)))
                    .stroke(.orange, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: ex.timerLeft)
                Text(String(format: "%d:%02d", ex.timerLeft / 60, ex.timerLeft % 60)).font(.system(size: 20, weight: .bold, design: .monospaced))
            }.frame(width: 100, height: 100)
            VStack(alignment: .leading, spacing: 10) {
                Text("Focus").font(.system(size: 15, weight: .bold))
                HStack { ForEach([15, 25, 45], id: \.self) { mnt in
                    Button("\(mnt)m") { ex.setMinutes(mnt) }.buttonStyle(.plain).font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 9).padding(.vertical, 4).background(ex.timerTotal == mnt * 60 ? Color.orange : .white.opacity(0.12), in: Capsule())
                } }
                HStack(spacing: 12) {
                    Button(ex.timerRunning ? "Pause" : "Start") { ex.startPause() }.buttonStyle(.borderedProminent).tint(.orange)
                    Button("Reset") { ex.reset() }.buttonStyle(.bordered)
                }.controlSize(.small)
            }
        }.foregroundStyle(.white).padding(.horizontal, 28)
    }
}
