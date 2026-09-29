# S2 形变与衣装修复证据

日期2026-09-29，基线源码3f9b349；候选v2→v8，运行时未替换。详情见[验收表](../../2026-09-29_S2人物形变与衣装缺陷修复验收.md)。

- `candidates.json`：最终三人配方、GLB摘要、面数、材质、衣物删面数。
- `inspection.json`：Godot最终结构检查0失败；`fitting.json`：导出GLB每人43表情状态、151,188表面采样，0失败。
- `fitting-v2/v4/v6/v7.json`：原版与返工反例，不能当作最终结果。v2三人共904负骨骼权重，v8为0。
- `validation.json`：验证边界、图片摘要、来源及重复生成结果；50项Godot/23项Python通过。
- 36张最终图片：三人正侧背、中性、blink/raise/lower/mouth端点、半张口、0.75皱眉、组合frown和侧向张口；均已查看。工具实际生成78图，其他42张仅生成未逐张签收。
- 3张`diagnostic-flat-*`：v2平涂定位，身体绿、衣服蓝、鞋袜黄、眉毛红、其他紫；不是最终材质。

机位与灯光使用`tools/render_character_candidates.gd`固定定义，900×1000、FOV32、Compatibility/M5 Pro；扩展脸部机位在同工具。后台`open -g -n`启动，根窗口隐藏且NO_FOCUS，不运行main场景；最终日志78图、pointer_visible=true。图片没有后期修饰，原问题对照在[上一阶段](../2026-09-29-s2-character-pipeline/README.md)。

已消除本轮取样中的眉片穿插、原张口红面和鞋裤白色穿出；发丝/睫毛颗粒、皮肤/衣料质感仍待制作。静帧和数值不能代表正式动态、S1实景或独立玩家验收。
