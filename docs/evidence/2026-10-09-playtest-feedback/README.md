# 2026-10-09 玩家反馈与效果方向

combat-directions.png 是内置imagegen生成的概念示意，并非实机截图。用户选择C漫画夸张；保持蓄力→接触→收势，真实命中才发爆点，真正击倒才发KO，不盖字幕，尚未由概念确认推导动作实现完成。

生成提示：以用户蓝衬衣主角/路边车截图为环境与颜色参考，制作A克制写实/B轻度街机/C漫画夸张三列九格方向板；展示挥拳与举起纸箱摔砸的蓄力、接触、收势，保持自然身体比例与现有游戏观感，分别比较灰尘、冲击环、轨迹/漫画爆点与KO大小。标题“打击与摔砸 · 效果方向讨论”，副标题“概念示意，非实机效果”；无血腥，不把它呈现为已实现画面。使用内置工具，未使用CLI或新增API依赖。

初始复现：隔离场景把倒地居民放在车体下，60帧油门后车辆位置(0,0,64)不变、speed=0、blocked=true。该夹具的救助重叠只产生0.000857m垂直偏移、存档仍有效，因此不能据此断言玩家Invalid data一定由高度引起。用户磁盘当时可用358GiB；已保存的v26文件仍可解析，当前未保存世界的具体非法字段须进一步诊断。

## 已验证实机内容

- `runtime/high-speed-impact.png` / `save-status.png`：真实车体接触抛离与独立保存状态提示。
- `runtime/rescue-assessing.png` / `rescue-transporting.png`：站棚救助的实际评估和转运。
- `runtime/take-traffic_0.png` / `take-bus_101.png`：真实E目标/公交接管按钮进入驾驶，司机离车；图形脚本同时断言接管后解除暂停。
- `runtime/comic-punch.png` / `comic-slam.png` / `comic-ko.png`：真实碰撞判定生成的C方向字效和爆点，非imagegen。测试为保持可重复性冻结目标AI；画面是命中瞬间，不证明被击者完整倒地过程。
- `before-motion` / `after-motion`：主角现有模型步行/跑步四相位；`locomotion-route`为普通玩家镜头的6段连续输入及route.json（23.15885m，最大步长0.09167m，无玩家存档读写）。

图形均由最小化、不抢焦点窗口与独立SubViewport生成，使用正常引擎资源；固定FPS自动输入不是正常游玩帧率测量，也不是独立玩家体验验收。最终113项Godot/34项Python、包综合及三专项均通过；regression-results.json、package-probes.json、package-integrity.json与packaged-locomotion/verification.json记录实际结果。

玩家现有v26存档另经只读隔离恢复：v27世界运行120物理帧后全档有效，测试前后原文件SHA256一致、persistence=false；未在证据目录复制私人存档内容。这不代表截图当时的未保存状态已取回。


最终包候选：`20261009T033244602920Z-6723eb45-fee40d95`；实际运行输入SHA256为`fee40d95f16d0ab7589123b210ea934be03c2b16b9c4b487db80c76410a09799`。构建时基于6723eb45加未提交修复，manifest如实记录runtime_dirty；以完整运行输入及PCK摘要校验，不把旧提交号当最终代码。候选c4cd5ebc已被替代，最终验证状态以package-*和验收表为准。
