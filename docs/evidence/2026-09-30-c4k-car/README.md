# C4k 汽车整车与驾驶空间证据

2026-09-30。最终运行SHA-256 `7548c00925247863693d343d9f02903bb36c33c20a68305082d42fb56889e10e`；构建 `20260930T065815183215Z-f64360ab-7548c009`。对应[阶段验收](../../2026-09-30_C4k汽车整车与驾驶空间验收.md)中的G05-C4k-A/B、G05/G06-C4k-C。工程通过不等于GTA VI展示品质、整城或独立玩家体验通过。

## 来源与内容

| 文件 / 目录 | 内容与验证范围 |
| --- | --- |
| final-source.json | 最终套件启动前冻结的全部运行输入；结束后逐项摘要一致 |
| final-check-coverage.json | 98项Godot逐测试源码/日志摘要、执行时间和通过标记；整套退出0，全部日志晚于最终清单，无执行后改测试 |
| integration-checks.json | 32项Python、A/B职业图形、源码/包静态与驾驶、八档恢复、两目录包启动、导入/冒烟等20份日志摘要；无ERROR/WARNING |
| artifact-verification.json | 最终源码、PCK、签名后引擎、内外清单、制作摘要、签名、ZIP CRC及内容一致；原构建dirty/not_yet_verified保留 |
| source-visual / package-visual | 各12张固定夹具相机图和render.json；几何、司机与光照对照，不能当普通FPS |
| source-route / package-route | 各7张普通玩家相机图、连续路线JSON及四份实际存档；实际按键驾驶，无行程坐标直接摆放 |
| save-recovery.json | 实际TodayOff八个独立进程恢复上述八份档；全部驾驶字段在同一JSON表示下比较，暂停灯光/座位和恢复制动通过 |
| render-identity.json | 固定图12对中7对字节相同；其余1—194像素差异，最大通道差37；路线7对中5对相同，其他10/27像素差、最大1；路线JSON全字段相同 |
| source-career | 最终A/B职业图形路线七图留存，未计为本轮逐张视觉复核 |
| before | 旧方盒车体及司机当前/明确坐姿的4张图片和原始测量 |
| iteration | 三次制作图、旧轮罩看穿近景、383帧碰撞阻挡的被拒路线、旧候选身份与观察结果；均不是最终通过证据 |
| temporary-package-probes.json | 包外工具临时副本摘要；继承地址改为包外绝对路径，运行场景/资源仍从PCK读取，副本已清理 |
| manifest.json | 本目录原图和JSON逐文件SHA-256；不包含自身或可继续补记的README |

最终53张原图归档。安装包12张固定视角已全部直接查看；普通玩家路线中的`seated-player-camera`、`waterfront`、`parked-player-camera`、`exit-at-homes`四张已直接查看。只对实际看过或同字节对应图主张视觉复核；其他图片用于保留流程证据。当前画面仍是原型品质，细致握姿、上下车表演、精细纹理与城市密度开放。

## 可复现入口

- `tools/prepare_city_car.gd`：重建六网格、LOD及制作来源；复用公交几何工具，无新增依赖。
- `tests/city_car_visual_test.gd`：78,040三角、82条LOD、24条朝向遮挡射线、实际蒙皮支撑、三司机33转向双掌、18晨昏边界与暂停读档。
- `tools/render_city_car.gd -- --output=<专用绝对目录>`：12固定视角；`tools/render_car_journey.gd`同参数生成普通相机路线和四份档。
- `tools/verify_car_journey_save.gd -- --source=<实际档绝对路径> --output=<结果绝对路径>`：独立实际包恢复；外部验证脚本用绝对路径传入TodayOff，包内不包含tools/tests。
- 完整检查：`GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot sh tools/check.sh`；Python：`python3 -m unittest discover -s tests -p 'test_*.py' -v`。

图形探针继承安全后台工具：启动和延迟入口均设NO_FOCUS与最小化、禁根输入、可见鼠标、Dummy音频；场景关闭玩家持久化。工具的初始时间/固定截图相机是夹具，不冒充自然开局。行程使用原控制器/碰撞/车流，提前制动由合成玩家按键完成，不是运行游戏新增自动刹车。前一轮罩版本套件主动中断，最终98项为修正后完整重新执行。

源码和最终包各323.868993m，最大车体单步0.092586m、阻挡0，从初始17:40经步行/驾驶到18:23下车。这是受控路线工程证据，不是持续30—60分钟独立自由试玩，也不证明1440p30/1080p60。
