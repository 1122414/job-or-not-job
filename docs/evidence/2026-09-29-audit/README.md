# 2026-09-29 当前源码审查证据

源码基线：`main / 3113a91`。本目录为原始游戏画面与定向检查记录，无后期修图。对应[问题审查](../../2026-09-29_GTA6品质差距全面审查.md)及[开发纲要](../../2026-09-29_GTA6级品质开发纲要与实施路线.md)。

## 环境与隔离方式

Godot `4.7.1.stable.official.a13da4feb`，macOS / Apple M5 Pro，Compatibility，1280×800。所有图形夹具通过 `SceneTree` 实例化场景但不设为 `current_scene`；本项目据此不启用正式存档，补充夹具另断言 `persistence_enabled == false`。不以夹具预置状态冒充正常玩家的进度。默认受限图形进程曾无日志退出134；正常图形权限下成功运行，不将启动权限失败登记为游戏缺陷。

已在隔离B预览窗口操作候场E、数字1落座、J页鼠标点击、H帮助和关闭；不是完整职业线自主试玩。图形脚本捕获与实际GUI观察互相佐证。捕获后已关闭本轮预览。

## 截图清单

| 文件 | 内容与方法 | 判断边界 |
| --- | --- | --- |
| [street.png](street.png) | 现有 `tools/capture_views.gd`，A入口 | 固定视点，不代表连续走入 |
| [office.png](office.png) | 同夹具，A入口内侧 | 环境、人物与遮挡 |
| [work.png](work.png) | 同夹具，预置A工位状态 | 工位构图与页面 |
| [interview.png](interview.png) | 同夹具，A候场后坐下 | 面试空间与构图 |
| [interview-b.png](interview-b.png) | 补充夹具，B落座；断言已坐下 | 普通面试视点 |
| [interview-b-action.png](interview-b-action.png) | 补充夹具，B手机段落150物理帧后 | 手机已举起；不是整段自然度证明 |
| [street-reverse.png](street-reverse.png) | 补充夹具，反向街道 | 有夹具残留提示，不记成正式流程缺陷 |
| [ui-journal.png](ui-journal.png) | 事项页 | 默认/未入职内容 |
| [ui-bag.png](ui-bag.png) | 背包页 | 空包，未测满包边界 |
| [ui-people.png](ui-people.png) | 人物页 | 默认人物资料 |
| [ui-messages.png](ui-messages.png) | 招聘消息 | 默认消息，不代表长期列表 |
| [ui-promises.png](ui-promises.png) | 约定页 | 默认内容 |
| [ui-history.png](ui-history.png) | 历史页 | 默认内容 |
| [ui-ledger.png](ui-ledger.png) | 工资页 | 默认内容 |
| [ui-help.png](ui-help.png) | 帮助页 | 默认尺寸末行超出深色底板 |
| [ui-pause.png](ui-pause.png) | 暂停菜单 | 真正Control按钮，与手绘页不同 |
| [ui-computer.png](ui-computer.png) | 预置职业阶段并打开电脑页 | 背景仍在街上，只评价页面；不登记街上办公缺陷 |

共17张。补充夹具暂停世界、等待4个处理帧后 `RenderingServer.force_draw(false)`，保证页面提交后再取图。它改变状态只为取证；不能用其时间、位置和字幕组合证明正常流程故障。PNG尺寸与SHA-256见[manifest.json](manifest.json)。

## 实际验证结果

[checks.json](checks.json)保存四项已执行检查的退出码和结果摘要。均在当前源码上执行，没有本轮修复前后对比，也没有本轮全套43项通过的声明。

| 检查 | 退出码 / 结果 | 能证明的范围 |
| --- | --- | --- |
| `panels_test.gd` | 0 / `PANELS_TEST failures=0` | 页面状态与输入互斥；未断言文字几何范围 |
| `interview_performance_test.gd` | 0 / `INTERVIEW_PERFORMANCE_TEST failures=0` | 动作、骨骼位移和道具状态；接触阈值仍粗 |
| `work_projects_test.gd` | 0 / `WORK_PROJECTS_TEST failures=0` | 工作资料、预览与交付相关状态 |
| `full_route_test.gd` | 0 / `FULL_ROUTE_TEST failures=0` | 脚本路线连续状态；本轮此检查为headless，不冒称真人完整试玩 |

图形短测实际输出见[performance.json](performance.json)。每组600帧，正常/混乱各一轮；预热按现有 `tests/performance.gd`。没有CPU/GPU归因，没有跨设备测量，不将与旧记录的差值归因为某次提交造成回退。

