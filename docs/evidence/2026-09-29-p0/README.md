# P0工程证据

日期2026-09-29。本目录对应[工程验收](../../2026-09-29_P0构建与性能基线验收.md)，并非最终品质验收。

- `build-manifest.json`：运行时输入逐文件SHA-256、基线提交、未提交状态、存档版本、引擎和PCK摘要。
- `artifact-sha256.json`：签名后的运行时及ZIP摘要；验证包唯一目录见构建ID。
- `checks.json`：43项Godot、4项Python及独立包检查摘要；旧包哈希。
- `profile-a.json` / `profile-b.json`：Compatibility的A/B各3轮普通/混乱数据，保留所有帧。
- `profile-a-forward-plus.json` / `profile-b-forward-plus.json`：Metal Forward+相同夹具与分辨率数据；没有修改项目默认渲染器。
- `package-menu.png`：最终验证包1280×800菜单，构建标签可见；从/tmp启动，禁用正式存档。
- `forward-plus/`：Forward+街道、入口、工位、A面试渲染复核；不作为与Compatibility完全等价的效果证明。

复现：先用`python3 tools/build_manifest.py --output build/p0-source-identity.json`记录输入，再以Godot执行`tests/performance.gd -- --runs=3 --company=a --identity=build/p0-source-identity.json --output=res://build/p0-profile-a.json`，B改company。Forward+增加`--rendering-method forward_plus --rendering-driver metal`。不要并行运行图形性能采样。短固定视点按帧数触发混乱，因此不同帧率下模拟时长不同，不能从FPS比值推导纯GPU加速倍率。

独立包验证：从/tmp运行应用内`Contents/MacOS/TodayOff --script <项目绝对路径>/tools/verify_macos.gd -- --screenshot=<输出绝对路径>`；无画面加`--headless`。夹具不设current_scene，断言persistence=false；不覆盖用户存档。

限制：原型场景；120FPS受显示刷新上限影响；两种渲染器GPU计时均不可用；无20分钟路线、最终密度、主观声音或独立玩家结论。清单中的`not_yet_verified`是签名时事实，验证记录在本目录，避免签名后改包。
