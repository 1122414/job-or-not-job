# 图形取证窗口的启动覆盖

信号：工具在_initialize调用root.hide后，最终root.visible仍为true；运行中再次隐藏报“Can't change visibility of main window”。用户已明确要求自动开发不得抢前台或鼠标。

2026-09-29本机Godot4.7.1观察：C3b首轮八张图可以生成，但根窗口隐藏状态不成立。运行中hide被引擎拒绝；仅在_initialize设置最小化仍被启动过程覆盖。此前步骤中的根窗口状态不能据此写成隐藏成功。

处理：初始化时通过Window和DisplayServer设置不可聚焦；在首次deferred run之前再次设置最小化，关闭根输入，仅将合成事件送入SubViewport。取证开始检查最小化/不可聚焦/鼠标可见，结果记录实际root.has_focus和窗口模式。不要改游戏的玩家主动鼠标接管规则，也不要通过激活窗口来截图。

支持案例：tools/render_character_candidates.gd的background_run，tools/render_city_response.gd的窗口断言和八阶段图；最后一次观察root_minimized=true、root_focused=false、pointer_visible=true。tests/full_route_test.gd采用同样启动顺序。仅本机当前引擎验证一次；其他平台需重新测原生窗口行为。最小化与隐藏不同，证据分别记录，不替换历史事实。