| 场景 | 平均FPS | 平均帧时间 | P95 | P99 |
| --- | --- | --- | --- | --- |
| 正常 | 50.82 | 19.677ms | 23.219ms | 25.533ms |
| 混乱 | 44.69 | 22.377ms | 25.901ms | 27.981ms |

## 复现命令

从项目根目录执行；`godot`须解析到上述版本。图形取证/性能命令需要正常图形会话，不使用 `--headless`；测试命令使用headless。重新捕获时建议指定新的日期目录，保留本次原始证据。

```sh
godot --path . --script tools/capture_views.gd -- --output=res://docs/evidence/2026-09-29-audit
godot --path . --script tests/performance.gd
godot --headless --fixed-fps 60 --path . --script tests/panels_test.gd
godot --headless --fixed-fps 60 --path . --script tests/interview_performance_test.gd
godot --headless --fixed-fps 60 --path . --script tests/work_projects_test.gd
godot --headless --fixed-fps 60 --path . --script tests/full_route_test.gd
```

补充取证脚本运行于 `/tmp/job-audit-capture.gd`，未加入游戏代码。以下保留本轮原文，复现时保存到临时路径、创建输出目录并修改 `output`，运行 `godot --path . --script /tmp/job-audit-capture.gd`。该脚本只支持本次源码结构，不是长期测试接口。

```gdscript
extends SceneTree
var game
var output := "res://docs/evidence/2026-09-29-audit"
func _initialize(): call_deferred("run")
func snap(label: String):
	paused=true
	for i in range(4): await process_frame
	RenderingServer.force_draw(false)
	var error=root.get_texture().get_image().save_png(output.path_join(label+".png"))
	if error!=OK: push_error("capture "+label); quit(1)
	print("AUDIT_CAPTURE ",label)
func run():
	root.size=Vector2i(1280,800)
	root.set_disable_input(true)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	for i in range(15): await physics_frame
	assert(not game.persistence_enabled)
	game.player.position=Vector3(-14,0,5)
	game.player.yaw=0
	game.player.pitch=-0.08
	for i in range(5): await physics_frame
	for page in ["journal","bag","people","messages","promises","history","ledger","help","pause"]:
		game.panels.show_page(page)
		await snap("ui-"+page)
	game.panels.show_page("")
	for action in ["interview_hr","interview_lead","interview_boss","join_a","brief","data"]: game.career.apply(action)
	game.panels.show_page("computer")
	await snap("ui-computer")
	game.panels.show_page("")
	SaveGame.restore(game,game.initial_state.duplicate(true))
	game.interviews.schedule("interview_b")
	game.interviews.sessions.b.call_stage="room"
	var host=game.npc_for_role("b_hr")
	host.position=OfficeRooms.INTERVIEW_HOSTS.b
	game.player.position=OfficeRooms.INTERVIEW_SEATS.b
	game.speaker=host
	game.interviews.handle("interview_seat_b")
	for i in range(90): await physics_frame
	assert(game.player.seated)
	await snap("interview-b")
	paused=false
	game.interviews.sessions.b.step=2
	game.conversation=game.interviews.question("b")
	for i in range(150): await physics_frame
	await snap("interview-b-action")
	game.panels.show_page("")
	SaveGame.restore(game,game.initial_state.duplicate(true))
	game.player.position=Vector3(0,0,11)
	game.player.yaw=PI
	game.player.pitch=-0.06
	for i in range(30): await physics_frame
	await snap("street-reverse")
	paused=false
	game.queue_free()
	for i in range(3): await process_frame
	print("AUDIT_CAPTURE_COMPLETE persistence=false")
	quit()
```

## 未完成与来源边界

独立玩家、音频主观混音、完整战斗手感、长列表、窄窗口、大字、控制器、全天日程、多硬件、长期存档和最终美术样板均未验收。官方[GTA VI截图目录](https://www.rockstargames.com/VI/media/screenshots)能读取，但大图CDN请求失败、页面大图为空；未完成官方原图逐帧对照。上述缺口已经进入开发纲要G0—G8，不把未测写成通过。

## 文档交付核验

2026-09-29已核对指定6份文档的64个本地链接，缺失0；21组问题（R09/R15合为一组，共22个编号）在工作包表和定向验收表中全部有覆盖；17张PNG均为1280×800且与manifest校验一致；人周合计、20%预备金与示例人力成本算式一致。`git diff --check`通过。当前修改只涉及文档和证据，不修改游戏实现。
