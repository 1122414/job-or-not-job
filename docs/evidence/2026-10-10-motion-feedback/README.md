# MOT01—03 证据

范围：车辆碰撞、抢车持续动作、休息昼夜过场。见[验收](../../2026-10-10_碰撞抢车休息演出修复验收.md)。

- `package-checks.json`：真实不可变PCK的四项测试、离屏取证、源码/PCK/签名/ZIP CRC。
- `package/render.json`：实际包图形帧对应动作位置、推车位移与NO_FOCUS/最小化/鼠标可见状态。
- `entry-contact.png` / `rest-contact.png` / `impact-contact.png`：连续帧摘要；普通镜头另记。
- `takeover.mp4` / `collision.mp4` / `rest.mp4`：由实际包运行帧编码的抽样连续视频，摘要在`clips.json`；完整原始PNG序列保留于忽略构建目录`build/motion-feedback/raw-frames/`。选定PNG与接触表直接来自离屏渲染，不是概念图。

状态专项：`tests/vehicle_motion_test.gd`、`tests/rest_transition_test.gd`。旧日历业务用例通过真实Esc跳过新的展示继续执行；动画专测没有跳过持续时间。

图形采用脚本夹具固定初始位置，不代表自然玩家长时间试玩。用户人物资产制作脚本及用户当前前台窗口未改动。普通玩家镜头另有`normal-entry-contact.png`，已查看。实现提交9f5f7a8。suite-checks.json记录累计124项的枚举、初次失败和执行时序；final-traffic-checks.json记录冻结最终输入的三项复验。Markdown/JSON/关键PNG随项目文档同步，MP4在本仓库保留。
