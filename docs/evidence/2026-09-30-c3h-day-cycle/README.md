# C3h 跨日生活证据

`before.json`为167e11c运行代码下既有休息入口的四项夹具观测；`after.json`为最终专项七项实际E/数字键休息结果。`logic-source.json`和`final-source.json`保留文案修订前后完整运行输入摘要；差异仅city_outing.gd恢复选项的“刚才”→“之前”。

`day-route/`为最终连续路线，初始时间/玩家位置为夹具，后续使用普通输入和NPC实际路线；包含8图、route.json、暂停及完成的实际SaveGame文件。`career/`为A/B后台完整职业路线7图。`package/`为实际TodayOff默认Metal外部探针3图及身份。`images.json`逐项注明SHA-256和查看状态，不把归档自动算成已看。

`verification.json`记录84项Godot文件/日志摘要、成功标记与分段来源、30项Python输出、专项和图形检查。前11项因人物页修订另跑；“之前的同行”单项文案在其余全套执行期间修改，最终专项与图形/包另验。A/B GUI启动于这项文字修订前。`package-verification.json`保存包签名/CRC/源码输入/PCK和引擎验证。

路线运行命令（后台、静音、禁止鼠标捕获）：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --disable-render-loop --audio-driver Dummy --fixed-fps 60 --script tools/render_city_day_cycle.gd -- --no-mouse-capture --output=/private/tmp/c3h-final-day-route
```

8张路线图有实际查看依据（7张与先前已看图逐字节一致、1张文案更新后另看）；另看2张职业图和1张包图，总18张归档、11张复核。没有正常游戏FPS、全城规模或独立玩家30—60分钟体验证据。最新世界仍有重复楼体、空旷空间和原型人物/表演；详见[验收与开放范围](../../2026-09-30_C3h跨日生活与约定连续性验收.md)。
