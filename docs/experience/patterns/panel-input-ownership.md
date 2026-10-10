# 暂停页面的输入归属

信号：主页面独立布尔值导致叠加；普通节点处理 H，而暂停界面承诺 H 可用。
机制：世界节点暂停后不处理输入，UI 状态与暂停状态分散。
处理：GamePanels 始终处理 UI 快捷键，单一 page 映射展示，记录暂停帮助的返回目标；世界节点仍暂停，不通过恢复整个世界解决 UI 输入。
验证一次：tests/panels_test.gd；2026-09-22 实机 Tab→J→H 互斥、暂停H→Esc返回暂停，时间不推进。
边界：游戏场景对话不是暂停页面；后续场景对话减慢时钟必须独立处理。暂停中的背包操作需要显式允许，不能把所有键交还世界。

2026-09-29复用与扩展：R28/R29中手绘HUD文字没有点击对象，GamePanels又在`_input`吞掉鼠标；仅给HUD加按钮不能解决。页面改为Control后，让鼠标与Tab/Enter/方向进入GUI分发，仅保留业务快捷键；通过真实`Viewport.push_input`验证按钮，而非直接emit pressed。返回栈保留“暂停→安排→历史”的父级。当前macOS的默认ui_accept/ui_cancel只有键盘事件，需显式补手柄A/B绑定；方向映射已存在，不重复构造。逻辑检查不代表实体手柄已实测。

宽高比反例：只设置Window.size并断言界面没越界，仍可能测试的是固定16:10内容。`window/stretch/aspect`原为keep，16:9/21:9请求产生相同比例的截图。本轮改expand，同时检查实际逻辑宽高比、保存PNG尺寸；保留初次误标截图。长文本夹具也须先证明高度确实超过滚动区，不能把“没有内容需要滚动”误判成PageDown故障。验证：`tests/page_controls_test.gd`图形通过，见P2页面验收；该结论只适用本项目的canvas_items伸缩配置。

2026-09-29鼠标控制权反例：用户指出自动图形验证抢走鼠标。`OfficePlayer._ready()`无条件CAPTURED，`GamePanels.show_page("")`又重新CAPTURED，因此夹具启动后设置VISIBLE只保护到下一次关页面。修复应删除所有生命周期/页面关闭捕获；只有当前游戏场景、窗口有焦点、Viewport未禁输入、非headless、未指定`--no-mouse-capture`，且玩家主动点击世界画面，才可捕获。激活点击被消费，不穿透攻击；失焦/离树释放，回焦不重抓。`tests/mouse_capture_test.gd`无窗口验证启动/十页面往返/模拟点击/鼠标移动/焦点通知/销毁，0失败；真实人工捕获/浏览器锁定未由这些断言证明。以后自动工具不得置顶、拉前台或为了验证而锁住用户指针；停止测试保留部分证据，不能记成全路线通过。

2026-09-30 C4e复用：新增音量HSlider鼠标工作正常，但四总线Home/End共8项真实输入检查失败；GamePanels在_input里吞掉了未列入放行表的键。仅在暂停页面且GUI焦点为Slider时把Home/End交给控件，最终真实点击与8个键盘端点全部通过，保持暂停和鼠标可见。对应tools/capture_city_audio.gd，未修改世界快捷键归属。

2026-10-09 R04复用：TextEdit/LineEdit输入页必须在GamePanels业务快捷键分发前放行文字键，否则输入N会打开招聘消息。保留Esc/手柄返回，由暂停保证世界不消费动作键。`tests/free_chat_test.gd`实际推送N并断言文字框与页面归属；模型设置与自由输入Metal画面已检查。中文IME组合输入和实体手柄仍未人工验收。

2026-10-09 U01/U02用户纠正：自由输入不能作为独立大页面替代正常现场对话。改为原HUD对话框追加LineEdit/发送/取消，原选项保留为真实按钮；模型回答覆盖显示台词但不覆盖conversation选择数据。聚焦输入时暂停世界、GamePanels将文字键交给GUI，Esc只释放输入；固定选择/切页/结束交谈取消旧请求并释放该暂停所有权。上述R04整页入口已撤换，只有模型设置仍是独立页面。`tests/free_chat_test.gd`覆盖N/W/F/C/数字输入、实际点击发送/取消/选项、Esc和原主线续接；`tools/capture_inline_chat.gd`检查1280×800/720正常及长回复布局，真实中文IME仍开放。

自动点击反例：Control.get_global_rect给的是视口内坐标，root.push_input默认会再做窗口伸缩变换，导致发送按钮无响应；传in_local_coords=true后实际按钮与请求断言通过。保持真实GUI事件，不用emit pressed替代点击来掩盖坐标错误。HTTPRequest.timeout要在request前配置；事后改属性未重置已开始的等待，本轮先设短时限再发请求后超时回退通过。均为本机/本项目验证一次。


2026-10-09 NEXT05-L1/L2：内嵌输入高度跟随正文、选择与非空状态消息，不再固定预留空状态行。两分辨率图形检查还必须覆盖实际换行后的Button矩形及RichTextLabel，不能只比较预估字数。`tools/capture_inline_chat.gd`新增选择两两不相交、回复/选项/输入不相交及真实滚轮；本轮通过一次。`free_chat_test.gd`中文unicode事件通过只证明字符提交，不证明操作系统IME组合/候选窗；这两种证据必须分开。


2026-10-10 INPUT01：E交谈后出现完整暂停菜单。实际Godot4.7.1探针确认桌面web=false但WebSupport.is_processing=true：_enter_tree内set_process(false)会在进入ready阶段时被脚本回调启用覆盖。网页autoload随后将HUD对话主动释放鼠标误当成浏览器意外失锁，show_page("pause")又清掉conversation。将set_process平台开关移至_ready，并在_process加平台防线；网页指针状态逻辑也排除现有对话/自由输入的主动释放。

以往很多测试只root.add_child(game)，不设置SceneTree.current_scene；这个autoload因此直接return，无法观察该故障。`tests/interaction_menu_test.gd`先完成隔离场景初始化（persistence=false），再设current_scene并使用真实Viewport E事件，合成“上一帧曾捕获”的采样变量，不实际捕获桌面鼠标。旧版2断言失败，修复后通过一次，覆盖连续E、长按、菜单返回、自由输入、Esc及桌面回调防线。网页初始菜单/意外失锁/主动交谈/交谈结束仅用状态样本验证，不能视作真实浏览器指针锁体验。

适用范围：带自动处理回调的节点在_enter_tree禁用处理，以及依赖current_scene的autoload与普通隔离测试不一致。先实测生命周期，不把所有E误触都归为按键冲突；本例无需修改E或Esc映射。

INPUT01最终复验：02263fe通过八项相关回归及实际包E/页面/聊天恢复/启动检查；平台及生命周期机制源码和包均验证，真实浏览器人工锁定仍开放。

2026-10-10 FB10-03：简历面试新增独立PanelContainer，初版聚焦LineEdit后暂停世界，但容器继承了可暂停CanvasLayer，导致按键不进入输入框。将控件分支设PROCESS_MODE_ALWAYS后，真实N键及中文字符事件通过，同时保持世界暂停与快捷键隔离。resume_interview_test复用真实回环HTTP验证输入后评估；字符事件不代表操作系统IME候选验收。
