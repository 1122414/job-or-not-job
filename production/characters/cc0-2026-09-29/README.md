# 双公司关键人物制作源（候选）

这批文件用于 S2 候选制作，尚未代表正式人物验收。`source/` 是 MakeHuman 官方 CC0 资源包及官方仓库固定提交的未修改选择集；`provenance.json` 保留包 URL、摘要、Git 提交及每文件摘要。原始 `.mhclo/.mhmat/.target` 带 CC0 与作者声明，完整许可为 `source/LICENSE.ASSETS.md`。不包含 MakeHuman 应用程序，不把其 AGPL 应用许可误标为资产许可。

`recipes.json` 是可编辑设计源：主角、林岚和阿诚分别选择体型/脸形/发型/衣装，保留角色设定理由。衣服、眉毛和睫毛通过原始重心映射贴合新网格；四个面部形变为眨眼、抬眉、皱眉和张口。眼球另绑定左右眼骨，提供视线接口；没有对白时不应循环张嘴。

从仓库根生成候选（仅输出 build）：

```sh
python3 tools/build_character_cast.py production/characters/cc0-2026-09-29/source production/characters/cc0-2026-09-29/recipes.json build/character-candidates
```

`.gdignore` 将制作源排除于 Godot 导入与运行时包。旧三人物文件不因生成候选被覆盖。正式接入前还需查看中性光正侧背、脸部与表情、衣发穿插；按各体型重新核验骨架/上半身动作/座位与手物挂点，并补 LOD、导入压缩与性能。候选网格在这些关卡通过前不能称为正式 GTA 品质人物。

2026-09-29实际复核：第二轮结构检查通过、24张预览均已查看，但外观未通过。已修复眼球透明外层遮住虹膜、材质跨目录解析及衣装方向；眉毛尖角/穿插、张口破面和缺口腔资产、鞋裤接缝、发边/皮肤材质仍需制作。当前不得用于正式替换。详细反例见[候选复核](../../../docs/2026-09-29_S2人物制作管线与候选复核.md)。

无窗口结构检查：

```sh
godot --headless --path . --script tools/inspect_character_candidates.gd -- --source=res://build/character-candidates
```

macOS 后台图片输出（必须使用后台启动；工具隐藏根窗口，不运行游戏、不锁鼠标、不置顶）：

```sh
open -g -n -a /Applications/Godot.app --args --path "$PWD" --disable-render-loop --script tools/render_character_candidates.gd -- --no-mouse-capture --source=res://build/character-candidates --output=res://build/character-candidate-images
```

每次复核使用新的输出目录以保留前次反例。单独视口生成速度不代表游戏帧率，图片不代表动态转身/接触/体验验收。
