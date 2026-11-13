from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/showcase'
FONT='/System/Library/Fonts/STHeiti Medium.ttc'
def font(n): return ImageFont.truetype(FONT,n)
RED='#C8102E'; INK='#18181B'; MUTED='#66666D'
def text(d,xy,s,n=24,color=INK):d.text(xy,s,font=font(n),fill=color)
def base(h):
 im=Image.new('RGB',(1600,h),'#F8F7F5');d=ImageDraw.Draw(im)
 d.rounded_rectangle((48,42,312,86),radius=20,fill=RED);text(d,(68,51),'汇芯 · 开源工具',23,'white')
 return im,d
im,d=base(700)
text(d,(60,133),'汇芯 Token 管家',66)
text(d,(62,228),'还剩多少，一眼就知道',43,RED)
text(d,(64,307),'Codex · Antigravity · Grok Bot · WorkBuddy',25)
text(d,(64,359),'横向四卡 / 真实周期 / 总积分与可用积分',24,MUTED)
for i,(a,b) in enumerate([('01','安装应用'),('02','本机登录'),('03','连接来源'),('04','查看额度')]):
 x=64+i*205;d.rounded_rectangle((x,420,x+183,488),radius=15,fill='white',outline='#E3DDDA');text(d,(x+15,439),a+' '+b,21)
text(d,(64,527),'macOS 14+ · Apple 芯片 · 无需另装 CodexBar',25,RED)
d.rounded_rectangle((953,118,1547,575),radius=24,fill=INK)
text(d,(985,148),'更适合电脑的横向看板',29,'white')
for i,(name,value,cycle) in enumerate([('Codex','85%','5 小时 · 每周'),('Antigravity','78%','区分模型与周期'),('Grok Bot','45%','独立额度'),('WorkBuddy','3,120','可用积分 / 总积分')]):
 x=980+(i%2)*280;y=210+(i//2)*153
 d.rounded_rectangle((x,y,x+256,y+131),radius=17,fill='#2D2D34')
 text(d,(x+15,y+16),name,24,'white');text(d,(x+15,y+50),value,33,'#F1ABB7');text(d,(x+15,y+94),cycle,17,'#D3CED0')
text(d,(989,538),'数值仅作演示，读取本人账号',19,'#D3CED0')
d.rectangle((0,620,1600,700),fill=INK)
text(d,(62,642),'袁六伟 · 台州汇芯  |  公众号 / 视频号：袁六伟',23,'white')
text(d,(900,646),'学员 7000+ 人 · 服务商单客户 100+ 家',21,'#D0C8CA')
im.save(OUT/'hero-banner.jpg',quality=94)
im,d=base(680)
text(d,(60,123),'从本人账号，到一眼可见的剩余额度',47)
steps=[('本机登录','自己的工具与会话','不共享作者账号'),('内置读取引擎','固定版本 · 官方来源','SHA-256 校验'),('真实字段适配','区分模型、周期和积分','不混用独立额度'),('横向中文卡片','剩余额度与恢复时间','失败标记旧数据')]
for i,(a,b,c) in enumerate(steps):
 x=60+i*385
 d.rounded_rectangle((x,238,x+348,486),radius=22,fill='white',outline='#DED9D6',width=2)
 text(d,(x+22,262),f'STEP 0{i+1}',21,RED);text(d,(x+22,307),a,33);text(d,(x+22,365),b,22,MUTED)
 d.rounded_rectangle((x+20,421,x+328,465),radius=10,fill=RED);text(d,(x+32,431),c,20,'white')
 if i<3:text(d,(x+352,335),'→',25,RED)
d.rounded_rectangle((60,534,1540,626),radius=18,fill=INK)
text(d,(86,553),'本地个人看板 · 无汇芯账号体系 · 不上传作者账号 · 保留上游 MIT 与来源',25,'white')
text(d,(86,590),'支持 Apple 芯片 Mac / macOS 14+；Windows 与 Intel Mac 暂不支持。',19,'#D0C8CA')
im.save(OUT/'pipeline-architecture.jpg',quality=94)
print('Rendered 1600×700 and 1600×680')
