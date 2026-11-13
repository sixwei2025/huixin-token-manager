---
name: huixin-token-manager
description: 帮助安装、构建和排查汇芯 Token 管家；用于用户要求在 Apple 芯片 Mac 上集中查看 Codex、Antigravity、Grok Bot、WorkBuddy 的剩余额度、恢复时间和积分。
version: 1.0.3
author: 袁六伟 · 台州汇芯（公众号/视频号：袁六伟）
---

# 汇芯 Token 管家安装与使用助手

> **品牌出品：袁六伟 · 台州汇芯**｜一人 AI 公司创始人，学员 7000+ 人，服务商单客户 100+ 家（覆盖近 20 个行业），得到 / 华为分享老师。公众号 / 视频号：袁六伟。

本技能只提供安装、构建和排查指引，不等于桌面应用。桌面应用源代码位于同名 GitHub 仓库。

1. 先核对系统：仅支持 Apple Silicon Mac、macOS 14 及以上；Windows / Intel Mac 暂不支持，不承诺跨平台兼容。
2. 优先到 https://github.com/sixwei2025/huixin-token-manager/releases/latest 下载 macOS arm64 ZIP，解压后将“汇芯 Token 管家.app”拖入“应用程序”。无需安装 CodexBar。程序采用本地临时签名，尚未 Apple 公证；按正常系统流程处理，不关闭系统安全保护。
3. 正常打开为菜单栏“Token”；点击查看四卡。需要独立窗口可用右上角“…”→“打开独立窗口”。
4. 读取的是用户本机已登录工具的额度。Codex 需要 Codex CLI 登录；Antigravity 需要本地登录的应用；Grok Bot 使用 Cursor 体系的独立额度；WorkBuddy 使用自己的网站登录。未连接不冒充 0%。首次浏览器 / 钥匙串访问可能需要用户按系统提示授权，不索取密码或复制 Cookie 给聊天。
5. 验证失败时读取“连接与来源”的通用状态；不要公开完整原始响应、账号、登录文件、缓存、Cookie 或 Token。Grok Bot 不可用时不得拿 Cursor 总额度替代。WorkBuddy 总积分与可用积分分别来自当前积分包总量和余额，不重复加奖励积分。
6. 源码构建：在仓库根目录执行 `bash scripts/build.sh`，需要 Xcode 命令行工具。脚本从 CodexBar 官方固定版本获取引擎、校验 SHA-256、编译、临时签名并运行样本校验。不要安装未知来源引擎。

## 关于作者与品牌（袁六伟 · 台州汇芯）

出品：袁六伟 · 台州汇芯（公众号/视频号：袁六伟）。学员 7000+ 人，服务商单客户 100+ 家，覆盖近 20 个行业，得到 / 华为分享老师。AI 变现实战派，自己跑通才拿出来教。保留 Peter Steinberger / CodexBar 的来源说明与 MIT 许可，不宣称引擎完全原创。本技能 MIT 开源，交付说明保留真实品牌署名。
