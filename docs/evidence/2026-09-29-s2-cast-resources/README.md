# 人物导入证据

`resources-before/after.json`来自实际导入PackedScene材质和RenderingServer网格。纹理Image记录真实格式、压缩、mipmap及字节；LOD记录每级误差和三角形数量。

8张PNG是实际已查看的同位对比：前2脸、后3脸和3全身。两组均900×1000、FOV32、2×MSAA、相同灯光，后台隐藏NO_FOCUS视口，不运行游戏、不锁鼠标。完整输出各24张留build，但未逐张查看不能算全部验收。

使用工具`tools/audit_cast_resources.gd`、`tools/render_character_candidates.gd --imported --msaa=1`和`tests/cast_resources_test.gd`。GLB身份见`assets/characters/cast/provenance.json`，与已验证v8相同。美术、LOD切换、动态与实景性能仍开放。
