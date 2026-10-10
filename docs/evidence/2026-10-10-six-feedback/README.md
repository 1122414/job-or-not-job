# 本轮证据

`home-minimap.png`、`home-map.png`、`mentor-body.png`来自tools/render_feedback_oct10.gd后台SubViewport，1280×800，兼容渲染器、Dummy音频，未接管指针。已目视复核。

阶段一：vehicle_escape旧基线4个失败（司机1、导师三朝向3）；增加真实紧贴司机条件后旧转向控制又复现倒退1失败。最终专项与十项相关回归退出0、failures=0且无ERROR。具体命令和边界见上级六项反馈验收。玩家存档只读取位置关系，没有复制完整存档到证据中。
