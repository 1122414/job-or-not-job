# C4g 昼夜光照、渲染后端与独立包证据

日期：2026-09-30。对应[阶段验收](../../2026-09-30_C4g完整城区昼夜光照验收.md)。`before-source.json`为07307d65，`final-source.json`为54ef9da4。所有最终图形、三轮指标、路线和独立包均对应后者；程序化光照固定夹具与自然移动证据分别记录。

## 图形

共归档74张原图，36张实际查看；逐图SHA-256及查看状态见`image-sha256.json`。不把归档数量当作逐张视觉审核。

- `before-compat` / `before-metal`：各7张原始光照代表图及完整22视角元数据。
- `final-metal`：22张完整城区同位图；macOS默认后端，无命令行renderer覆盖。618组实际非空GPU批变换、23树位在重建中一致。
- `final-compat`：保留7张回退后端代表图及完整22视角元数据。
- `evening`：11张正常玩家镜头/相处过程，实际E和三种回应通过。到场状态读取此前真实自然行走的存档，玩家靠近位置为交互夹具。
- `walk`：9张连续玩家输入路线图、145.501313m与逐路点/时间；实际打开/合上图册。
- `career`：7张完整双公司职业路线图。
- `package`：通过实际TodayOff从项目外启动的3张默认Metal图形，`verification.json`记录包身份、actual renderer与桌面保护。
- `iteration`：首版Filmic过亮的中心步道反例，非最终版本。

固定照明对照把三位同事放在既有场所并冻结其他角色；部分人物相互重叠、处在原步行动作中。这些夹具只用于一致照明比较，不作为自然站位、人物动画或正式体验的通过证据。完整城区和GTA VI目标未完成。

| 观察 | 原版 | 最终默认Metal |
| --- | --- | --- |
| 花园夜间 | [原图](before-compat/garden-night.png) | [同位图](final-metal/garden-night.png)、[实际交谈](evening/a_group-encounter.png) |
| 黄昏 | [原图](before-compat/garden-dusk.png) | [余晖](final-metal/garden-dusk.png) |
| 中心步道 | [原图](before-compat/central-walk.png) | [最终](final-metal/central-walk.png)、[正常玩家镜头](walk/route-0.png) |
| 公司A | [原图](before-compat/company-a.png) | [白天](final-metal/company-a.png)、[夜间](final-metal/company-a-night.png) |
| 书屋晚间 | [原图](before-compat/bookshop-evening.png) | [最终](final-metal/bookshop-evening.png)、[实际交谈](evening/a_friend-encounter.png) |

## 指标与包

`profile-before/final-compat/metal.json`保存四组原始数据；`profile-summary.json`仅汇总，不改变源数据。九视角×三轮×30个记录样本；每样本实际完成信号增量1。GL总完成信号1080、Metal2159，含采样窗口外信号，不据总量推算帧率。GPU计时全0为不可用。冻结离屏提交与正常运行FPS、CPU/GPU全帧耗时严格分开。

默认Metal并非所有视角都更快，中心步道约比最终GL慢1.25ms；夜间停止太阳阴影也降低了GL成本。图形比较保留后端地表/反射差异，不宣称逐像素相同。

`package-identity.json`记录内外清单、PCK、输入引擎、签名后引擎与ZIP摘要，以及签名/CRC检查。包为`build/baselines/20260929T204542764289Z-b3fcacc5-54ef9da4/今天不上班-macOS-0.5.0.zip`，ZIP SHA-256：`f922d0e153431cf2e283b9f36ad20001b6653b67a1a9906f898cb1c6f8bce8f9`。

原始构建标记dirty/not_yet_verified保留；后验收单独记录。两次完整包探针均使用实际TodayOff启动器，分别从项目根目录和/private/tmp运行；persistence=false。图形工具最小化、不可聚焦、鼠标可见、禁根输入、Dummy音频，没有抢前台或写玩家档。

## 验证边界

最终汇总见`verification.json`：83项Godot本次连续执行通过，每项测试文件/日志摘要与成功行已保存，导入及启动日志无错误；30项Python通过的执行结果另标原始日志未保留。所有图形工具显式使用新输出目录，旧证据、旧包及玩家档保持。双画质各三轮20分钟、独立玩家30—60分钟、正式视听与整城面积验收仍开放。
