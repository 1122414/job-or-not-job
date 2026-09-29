# 城区植被制作源

2026-09-29从Poly Haven官方API下载。`provenance.json`保存原始URL、作者、CC0许可、上游MD5和本地SHA-256。`.gdignore`隔离影视级原件；游戏仅引用`assets/city_nature`派生文件，无运行时下载。

- `tree_small_02`：Rico Cilliers，原始2K glTF含2,062,487三角形。原glTF叶色JPEG没有透明通道，须保留官方独立alpha PNG并离线合并。
- `leafy_grass`：Charlotte Baglioni，2米扫描范围、2K颜色/OpenGL法线/ARM。包含苜蓿、土壤和枯叶，不当作均匀草坪素材。

来源：[树](https://polyhaven.com/a/tree_small_02)、[草地](https://polyhaven.com/a/leafy_grass)、[CC0许可](https://polyhaven.com/license)。不包括网站示例渲染图、文字或标志。

## 可复现制作

在项目根目录执行；最后两步会更新本项目派生资源，应先保存人工修改再比较结果：

```sh
python3 tools/fetch_open_assets.py --set nature
python3 tools/tree_leaf_components.py
godot --headless --path . --script tools/bake_city_tree.gd
godot --headless --path . --script tools/prepare_city_nature.gd
godot --headless --path . --editor --import --quit
godot --headless --path . --script tests/city_nature_test.gd
```

映射工具仅用Python标准库；制作使用项目同版Godot。每次检查原件摘要和映射摘要，不修改原始文件。叶片按原始连接分组：30,250组全部保留。八类曲面裁切片按UV轮廓生成近/中/远网格，三类管状叶柄使用连通性守卫的减面；改变原件后需重新审查拓扑分类。71顶点类型是裸枝的裁切片，42顶点类型是立体叶柄，不能仅按形状名称或包围盒厚薄分类。

全树自动LOD会删掉独立小叶片；局部自动LOD也可能将叶柄分为两段。制作脚本拒绝断开的候选，再选择保持连通的网格。中远距离减少曲面内部几何，但保留每组轮廓及位置；根部三级统一使用原模型最低点，避免切换时跳动。

`prepare_city_nature.gd`合并叶色/alpha、输出三个运行网格并设置12张2K纹理的VRAM压缩和mipmap；需随后执行Godot导入。运行清单保存原始来源和派生摘要；独立包另附`NATURE-SOURCES.json`。检查实际`Image.is_compressed()`，不能仅凭资源类名判断显存压缩。

正式观感、LOD移动过渡、完整城区性能与玩家签收独立验收，制作成功不代表这些关卡已通过。
