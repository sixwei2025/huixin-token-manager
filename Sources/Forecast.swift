import Foundation

struct QuotaForecast: Codable {
    let etaSeconds: Double?
    let willLastToReset: Bool
    var basis: String = "cycle"
}
extension QuotaCard {
    private var forecasts: [(Meter, QuotaForecast)] {
        meters.compactMap { m in m.forecast.map { (m, $0) } }
    }
    private var limiting: (Meter, QuotaForecast)? {
        forecasts.filter { $0.1.etaSeconds != nil }.min { ($0.1.etaSeconds ?? .infinity) < ($1.1.etaSeconds ?? .infinity) }
    }
    var predictionTitle: String {
        if issue != nil { return "数据更新后继续预测" }
        if let (_, value) = limiting, let seconds = value.etaSeconds {
            if seconds <= 0 { return "当前额度已用完" }
            if seconds < 3600 { return "预计还能用约 \(max(1, Int(ceil(seconds / 60)))) 分钟" }
            if seconds < 86400 { return "预计还能用约 \(String(format: "%.1f", seconds / 3600)) 小时" }
            return "预计还能用约 \(String(format: "%.1f", seconds / 86400)) 天"
        }
        if !forecasts.isEmpty && forecasts.allSatisfy({ $0.1.willLastToReset }) { return "按当前节奏，可用至恢复" }
        return meters.isEmpty ? "连接后开始预测" : "正在积累用量记录"
    }
    var predictionDetail: String {
        if issue != nil { return "上次数据仅作参考，不用于当前预测" }
        if let (meter, value) = limiting {
            return "\(meter.label) · \(value.basis == "recent" ? "按最近 1 小时用量" : "按本轮平均用量")估计，随使用强度变化"
        }
        if !forecasts.isEmpty { return "基于服务返回的周期与平均用量，非保证值" }
        return "需要至少 10 分钟的有效记录；额度恢复或充值后重新计算"
    }
}

struct TrendPoint: Codable {
    let date: Date
    let remaining: Double
    let reset: Date?
    let capacity: String?
}
/// A bounded, anonymous rolling window; resets and top-ups split the history before extrapolation.
final class UsageTrendStore {
    private var points: [String: [TrendPoint]] = [:]
    private let file: URL
    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("汇芯 Token 管家/trends.json")
        if let data = try? Data(contentsOf: self.file), let stored = try? JSONDecoder().decode([String: [TrendPoint]].self, from: data) { points = stored }
    }
    func apply(to card: QuotaCard, now: Date = Date()) -> QuotaCard {
        var card = card
        for index in card.meters.indices {
            guard let remaining = card.meters[index].remaining, remaining.isFinite else { continue }
            let meter = card.meters[index]
            let key = card.id + ":" + meter.label
            var history = (points[key] ?? []).filter { now.timeIntervalSince($0.date) <= 7200 && $0.date <= now }
            if let last = history.last {
                let resetChanged = last.reset.map { old in meter.reset.map { abs(old.timeIntervalSince($0)) > 60 } ?? true } ?? (meter.reset != nil)
                if resetChanged || remaining > last.remaining + 0.25 || last.capacity != card.totalCredits { history = [] }
            }
            if history.last.map({ now.timeIntervalSince($0.date) >= 25 }) ?? true {
                history.append(TrendPoint(date: now, remaining: remaining, reset: meter.reset, capacity: card.totalCredits))
            }
            points[key] = Array(history.suffix(300))
            let recent = history.filter { now.timeIntervalSince($0.date) <= 3600 }
            if let forecast = Self.forecast(recent, current: remaining, reset: meter.reset, now: now) { card.meters[index].forecast = forecast }
        }
        try? FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(points) { try? data.write(to: file, options: .atomic) }
        return card
    }
    static func forecast(_ points: [TrendPoint], current: Double, reset: Date?, now: Date) -> QuotaForecast? {
        guard points.count >= 3, let first = points.first, let last = points.last,
              last.date.timeIntervalSince(first.date) >= 600, now.timeIntervalSince(last.date) <= 120,
              current.isFinite, current >= 0, current <= 100 else { return nil }
        let consumed = first.remaining - last.remaining
        guard consumed >= 0.5 else { return nil }
        let eta = current * last.date.timeIntervalSince(first.date) / consumed
        guard eta.isFinite else { return nil }
        if let reset, reset <= now { return nil }
        let lasts = reset.map { eta >= $0.timeIntervalSince(now) } ?? false
        return QuotaForecast(etaSeconds: lasts ? nil : eta, willLastToReset: lasts, basis: "recent")
    }
}
