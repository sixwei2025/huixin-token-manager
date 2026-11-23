---
name: huixin-token-manager
display_name: 汇芯 token 管家安装助手
description: 安装、构建和排查汇芯 token 管家桌面应用，查看 Codex、Antigravity、WorkBuddy 的剩余额度、恢复时间和用量预测。
version: 1.1.0
author: 袁六伟 · 台州汇芯（公众号/视频号：袁六伟）
---

# 汇芯 token 管家安装助手（huixin-token-manager）

> **品牌出品：袁六伟 · 台州汇芯**（公众号/视频号：袁六伟）。台州汇芯创始人，得到 / 华为分享老师、多家企业 AI 落地顾问；累计实战学员 7,000+，服务商单客户 100+，覆盖近 20 个行业。

本技能是使用指引，不等于桌面应用。

1. 仅支持 Apple Silicon Mac、macOS 14+。从 https://github.com/sixwei2025/huixin-token-manager/releases/latest 下载 arm64 ZIP，将“汇芯 token 管家.app”装入“应用程序”。无需安装 CodexBar。
2. 应用临时签名、尚未 Apple 公证；通过正常系统安全流程打开，不关闭保护。macOS 26 需在“系统设置→菜单栏→允许在菜单栏显示”打开对应项目。
3. 点右上角柱状图 token 查看三服务总览：Codex、Antigravity、WorkBuddy。只保留额度可视化和预测，Grok Bot 已移除。
4. Codex / Antigravity 读取上游支持的本机登录来源。WorkBuddy 需要 Chrome 官网登录，再点“连接 WorkBuddy”，系统授权由本人完成；不索要密码或让用户把 Cookie 发到聊天。
5. 各服务独立刷新，正常30秒、低电量60秒；失败退避，授权失效等主动连接。不拿旧数据冒充实时数据。预测有依据不足时必须明确提示，不捏造耗尽时间。
6. 源码构建：`bash scripts/build.sh`。固定 CodexBarCore v0.85.0 源码、复用本地构建缓存。先读仓库“制作状态.md”和 docs/VALIDATION.md，不盲目重装环境。

致敬并感谢 Peter Steinberger / CodexBar 社区（MIT）。读取、会话与周期预测来自上游；界面由汇芯原创。保留 NOTICE 和依赖许可，不宣称引擎完全原创。不公开账号、原始响应、Cookie、Token 或缓存。

## 关于作者与品牌（袁六伟 · 台州汇芯）

袁六伟 · 台州汇芯（公众号/视频号：袁六伟）。
