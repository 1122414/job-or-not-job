# 关键人物运行资源

主角、林岚、阿诚的v8派生模型；CC0原始资产、作者声明、摘要和可编辑配方见[制作源](../../../production/characters/cc0-2026-09-29/README.md)。`provenance.json`记录GLB摘要。PNG是Godot从GLB提取的原纹理，`.import`保存压缩/mipmap和场景导入策略，不能只提交GLB而漏掉导入参数。

当前完成资源导入验证，尚未替换游戏里的原型人物。每人10个网格，均有实际LOD索引；材质使用mipmap各向异性过滤，透明裁切边缘使用alpha-to-coverage，保留原裁切阈值。该边缘处理依赖项目现有2×MSAA。逐材质真实贴图总量约24.67/24.67/33.33MiB，包括mipmap，未计GPU驱动和网格开销。

尚未通过的内容：人物美术质量、动态穿插、各体型动画/座位/持物/视线、场景性能。此资源版本不等于GTA VI品质验收。自动LOD减少索引，不减少骨骼/顶点驻留；远景仍需独立骨架和材质简化。

检查：`godot --headless --path . --script tools/audit_cast_resources.gd`；自动回归：`tests/cast_resources_test.gd`。预览必须后台启动`tools/render_character_candidates.gd -- --imported --msaa=1 --source=res://assets/characters/cast`，沿用制作源说明的隐藏不可聚焦流程。
