# 骨架适配与待机交谈证据

日期2026-09-29，起始提交f026c67，包含本阶段运行时修改。[阶段验收](../../2026-09-29_P1骨架适配与待机交谈验收.md)明确范围和未完成项。

- `casual/office/office_female_<idle/talk>_<0/33/66>.png`：三套人物、两动作、三相位，共18张。固定近景用于骨骼和网格检查，不是玩家默认镜头。
- `casual_<idle/talk>_before.png`：原程序曲线对照，同位近景；只补了静止重置轨，不是新动作。
- `retarget-report.json`：全身制作预览六片段×三套人物×61样本，检查有限值/局部骨长，记录踝高度，不证明地面/椅面/物体接触。
- `animation-provenance.json`：运行时两段烘焙摘要、原件镜像版本、目标GLB摘要、采样率/循环接缝。
- `checks.json`：全套46项Godot、8项Python及定向检查、重建和制作工具反例，PNG摘要。
- `build-manifest.json`、`artifact-sha256.json`、`package-verification.json`、`packaged-menu.png`：独立包身份、验证和截图。

三套衣装当前共用同一骨架，不当作三种体型验收。人物面孔、表情、衣服/鞋边仍是原型质量；两个片段替换不能代表全部20动作、GTA品质或独立玩家接受。

- `profile-*.json`、`performance-summary.json`、`performance-table.md`：双公司/双渲染器共24样本，同先前600帧/预热60帧夹具，保存源码身份与原始帧时间。仅原型短测，GPU全零视为不可用。
- `route/`：本轮正常渲染连续路线七张阶段图；原历史证据没有覆盖。
