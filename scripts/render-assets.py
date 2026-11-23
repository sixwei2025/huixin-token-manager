#!/usr/bin/env python3
"""Render high-DPI README showcase hero-banner.jpg using headless Chrome + 01-app-demo.png."""

from pathlib import Path
import subprocess
import tempfile
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "showcase"
DEMO_PNG = OUT / "01-app-demo.png"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

HTML = f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8" />
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; }}
  html, body {{
    width: 1600px;
    height: 700px;
    overflow: hidden;
    font-family: -apple-system, BlinkMacSystemFont, "PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", sans-serif;
    background: linear-gradient(135deg, #FAF8F6 0%, #F4EFEA 55%, #F0E9E4 100%);
    color: #18181B;
    position: relative;
  }}
  .glow-red {{
    position: absolute;
    right: -120px;
    top: -140px;
    width: 780px;
    height: 780px;
    background: radial-gradient(circle, rgba(200,16,46,0.085) 0%, rgba(200,16,46,0) 68%);
    pointer-events: none;
  }}
  .glow-warm {{
    position: absolute;
    left: -100px;
    bottom: -140px;
    width: 560px;
    height: 560px;
    background: radial-gradient(circle, rgba(24,24,27,0.04) 0%, rgba(24,24,27,0) 70%);
    pointer-events: none;
  }}
  .container {{
    position: relative;
    z-index: 2;
    width: 100%;
    height: 628px;
    padding: 44px 56px 28px 56px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 44px;
  }}
  .left {{
    width: 720px;
    display: flex;
    flex-direction: column;
    justify-content: center;
  }}
  .badge {{
    display: inline-flex;
    align-items: center;
    gap: 8px;
    align-self: flex-start;
    background: #C8102E;
    color: #FFFFFF;
    font-size: 16px;
    font-weight: 600;
    padding: 8px 18px;
    border-radius: 999px;
    letter-spacing: 0.3px;
    box-shadow: 0 6px 16px rgba(200, 16, 46, 0.22);
  }}
  .title-row {{
    display: flex;
    align-items: center;
    gap: 20px;
    margin-top: 22px;
  }}
  .app-icon {{
    width: 72px;
    height: 72px;
    border-radius: 18px;
    background: linear-gradient(145deg, #D91434 0%, #B30C27 100%);
    display: flex;
    align-items: flex-end;
    justify-content: center;
    gap: 7px;
    padding: 15px 14px;
    box-shadow: 0 10px 24px rgba(200, 16, 46, 0.28);
    flex-shrink: 0;
  }}
  .bar {{
    width: 11px;
    background: #FFFFFF;
    border-radius: 4px;
  }}
  .bar.b1 {{ height: 18px; }}
  .bar.b2 {{ height: 30px; }}
  .bar.b3 {{ height: 42px; }}
  h1 {{
    font-size: 56px;
    font-weight: 800;
    letter-spacing: -0.5px;
    line-height: 1.1;
    color: #141417;
  }}
  .subtitle {{
    margin-top: 14px;
    font-size: 27px;
    font-weight: 700;
    color: #C8102E;
    line-height: 1.3;
  }}
  .desc {{
    margin-top: 12px;
    font-size: 18px;
    line-height: 1.55;
    color: #52525B;
    max-width: 680px;
  }}
  .cards {{
    margin-top: 26px;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
  }}
  .card {{
    background: rgba(255, 255, 255, 0.92);
    border: 1px solid #E5DFD9;
    border-top: 3px solid #C8102E;
    border-radius: 14px;
    padding: 14px 14px 13px 14px;
    box-shadow: 0 4px 14px rgba(24, 24, 27, 0.04);
  }}
  .card-num {{
    font-size: 12px;
    font-weight: 700;
    color: #C8102E;
    letter-spacing: 0.4px;
  }}
  .card-title {{
    margin-top: 4px;
    font-size: 16px;
    font-weight: 700;
    color: #18181B;
  }}
  .card-sub {{
    margin-top: 5px;
    font-size: 12.5px;
    line-height: 1.4;
    color: #66666D;
  }}
  .pills {{
    margin-top: 22px;
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }}
  .pill {{
    background: #18181B;
    color: #F4F4F5;
    font-family: "SF Mono", Menlo, monospace;
    font-size: 13.5px;
    font-weight: 600;
    padding: 8px 15px;
    border-radius: 9px;
  }}
  .pill-outline {{
    background: rgba(255, 255, 255, 0.85);
    color: #3F3F46;
    border: 1px solid #DCD6D0;
    font-size: 13.5px;
    font-weight: 600;
    padding: 7px 14px;
    border-radius: 9px;
  }}
  .right {{
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    justify-content: center;
  }}
  .window {{
    width: 736px;
    background: #1C1C20;
    border-radius: 18px;
    padding: 10px 10px 10px 10px;
    box-shadow:
      0 28px 60px rgba(20, 20, 26, 0.22),
      0 8px 20px rgba(20, 20, 26, 0.12),
      0 0 0 1px rgba(255, 255, 255, 0.12) inset;
  }}
  .window-bar {{
    height: 30px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 0 10px 6px 10px;
  }}
  .dots {{
    display: flex;
    gap: 7px;
  }}
  .dot {{
    width: 11px;
    height: 11px;
    border-radius: 50%;
  }}
  .dot.r {{ background: #FF5F56; }}
  .dot.y {{ background: #FFBD2E; }}
  .dot.g {{ background: #27C93F; }}
  .win-title {{
    font-size: 12.5px;
    color: #A1A1AA;
    font-weight: 500;
  }}
  .win-tag {{
    font-size: 11.5px;
    color: #F4F4F5;
    background: rgba(200, 16, 46, 0.85);
    padding: 2px 9px;
    border-radius: 999px;
    font-weight: 600;
  }}
  .screen-wrap {{
    width: 100%;
    border-radius: 10px;
    overflow: hidden;
    background: #FFFFFF;
  }}
  .screen-wrap img {{
    display: block;
    width: 100%;
    height: auto;
  }}
  .caption {{
    margin-top: 12px;
    font-size: 13px;
    color: #71717A;
    padding-right: 4px;
  }}
  .footer {{
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 72px;
    background: #18181B;
    color: #F4F4F5;
    padding: 0 56px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    font-size: 15.5px;
    z-index: 3;
  }}
  .footer-left {{
    display: flex;
    align-items: center;
    gap: 14px;
  }}
  .footer-brand {{
    color: #FFFFFF;
    font-weight: 700;
  }}
  .footer-sep {{
    color: #52525B;
  }}
  .footer-muted {{
    color: #D4D4D8;
    font-size: 14.5px;
  }}
  .footer-right {{
    color: #A1A1AA;
    font-size: 14px;
  }}
</style>
</head>
<body>
  <div class="glow-red"></div>
  <div class="glow-warm"></div>
  <div class="container">
    <div class="left">
      <div class="badge">汇芯开源工具 · v1.1.0 · Apple Silicon / macOS 14+</div>
      <div class="title-row">
        <div class="app-icon">
          <div class="bar b1"></div>
          <div class="bar b2"></div>
          <div class="bar b3"></div>
        </div>
        <h1>汇芯 token 管家</h1>
      </div>
      <div class="subtitle">只看额度与预测 · 一眼看清三引擎剩余配额</div>
      <div class="desc">
        Codex · Antigravity · WorkBuddy 三栏横向看板，独立后台同步与可解释用量预测，不猜、不编造耗尽时间。
      </div>
      <div class="cards">
        <div class="card">
          <div class="card-num">01 原创面板</div>
          <div class="card-title">三栏同屏</div>
          <div class="card-sub">区分模型周期与可用积分</div>
        </div>
        <div class="card">
          <div class="card-num">02 独立同步</div>
          <div class="card-title">互不阻塞</div>
          <div class="card-sub">超时去重与失败退避保护</div>
        </div>
        <div class="card">
          <div class="card-num">03 用量预测</div>
          <div class="card-title">可解释趋势</div>
          <div class="card-sub">真实周期与近期消耗</div>
        </div>
        <div class="card">
          <div class="card-num">04 本地隐私</div>
          <div class="card-title">零账号上传</div>
          <div class="card-sub">只读本人本机授权会话</div>
        </div>
      </div>
      <div class="pills">
        <div class="pill">菜单栏常驻 · token</div>
        <div class="pill">CodexBarCore v0.85.0 (MIT)</div>
        <div class="pill-outline">无需另装原版 CodexBar</div>
      </div>
    </div>

    <div class="right">
      <div class="window">
        <div class="window-bar">
          <div class="dots">
            <div class="dot r"></div>
            <div class="dot y"></div>
            <div class="dot g"></div>
          </div>
          <div class="win-title">汇芯 token 管家 — 实时额度看板</div>
          <div class="win-tag">演示模式</div>
        </div>
        <div class="screen-wrap">
          <img src="{DEMO_PNG.as_uri()}" alt="汇芯 token 管家界面" />
        </div>
      </div>
      <div class="caption">真实应用界面截图（演示数据），支持菜单栏一键唤起与后台静默刷新</div>
    </div>
  </div>

  <div class="footer">
    <div class="footer-left">
      <span class="footer-brand">袁六伟 · 台州汇芯</span>
      <span class="footer-sep">|</span>
      <span class="footer-muted">得到 / 华为分享老师 · 实战学员 7,000+ · 企业商单客户 100+</span>
    </div>
    <div class="footer-right">公众号 / 视频号：袁六伟  ·  致敬 Peter Steinberger / CodexBar (MIT)</div>
  </div>
</body>
</html>
"""


def main() -> None:
    with tempfile.TemporaryDirectory() as td:
        td_path = Path(td)
        html_path = td_path / "banner.html"
        png_path = td_path / "banner.png"
        html_path.write_text(HTML, encoding="utf-8")

        subprocess.run(
            [
                CHROME,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--force-device-scale-factor=2",
                "--window-size=1600,700",
                f"--screenshot={png_path}",
                html_path.as_uri(),
            ],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

        im = Image.open(png_path).convert("RGB")
        if im.size != (1600, 700):
            im = im.resize((1600, 700), Image.Resampling.LANCZOS)
        out_path = OUT / "hero-banner.jpg"
        im.save(out_path, quality=95, subsampling=0)
        print(f"Saved {out_path} ({im.size[0]}x{im.size[1]})")


if __name__ == "__main__":
    main()
