# S4 手物接触证据

2026-09-29，工程子阶段。对应 [验收与问题表](../../2026-09-29_S4手机取放与持物接触验收.md)。

- `contact-measurements.json`：最终六体型、四手机片段各257相位、四物件各97步态采样；支撑体积五相位。接触最大2.035mm、支撑穿透最大0.326mm。
- 七张最终图：A拿起/持机、B持机、四物件托举，逐张实际查看；另两张已看返工反例保留，不能误作最终画面。图片1200×900、FOV40、Compatibility、2xMSAA；沿用实际场景光照。生成12张，只归档明确查看的7张最终图。
- `remaining-measurements.json`：纸张/纸箱未修的三相位真实网格AABB间距，不将内部点距离0解释为没有穿透。
- `validation.json`：最终54项Godot完整门禁、24项Python、两公司图形路线；图形路线在清理无几何手机标记前完成，最终headless和接触图在清理后完成。
- `build-manifest.json`、`artifact-sha256.json`、`package-verification.json`：独立包身份、ZIP摘要、两目录启动器探针和签名/ZIP结果。新包 `20260929T063601251860Z-8505c34f-8cea17f0`，源摘要8cea17f0；构建于提交前，dirty标记真实保留，包内不回写结果。

复现命令：`GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot sh tools/check.sh`；`python3 -m unittest discover -s tests -p 'test_*.py'`；headless脚本 `tests/hand_contact_test.gd -- --output=res://build/hand-contact-measurements.json`。

图形只用 `open -g -n` 启动 `tools/render_hand_contacts.gd`，继承隐藏NO_FOCUS根窗口，SubViewport明确UPDATE_ALWAYS；不拉前台、不捕获鼠标。不采用黑图或空绘制循环作画面/FPS证据。完整手指包覆、自然握姿、二十动作与玩家体验尚未验收。
