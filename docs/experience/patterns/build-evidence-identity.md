# 构建身份与验证证据必须绑定同一批输入

信号：源码测试通过但用户仍启动旧包；相同Git提交在有未提交修改时产生不同画面；独立包资源检查在源码目录和临时目录结果不同。

机制：提交号只能标识已提交版本。导出和启动会受到当前资源、导出排除项、启动工作目录影响。签名后修改包内清单还可能破坏签名，不能把验证结果回写已签名包。

处理：`tools/build_manifest.py`记录运行时文件SHA-256及未提交状态，`tools/package_macos.py`输出唯一目录、PCK/运行时/ZIP摘要，导出后检查输入未变化；启动器先进入包内Resources，避免源码回退。构建清单只记构建事实，验收结果保存在包外。`tools/verify_macos.gd`从项目外加载包，检查身份、资源排除、场景和禁用存档；源码目录启动是另一项边界回归。重复导出必须排除build目录，复用网页导出经验。

验证：2026-09-29本项目验证一次。初版从项目目录运行时读取了`res://tests/world_test.gd`，从/tmp则没有；启动器固定工作目录后两种启动均通过。4项Python清单测试覆盖增加、改变、删除运行时文件及文档/构建忽略。两次新构建没有改变既有0.5.0包哈希。证据见`docs/evidence/2026-09-29-p0/README.md`。

性能边界：`tests/performance.gd`将图形采样与headless夹具验证分开，绑定源码摘要、实际渲染器、分辨率与原始帧时间。Compatibility的GPU计时全为零只记不可用；render CPU不含脚本，不能冒充整个CPU耗时或与重叠监视器相加。短固定视点不能证明20分钟路线或最终密度达标。

2026-09-29 S1 补充：process_frame 并不承诺该循环实际画了画面。首次场景短测出现约145FPS且绘制计数长时间不变，窗口未绘制是待证假设；不能反推过去所有快速数据一定错误。`tests/performance.gd` schema3 记录逐样本 `Engine.get_frames_drawn()` 增量，任何零绘制样本使图形批次退出3并标记无效，headless仅保留夹具验证。`--disable-render-loop`实测被拒收，正常图形180帧短诊断有效。历史schema2没有这一守卫，作为历史观察保留，不能用于最终渲染性能签收。用户随后禁止抢鼠标，旧置顶建议已撤销；自动图形验证必须后台启动、隐藏NO_FOCUS窗口、子视口显式绘制。离屏图片不等于游戏FPS，不用其循环速度做性能签收。

2026-09-29 S2再验证：绕过TodayOff启动器从项目目录直接执行包内Godot，会再次读到源码tests并触发排除检查；这不是PCK泄漏证据。通过实际启动器（它进入Resources）从两个目录执行才是产品启动边界。原始GLTF的Skin可能使用数字bind_bone，导入PackedScene则使用bind_name；离线蒙皮诊断必须分别解析后映射同名骨骼，遇到-1立即停止，不能把错误姿态计入前后数据。

2026-09-29 C3b窗口纠正：本机启动会覆盖_initialize中的隐藏/最小化，运行中不能隐藏主窗口。改为初始化和deferred入口分别设不可聚焦、后者再次最小化，结果必须记录无焦点与鼠标可见；不要只凭root.hide调用声称隐藏。详见[后台窗口状态](background-window-state.md)。原有离屏性能边界不变。

2026-09-29 C4a补充：无窗口后端的MultiMesh.buffer在本机返回空数组。两次空数组hash相等是假阳性，追加instance_count×12长度断言后610次失败，不能据此判定几何生成不稳定。确定性检查移到真实Compatibility图形后端，必须读到非空变换再比较。重建整个场景的夹具还需清理该夹具注册的InputMap动作，否则出现25个重复动作错误；只清理新建动作，保留原输入表，不扩改运行时输入行为。支持工具tools/render_city_streets.gd；最终验收状态见C4a记录，headless不再宣称验证GPU缓冲。

