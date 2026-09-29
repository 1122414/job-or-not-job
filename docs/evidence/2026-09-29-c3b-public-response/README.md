# 公共救助与现场处置证据

日期2026-09-29，实施11a9ce0。详细问题、预期/实际测试和限制见[C3b验收](../../2026-09-29_C3b公共救助与现场处置验收.md)。

- response-station：常驻小组及实体接收场所。
- scene-report：倒地姿态完成后的真实E/数字求助，保留角色死亡事实；before-report是过早截取倒地中途及文案包含实现说明的反例。
- crew-arrival、scene-assessment、scene-transfer、return-through-city：小组实际从站点沿路到场，现场评估后转运，车辆在路口停线。
- station-received：到站150物理帧后身体仍在实体床上，小组离开；不以隐藏或复活代替清理路口。
- response-map：场所/小组标记和实际服务状态。

八张最终图及一张反例均已逐张查看。最终图来自build/c3b-response-delivery，反例来自build/c3b-response-checked。原始伤亡位置和观察相机是取证夹具，救助人员连续实际移动；不能称作独立玩家从公司起点游玩。当前画面仍存在方块环境、通用人物与握持/侧卧/抬放表演不足，未通过正式视听签收。

render.json记录窗口真实状态：root_hidden=false、root_minimized=true、root_unfocusable=true、root_focused=false、pointer_visible=true。初轮hide和初始化最小化单独设置均没有满足要求，后来改为启动及deferred入口两次设置；诊断见window-diagnosis.json。不要把最小化改写成隐藏。

checks.json保存66项Godot、24项Python、19种坏档/15版本、补强定向及四条实际路线结果和日志摘要；全部最终检查0错误/警告。图形/完整公司路线使用dc973533，最终包3c1b9267只多一条评估距离合法性检查，无场景/动画改动。全套之后的补充已单独定向和实际包验证，未声称重新跑过最终源码全套。

build-manifest.json和artifact-sha256.json保持提交前构建的真实身份与dirty标记；package-verification.json记录最终TodayOff在项目与/private/tmp实际启动、28人物/转运JSON、签名与ZIP CRC通过，玩家持久化禁用。运行源码摘要在实施提交后与包仍一致。没有最终双画质性能、跨区或独立玩家结论。
