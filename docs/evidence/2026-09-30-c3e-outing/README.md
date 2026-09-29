# C3e 同事进入公共生活证据

最终运行源码`aac2b5e2b6f2c5b52b91ceeee81bd4ea2b827854a94b94d270cd83dc2a48fa43`。全部图片来自当前Godot实际渲染，未修图；完整功能与限制见[验收](../../2026-09-30_C3e同事进入公共生活验收.md)。

- `outing/`：三地点实际E/数字键交谈、不同回应及之后600物理帧的真实返程，9图均已查看；1440×900、2×MSAA、正常玩家相机。初始状态是实际步行生成的到场存档，时钟固定18:30。`render.json`记录连续返程位移和窗口保护，不是普通FPS或独立玩家体验。
- `navigation/people-navigation.png`：实际P键打开、鼠标点击“找到同行的人”，恢复世界并指向同伴，图片已查看。`navigation.json`记录按键和点击结果。
- `career/`：最终源码A/B完整职业与拒绝/协商自动路线的7张阶段图；本轮实际查看`defend.png`、`handover.png`。不把7张全部声明为人工逐张审查。
- `routes.json`：六段实际往返合计744.615936m；每段最大单步低于0.038338m，车辆占地重叠采样0。仅证明这些路线与交通时序。
- `cross-process.json`：三份完成档、六份途中档在独立进程中恢复，完整social字段比较通过。原磁盘档由`tests/city_outing_test.gd`生成到`build/c3e/`；不把临时档作为唯一复现依据。
- `artifact-verification.json`：新独立包的实际TodayOff在项目目录和`/private/tmp`运行均通过；签名、CRC、内外清单、PCK和引擎摘要核验。包保留提交前dirty及构建时not_yet_verified记录，后验收不改写签名内容。

复现入口：`tests/city_outing_test.gd`、`tests/city_outing_save_test.gd`、`tools/render_city_outing.gd`（可加`--navigation-only`）、`tests/full_route_test.gd`和`tools/verify_macos.gd`。包中开发工具被排除，独立包探针必须使用仓库外部脚本的绝对路径。所有图形入口最小化/不可聚焦/禁根输入/鼠标可见。

已观察限制：书屋陈设少，室外晚间人物脸部暗，同伴与主角外观重复；对白仍依赖字幕，正式表情、语音、生活声和整体美术未验收。这些图不支持GTA VI品质或完整30—60分钟自由生活已完成的结论。
