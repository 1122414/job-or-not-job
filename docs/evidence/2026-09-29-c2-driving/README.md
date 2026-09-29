# C2a 驾驶与街道交通证据

2026-09-29。运行源码 d63424b90895567bc69ee9b89f428eab7d58eaa7bc203e6d97d59a470c99059a；构建基线780867f含已记录的未提交修改。实施提交01b4ea4，提交后运行摘要一致。对应[验收](../../2026-09-29_C2a驾驶与街道交通验收.md)。

- car_office/car_homes：两处共享车及停车位。
- driver-seat：主角正常驾驶坐姿；driver-turn-left/right：实际双向转向掌面与方向盘。
- driving-camera：真实Viewport W输入后第三人称镜头；driving-map、driving-map-vehicles：地图、滚动与两辆车入口。
- traffic-bus-queue：两辆车在真实公交后停止。
- before-driver-seat：首次休息坐姿的手臂穿出车门反例，已查看，不能作为当前状态。
- render.json：隐藏NO_FOCUS子视口、鼠标可见与实际输入结果。9张最终PNG均已逐张查看。
- checks.json：58项Godot/24项Python、定向地图、两目录包内探针、来源身份/签名/ZIP、各PNG摘要。另含隐藏完整图形路线步骤与0失败结果。

生成工具 `tools/render_city_driving.gd`；根窗口隐藏、不可聚焦，根输入禁用，只有显式模拟事件送入子视口，不抢鼠标。保留实际玩家更新，不能用静止模型姿态替代游戏行为。既有 makehuman、角色与动作来源继续沿用；新车为程序几何原型。

画面证明驾驶/坐姿/车流和页面已接入，仍明显存在方盒车体、建筑占位和稀疏街景。转向时手掌可达不等于自然换手、手指包覆、整段进出车演出或GTA品质通过；未声称完成正式美术或FPS验收。
