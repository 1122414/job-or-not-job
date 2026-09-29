# C1 城区与公交证据

日期：2026-09-29。运行源码摘要与构建身份见 `verification.json`。

- `district-overview.png`：首个连通区域总览，明确仍是空间原型。
- `office-platform.png`、`market-street.png`、`residential.png`、`waterfront.png`：四区实际视图。
- `bus-passenger.png`、`passenger-camera.png`：实际玩家物理/姿态更新下的乘车与正常玩家镜头。
- `city-map.png`、`bus-controls.png`：真实 Control 页面。
- `counterexample-fixture-standing.png`：首轮预览关闭玩家物理，站姿不证明游戏中的实际乘车姿态。
- `counterexample-office-pose.png`：恢复玩家更新后发现原坐姿为 work，已经改用休息坐姿。
- `image-sha256.json`：上述 11 图摘要。最终 9 图逐张查看，非专业美术或自由玩家体验签收。
- `verification.json`：56 项 Godot、24 项 Python、源码/包身份及包内四站/乘车恢复验证；图形路线另记结果。

图形仅使用 `open -g -n` 后台启动、隐藏不可聚焦根窗口和显式更新子视口。不捕获鼠标；禁止用截图生成速率冒充游戏帧率。新环境仍缺真实密度、材质/灯光、公共活动和交通声景，宏观目标继续开放。