C4a取证路径补记：full_route_test默认输出2026-09-22历史目录；本次忘传已存在的--output参数，七张旧图被本轮截图替换。因开始时旧图干净，先把新图保存在build/c4a-company-route，再逐件从HEAD恢复历史原图，无历史证据丢失。以后图形路线必须显式传-- --output=res://build/<本阶段目录>，不要重新生成历史证据身份。

2026-09-29 C4b强制绘制补记（本机验证一次）：`--disable-render-loop`下，`Engine.get_frames_drawn()`始终为0，即便`RenderingServer.force_draw(false)`已产生真实子视口图像；旧C2b离屏数据中的该字段不能证明没有绘制。`tools/profile_district_render.gd`逐样本要求`RenderingServer.frame_post_draw`完成信号恰好增加1，并要求真实后端、非空图像和窗口守卫。最终每组三轮四视角含1080样本、120预热，总1200次完成信号；Engine计数仍0。此修正适用于显式force_draw的隔离诊断，不撤销正常渲染循环中S1的Engine计数守卫。参考[Engine文档](https://docs.godotengine.org/en/stable/classes/class_engine.html#class-engine-method-get-frames-drawn)和[RenderingServer文档](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html#class-renderingserver-signal-frame-post-draw)。冻结场景提交时间、视口render CPU和实际GPU时间分别记录；Compatibility零GPU数据继续记不可用。

2026-09-29 C4b制作源漂移（本项目验证一次）：初始`tools/company_room_source.gd`仍把手机放在z=-14.42并旋转0.12弧度，运行场景S4已经改为z=-14.54且不旋转。从旧模板重新生成公司会静默撤回接触修复；完整几何对照分别发现24个三角形位置不符及互动根变换不符。同步模板后通过，最终烘焙直接以原可编辑场景为输入。未合并制作源保存在`tools/company_sources/`且从产品包排除，生成器默认读取它；`tools/verify_company_batches.gd`在相同局部坐标中逐三角形匹配材质、法线/UV/切线，并比较碰撞、灯光、锚点元数据与互动对象。几何位置量化为0.00001m，属性容差0.001；这不能代替像素、动画、物理或长期玩家验收。支持检查`tests/company_batches_test.gd`及C4b验收。不要仅凭生成器成功退出或网格总数相同就覆盖已编辑场景。


2026-09-30 C4f验证入口补记：本机4.7.1实际TodayOff执行外部`tools/verify_macos.gd`时，新增`var hit := game.get_world_3d().direct_space_state.intersect_ray(ray)`无法推断类型，日志出现Parse Error，但进程退出0；工具加载失败，不能记为包通过。明确声明`Dictionary`后同一包实际运行至`PACKAGED_SMOKE_OK`，运行资源无需重建。检查必须同时要求成功标记、无SCRIPT ERROR/ERROR及预期检查项，不能只看shell返回码。项目`tools/check.sh`已有错误扫描，外部包与图形验证也沿用。这里只确认该外部脚本/本机版本案例，不泛化为所有Godot错误都返回0。

2026-09-30 C4g平台覆盖：项目基础renderer仍为GL，macOS feature override为Forward+。包生成器若只正则读取基础值，会写错目标配置（代码预测，在最终打包前修正）。`configured_renderer`先读取目标平台覆盖，Python用macOS覆盖和web回退两种结果验证；实际后端不能仅看配置，`verify_packaged_lighting.gd`通过TodayOff在项目外真实绘制并读取RenderingServer，确认本机默认Metal/Forward+。包清单保留配置身份，实际后端由外部验收记录；headless不能充当图形后端验证。本机一次验证，不外推其他Mac硬件或驱动回退。

C4g完成信号边界：同一工具GL总frame_post_draw为1080，Metal为2159；每个被计时样本内均实际增加1，差异位于采样区间外。汇总曾错误要求所有后端总数都等于GL结果，核查原始27条/810样本和工具逐样本断言后纠正。总信号数不是正常帧率或重复绘制归因；保持原始总数，不把Metal数据改写为1080。详见C4g四组profile JSON及验收限制。

2026-09-30 S4b再次验证外部工具入口：误用`--script res://tools/verify_macos.gd`时，发布包已按export_presets排除tools，日志明确File not found；无窗口进程仍退出0。Python的check=True单独不足以验收。改为传入仓库中独立验证脚本的绝对路径，脚本的res://场景/角色继续从实际TodayOff加载的PCK读取；图形探针也须独立，不能继承被排除的res://tools或tests。两目录必须同时满足成功标记与无错误日志，之后同一包资源探针和默认Metal连续移动实际通过，不修改包来塞入开发工具。该失败仅属于验证入口，未计作产品通过；与C4f解析错误共同说明本机退出码需要日志证据补充。

2026-09-30 C4k再次验证：外部包验证新增动态对象的`find_bone`与骨骼位置，使用推断类型发生Parse Error但退出0；显式声明int/Vector3后两目录实际执行到PACKAGED_CAR和PACKAGED_SMOKE_OK，未改变PCK。轮罩修正后主动中断旧套件，以新运行摘要重新执行完整98项；每个日志均晚于冻结清单，且源码结束摘要与包一致。旧候选包和失败照片保留独立身份，不把其检查混入最终版本。源码/包仅部分图片字节相同，逐像素差异另录，不能把近似图像记作完全一致。


2026-10-01 R30实际包复验：`engine_source_sha256`标识签名前原引擎，`artifact-sha256.json`中的`packaged_runtime_sha256`标识签名后包内引擎。首次校验误用前者对签名后文件，失败；改用已有正确字段，签名/PCK/ZIP CRC通过，未修改包。二者不可要求字节一致。源码/包五场景血量和命中相位相同，21图只有20图逐字节一致；首张24像素最大通道差2，原因未测。保留两套图与差异，不因目视相同声称全部像素一致。此哈希边界在当前打包脚本/本机验证一次；完整行为/画面仍须独立检查。详见`docs/evidence/2026-10-01-player-strike/package-integrity.json`。


2026-10-09 NEXT07后台活场景复验：实际包3600次frame_post_draw逐样本增1且窗口守卫通过，再次确认显式绘制应用完成信号而非Engine计数。OS.get_cmdline_args在本机已移除disable-render-loop/fixed-fps等引擎处理参数；用是否包含启动参数判断真实配置会误拒绝合法运行，改用RenderingServer.is_render_loop_enabled并验证缺少关闭参数确实拒绝。性能监视器周期刷新，10步预热后可连续读到启动期3486ms旧值，不是当前帧成本；至少2秒墙钟预热后六组最高8.87ms，并明确记录周期快照及实际预热步数。源码和headless模式不再报告后台FPS。支持tests/performance.gd及docs/evidence/2026-10-09-performance；本机验证一次，GPU零值仍不可用，正常FPS/长期路线保持未验收。


2026-10-09统一候选包7f9a5bca再次复用：先比当前运行输入与此前完整120项来源，再独立核对实际PCK/签名后引擎/ZIP。包外测试仅改res://tests依赖及朋友事件输出目录，游戏res://资源保持包内；七项包检查与五次实际档独立恢复通过。五张包图只有四张与源码逐字节相同，协商图目视可读但差异原因未测，继续保留“相同身份不代表逐像素必同”的边界。详见docs/evidence/2026-10-09-current-package。


2026-10-10最新7264974b包复验：序章、完整12周、朋友三分支、回应、HTTP上下文及四次独立恢复共九项通过，运行输入/PCK前后冻结。包外夹具不能仅替换保存文件路径，还要替换创建目录的同根路径；本轮遗漏后3次res://build创建错误，但exit0/断言0失败，现有日志错误扫描正确拒收。仅修正外部路径并重跑全部九项通过，未改包或断言。此反例再次支持“退出码+成功标记+无错误日志”的组合，适用包内只读资源与外部夹具，不是游戏存档故障。证据：docs/evidence/2026-10-10-core-package-recheck。
