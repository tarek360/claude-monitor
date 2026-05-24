import SwiftUI

// MARK: - Model

final class UsageViewModel: ObservableObject {
    @Published var fiveHourPct: Double = 0
    @Published var fiveHourResets: Date = Date()
    @Published var sevenDayPct: Double = 0
    @Published var sevenDayResets: Date = Date()
    @Published var hasData = false

    func update(from data: Data) {
        struct Limit: Decodable { let usedPercentage: Double; let resetsAt: TimeInterval }
        struct Limits: Decodable { let fiveHour: Limit; let sevenDay: Limit }
        struct Payload: Decodable { let rateLimits: Limits }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let p = try? decoder.decode(Payload.self, from: data) else { return }

        DispatchQueue.main.async {
            self.fiveHourPct    = p.rateLimits.fiveHour.usedPercentage
            self.fiveHourResets = Date(timeIntervalSince1970: p.rateLimits.fiveHour.resetsAt)
            self.sevenDayPct    = p.rateLimits.sevenDay.usedPercentage
            self.sevenDayResets = Date(timeIntervalSince1970: p.rateLimits.sevenDay.resetsAt)
            self.hasData = true
        }
    }
}

// MARK: - Usage Card

private enum ResetStyle { case hourly, weekly }

private struct UsageCard: View {
    let label: String
    let percentage: Double
    let resetsAt: Date
    let resetStyle: ResetStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(percentage.rounded()))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiaryLabelColor))
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(geo.size.width * CGFloat(min(percentage / 100, 1)), 6))
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            Text(resetLabel)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.quaternaryLabelColor))
        .cornerRadius(12)
    }

    // green at 0% → orange → red at 80%+
    private var barColor: Color {
        let hue = 0.35 * max(0, 1 - percentage / 80)
        return Color(hue: hue, saturation: 0.85, brightness: 0.95)
    }

    private var resetLabel: String {
        let timeFmt = DateFormatter()
        timeFmt.dateFormat = "h:mma"   // e.g. "5:00PM"

        switch resetStyle {
        case .hourly:
            // "resets 5:00pm (2h 50m)"
            let timeStr = timeFmt.string(from: resetsAt).lowercased()
            let secs  = Int(max(resetsAt.timeIntervalSinceNow, 0))
            let hours = secs / 3600
            let mins  = (secs % 3600) / 60
            let rel   = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"
            return "resets \(timeStr) (\(rel))"

        case .weekly:
            // "Tue, 6:00am"
            let dayFmt = DateFormatter()
            dayFmt.dateFormat = "EEE"
            let day  = dayFmt.string(from: resetsAt)
            let time = timeFmt.string(from: resetsAt).lowercased()
            return "\(day), \(time)"
        }
    }
}

// MARK: - Menu Item Row

private struct MenuItemRow: View {
    let title: String
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .foregroundColor(Color(.labelColor))
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(isHovered ? Color(.selectedMenuItemColor).opacity(0.15) : Color.clear)
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Root View

struct PopoverView: View {
    @ObservedObject var model: UsageViewModel
    var onGitHub: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack(spacing: 8) {
                if let img = NSImage(named: "claudecode") {
                    Image(nsImage: img)
                        .resizable()
                        .frame(width: 48, height: 48)
                }
                Text("Usage")
                    .font(.system(size: 24))
                    .foregroundColor(Color(.labelColor))
            }
            .frame(maxWidth: .infinity, alignment: .center)

            // Cards
            if model.hasData {
                UsageCard(label: "Current", percentage: model.fiveHourPct, resetsAt: model.fiveHourResets, resetStyle: .hourly)
                UsageCard(label: "Weekly",  percentage: model.sevenDayPct,  resetsAt: model.sevenDayResets, resetStyle: .weekly)
            } else {
                Text("Waiting for data…")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 30)
            }

            Divider()

            // Controls
            VStack(spacing: 2) {
                MenuItemRow(title: "View on GitHub", action: onGitHub)
                MenuItemRow(title: "Quit",           action: onQuit)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
