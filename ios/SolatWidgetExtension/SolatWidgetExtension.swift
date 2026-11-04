import SwiftUI
import WidgetKit

private enum SolatWidgetConstants {
  static let appGroup = "group.live.iqfareez.waktusolatmalaysia"
  static let malaysiaTimeZone = TimeZone(identifier: "Asia/Kuala_Lumpur") ?? .current
}

private struct PrayerMonth: Decodable {
  let zone: String
  let year: Int
  let monthNumber: Int
  let prayers: [PrayerDay]

  enum CodingKeys: String, CodingKey {
    case zone
    case year
    case monthNumber = "month_number"
    case prayers
  }

  func isCurrentMonth(at date: Date) -> Bool {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = SolatWidgetConstants.malaysiaTimeZone
    let components = calendar.dateComponents([.year, .month], from: date)
    return components.year == year && components.month == monthNumber
  }

  func prayerEvents() -> [PrayerEvent] {
    prayers.flatMap { day in
      [
        PrayerEvent(name: .fajr, timestamp: day.fajr),
        PrayerEvent(name: .sunrise, timestamp: day.syuruk),
        PrayerEvent(name: .dhuhr, timestamp: day.dhuhr),
        PrayerEvent(name: .asr, timestamp: day.asr),
        PrayerEvent(name: .maghrib, timestamp: day.maghrib),
        PrayerEvent(name: .isha, timestamp: day.isha),
      ]
    }
    .filter { $0.date.timeIntervalSince1970 > 0 }
    .sorted { $0.date < $1.date }
  }
}

private struct PrayerDay: Decodable {
  let fajr: Int64
  let syuruk: Int64
  let dhuhr: Int64
  let asr: Int64
  let maghrib: Int64
  let isha: Int64
}

private enum PrayerName {
  case fajr
  case sunrise
  case dhuhr
  case asr
  case maghrib
  case isha

  func label(isMalay: Bool) -> String {
    switch (self, isMalay) {
    case (.fajr, true): return "Subuh"
    case (.sunrise, true): return "Syuruk"
    case (.dhuhr, true): return "Zohor"
    case (.asr, true): return "Asar"
    case (.maghrib, true): return "Maghrib"
    case (.isha, true): return "Isyak"
    case (.fajr, false): return "Fajr"
    case (.sunrise, false): return "Sunrise"
    case (.dhuhr, false): return "Dhuhr"
    case (.asr, false): return "Asr"
    case (.maghrib, false): return "Maghrib"
    case (.isha, false): return "Isha"
    }
  }
}

private struct PrayerEvent: Identifiable {
  let name: PrayerName
  let date: Date

  var id: String {
    "\(name)-\(date.timeIntervalSince1970)"
  }

  init(name: PrayerName, timestamp: Int64) {
    self.name = name
    self.date = Date(timeIntervalSince1970: TimeInterval(timestamp))
  }
}

private struct SolatWidgetEntry: TimelineEntry {
  let date: Date
  let prayerMonth: PrayerMonth?
  let location: String
  let language: String
  let uses24HourTime: Bool

  var isMalay: Bool {
    language == "ms"
  }

  var currentMonthIsAvailable: Bool {
    prayerMonth?.isCurrentMonth(at: date) == true
  }

  var upcomingPrayers: [PrayerEvent] {
    guard currentMonthIsAvailable, let prayerMonth else { return [] }
    return prayerMonth.prayerEvents().filter { $0.date > date }
  }
}

private struct SolatTimelineProvider: TimelineProvider {
  func placeholder(in context: Context) -> SolatWidgetEntry {
    SolatWidgetEntry(
      date: Date(),
      prayerMonth: nil,
      location: "",
      language: "en",
      uses24HourTime: false
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (SolatWidgetEntry) -> Void) {
    completion(readEntry(at: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<SolatWidgetEntry>) -> Void)
  {
    let now = Date()
    let currentEntry = readEntry(at: now)
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = SolatWidgetConstants.malaysiaTimeZone
    let nextMidnight =
      calendar.date(
        byAdding: .day,
        value: 1,
        to: calendar.startOfDay(for: now)
      ) ?? now.addingTimeInterval(24 * 60 * 60)

    guard let month = currentEntry.prayerMonth, month.isCurrentMonth(at: now) else {
      completion(
        Timeline(
          entries: [currentEntry],
          policy: .after(now.addingTimeInterval(6 * 60 * 60))
        )
      )
      return
    }

    let eventEntries = month.prayerEvents()
      .filter { $0.date > now && $0.date < nextMidnight }
      .map { event in readEntry(at: event.date) }
    let midnightEntry = readEntry(at: nextMidnight)
    completion(
      Timeline(
        entries: [currentEntry] + eventEntries + [midnightEntry],
        policy: .after(nextMidnight)
      )
    )
  }

  private func readEntry(at date: Date) -> SolatWidgetEntry {
    let defaults = UserDefaults(suiteName: SolatWidgetConstants.appGroup)
    let prayerMonth = defaults?.string(forKey: "prayer_data")
      .flatMap { $0.data(using: .utf8) }
      .flatMap { try? JSONDecoder().decode(PrayerMonth.self, from: $0) }
    let is12HourTime = defaults?.object(forKey: "widget_time_is_12") as? Bool ?? true

    return SolatWidgetEntry(
      date: date,
      prayerMonth: prayerMonth,
      location: defaults?.string(forKey: "widget_title") ?? "",
      language: defaults?.string(forKey: "widget_language") ?? "en",
      uses24HourTime: !is12HourTime
    )
  }
}

private struct SolatWidgetView: View {
  @Environment(\.widgetFamily) private var family
  let entry: SolatWidgetEntry

  private var timeFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: entry.isMalay ? "ms_MY" : "en_MY")
    formatter.timeZone = SolatWidgetConstants.malaysiaTimeZone
    formatter.dateFormat = entry.uses24HourTime ? "HH:mm" : "h:mm a"
    return formatter
  }

