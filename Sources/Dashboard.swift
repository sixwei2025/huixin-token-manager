import AppKit
import SwiftUI

struct Dashboard: View {
    @ObservedObject var store: QuotaStore
    @State private var details = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(nsImage: BrandMark.image(size: 42))
                VStack(alignment: .leading, spacing: 3) {
                    Text("汇芯 token 管家").font(.system(size: 21, weight: .semibold))
                    Text("看清额度，把握节奏").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Circle().fill(Color.green).frame(width: 5, height: 5)
                Text("自动同步").font(.system(size: 11)).foregroundStyle(.secondary)
                Button { store.manualRefresh() } label: { Label("更新", systemImage: "arrow.clockwise") }
                    .disabled(CommandLine.arguments.contains("--demo")).controlSize(.small)
                Menu {
                    Button("连接与来源") { details = true }
                    Button("打开独立窗口") { AppWindowHelper.shared.showWindow(store: store) }
                    Divider()
                    Button("退出汇芯 token 管家") { NSApp.terminate(nil) }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 22)
            }
            HStack(alignment: .top, spacing: 14) {
                ForEach(store.cards) { card in
                    ProviderPanel(card: card, loading: store.loading.contains(card.id),
                        connecting: store.connecting.contains(card.id), blocked: store.blocked.contains(card.id),
                        connect: { store.connect(card.id) })
                }
            }
            HStack {
                Text(CommandLine.arguments.contains("--demo") ? "演示数据" : "每 30 秒独立更新 · 唤醒与联网后自动同步")
                Spacer()
                Button("连接与来源") { details = true }.buttonStyle(.plain)
            }.font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .padding(22).frame(width: 960, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $details) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Image(nsImage: BrandMark.image(size: 30))
                    Text("汇芯 token 管家").font(.title2.bold())
                }
                Text("只看额度与预测").font(.headline)
                Text("Codex 与 Antigravity 读取本机已登录的账号。WorkBuddy 使用 Chrome 中已登录的官网会话，连接一次后由常驻读取进程复用。")
                HStack {
                    Text("WorkBuddy").bold()
                    Spacer()
                    Link("登录官网", destination: URL(string: "https://www.workbuddy.cn/profile/plans-usage")!)
                    Button(store.connecting.contains("workbuddy") ? "等待本人授权…" : "连接 WorkBuddy") { store.connect("workbuddy") }
                        .disabled(store.loading.contains("workbuddy"))
                }
                Text("首次连接可能出现系统钥匙串提示，请本人确认。自动同步不弹授权框；授权失效后停止自动重试，其他服务继续更新。")
                    .foregroundStyle(.secondary)
                Divider()
                Text("预测参考真实周期内的平均用量，结合近期消耗记录；额度恢复或充值后重新计算。预测是估计值，会随使用强度变化。")
                Text("袁六伟 · 台州汇芯\n读取与周期预测基于 Peter Steinberger / CodexBar v0.85.0（MIT）；界面由汇芯原创。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                HStack {
                    Link("开源来源", destination: URL(string: "https://github.com/steipete/CodexBar")!)
                    Spacer()
                    Button("完成") { details = false }.keyboardShortcut(.defaultAction)
                }
            }.font(.system(size: 12)).padding(26).frame(width: 540)
        }
    }
}
struct ProviderPanel: View {
    let card: QuotaCard
    let loading: Bool
    let connecting: Bool
    let blocked: Bool
    let connect: () -> Void
    private var tint: Color {
        card.id == "codex" ? Color(red: 0.12, green: 0.48, blue: 0.43) : card.id == "antigravity" ? Color(red: 0.36, green: 0.36, blue: 0.72) : accent
    }
    private var icon: String { card.id == "codex" ? "terminal" : card.id == "antigravity" ? "sparkles" : "square.stack.3d.up" }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: icon).font(.system(size: 17, weight: .medium)).foregroundStyle(tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(card.name).font(.system(size: 16, weight: .semibold))
                    Text(card.subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                if loading && card.meters.isEmpty { ProgressView().controlSize(.small) }
                else { Circle().fill(card.issue != nil ? Color.orange : tint).frame(width: 5, height: 5) }
            }
            Rectangle().fill(tint.opacity(0.20)).frame(height: 2)
            VStack(alignment: .leading, spacing: card.meters.count > 2 ? 12 : 22) {
                if card.meters.isEmpty {
                    Text(loading ? "正在连接服务…" : "连接后显示实时额度").font(.system(size: 12)).foregroundStyle(.secondary)
                }
                if card.id == "workbuddy", let total = card.totalCredits {
                    HStack { Text("总积分"); Spacer(); Text(total).monospacedDigit() }
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
                if card.id == "antigravity" && card.meters.count == 4 {
                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(0..<2) { group in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(group == 0 ? "Gemini" : "Claude / GPT").font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
                                HStack(alignment: .top, spacing: 14) {
                                    meterTile(card.meters[group * 2], compact: true)
                                    meterTile(card.meters[group * 2 + 1], compact: true)
                                }
                            }
                        }
                    }
                } else {
                    ForEach(card.meters) { meter in meterTile(meter) }
                }
            }.opacity(card.issue == nil ? 1 : 0.62)
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: 5) {
                Label("用量预测", systemImage: "waveform.path").font(.system(size: 10, weight: .medium)).foregroundStyle(tint)
                Text(card.predictionTitle).font(.system(size: 12, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                Text(card.predictionDetail).font(.system(size: 9)).foregroundStyle(.secondary).lineLimit(2)
            }.frame(maxWidth: .infinity, minHeight: 64, alignment: .leading).padding(11)
                .background(tint.opacity(0.055), in: RoundedRectangle(cornerRadius: 10))
            if connecting {
                Text("等待本人完成系统授权…").font(.system(size: 10)).foregroundStyle(.secondary)
            } else if blocked && card.id == "workbuddy" {
                HStack(spacing: 8) {
                    Text("会话未连接").font(.system(size: 10)).foregroundStyle(.orange)
                    Spacer()
                    Button("连接 WorkBuddy", action: connect).controlSize(.small).disabled(loading)
                }
            } else {
                HStack {
                    if let issue = card.issue {
                        Text(issue).foregroundStyle(.orange).lineLimit(1).help(issue)
                    } else if let updated = card.updated {
                        Text(loading ? "后台同步中 · 数据可继续查看" : "更新于 " + updated.formatted(date: .omitted, time: .standard))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 2)
                }.font(.system(size: 9))
            }
        }
        .padding(16).frame(maxWidth: .infinity).frame(height: 370)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 15))
        .overlay(RoundedRectangle(cornerRadius: 15).stroke(tint.opacity(0.12)))
    }
    private func meterTile(_ meter: Meter, compact: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(compact ? meter.label.components(separatedBy: " · ").last! : meter.label)
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer(minLength: 2)
                Text(meter.amount ?? meter.remaining.map { String(format: "%.0f%%", $0) } ?? "—")
                    .font(.system(size: compact ? 19 : 25, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle((meter.remaining ?? 100) <= 10 ? accent : Color.primary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.09))
                    Capsule().fill(tint).frame(width: geo.size.width * (meter.remaining ?? 0) / 100)
                }
            }.frame(height: 4)
            if meter.reset != nil {
                Text(resetText(meter.reset)).font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(1).minimumScaleFactor(0.8)
            }
        }.frame(maxWidth: .infinity)
    }

}