  private var headerDate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: entry.isMalay ? "ms_MY" : "en_MY")
    formatter.timeZone = SolatWidgetConstants.malaysiaTimeZone
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: entry.date)
  }

  var body: some View {
    Group {
      if family == .systemSmall {
        smallLayout
      } else {
        listLayout
      }
    }
    .modifier(WidgetBackground())
  }

  private var smallLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      header
      Spacer(minLength: 0)
      if let nextPrayer = entry.upcomingPrayers.first {
        Text(entry.isMalay ? "Waktu seterusnya" : "Next prayer")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(nextPrayer.name.label(isMalay: entry.isMalay))
          .font(.title2.bold())
          .minimumScaleFactor(0.75)
          .lineLimit(1)
        Text(timeFormatter.string(from: nextPrayer.date))
          .font(.headline)
          .foregroundStyle(.teal)
        Text(nextPrayer.date, style: .timer)
          .font(.caption2)
          .foregroundStyle(.secondary)
      } else {
        unavailableMessage
      }
    }
    .padding()
  }

  private var listLayout: some View {
    VStack(alignment: .leading, spacing: 8) {
      header
      if let nextPrayer = entry.upcomingPrayers.first {
        HStack(alignment: .firstTextBaseline) {
          VStack(alignment: .leading, spacing: 2) {
            Text(entry.isMalay ? "Waktu seterusnya" : "Next prayer")
              .font(.caption)
              .foregroundStyle(.secondary)
            Text(nextPrayer.name.label(isMalay: entry.isMalay))
              .font(.title3.bold())
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 2) {
            Text(timeFormatter.string(from: nextPrayer.date))
              .font(.headline)
              .foregroundStyle(.teal)
            Text(nextPrayer.date, style: .timer)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
        Divider()
        ForEach(Array(entry.upcomingPrayers.dropFirst().prefix(family == .systemLarge ? 5 : 3))) {
          prayer in
          prayerRow(prayer)
        }
      } else {
        unavailableMessage
      }
      Spacer(minLength: 0)
    }
    .padding()
  }

  private var header: some View {
    HStack(spacing: 4) {
      Text(entry.prayerMonth?.zone ?? (entry.isMalay ? "Waktu Solat" : "Prayer Times"))
        .font(.caption.bold())
        .lineLimit(1)
      if !entry.location.isEmpty {
        Text("· \(entry.location)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
      Spacer(minLength: 2)
      Text(headerDate)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
  }

  private func prayerRow(_ prayer: PrayerEvent) -> some View {
    HStack {
      Text(prayer.name.label(isMalay: entry.isMalay))
        .font(.subheadline)
      Spacer()
      Text(timeFormatter.string(from: prayer.date))
        .font(.subheadline.monospacedDigit())
        .foregroundStyle(.secondary)
    }
  }

  private var unavailableMessage: some View {
    Text(
      entry.isMalay
        ? "Buka aplikasi untuk mengemas kini waktu solat." : "Open the app to update prayer times."
    )
    .font(.subheadline)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct WidgetBackground: ViewModifier {
  func body(content: Content) -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content.containerBackground(for: .widget) {
        Color(.systemBackground)
      }
    } else {
      content.background(Color(.systemBackground))
    }
  }
}

struct SolatHorizontalWidget: Widget {
  let kind = "SolatHorizontalWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SolatTimelineProvider()) { entry in
      SolatWidgetView(entry: entry)
    }
    .configurationDisplayName("Prayer Times (Horizontal)")
    .description("See today's prayer times and the next prayer.")
    .supportedFamilies([.systemMedium])
  }
}

struct SolatVerticalWidget: Widget {
  let kind = "SolatVerticalWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: SolatTimelineProvider()) { entry in
      SolatWidgetView(entry: entry)
    }
    .configurationDisplayName("Prayer Times (Vertical)")
    .description("See the next prayer and upcoming prayer times.")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

@main
struct SolatWidgetBundle: WidgetBundle {
  var body: some Widget {
    SolatHorizontalWidget()
    SolatVerticalWidget()
  }
}
