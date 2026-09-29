# 中心街段建筑源

Poly Haven 的 [Modular Urban Apartments Facade](https://polyhaven.com/a/modular_urban_apartments_facade)，James Ray Cock，CC0-1.0。许可：https://polyhaven.com/license。Powered by Poly Haven。

`provenance.json`记录官方API返回的来源、作者、原件MD5/SHA256与独立玻璃alpha。原始glTF/二进制/贴图保留，`.gdignore`隔离整个制作目录。

重建顺序：

1. `python3 tools/fetch_open_assets.py --set architecture`：核对已有文件，摘要不同即拒绝覆盖。
2. `godot --headless --path . --script tools/prepare_city_architecture.gd -- --textures`。
3. `godot --headless --path . --editor --import --quit`。
4. `godot --headless --path . --script tools/prepare_city_architecture.gd`。

制作工具会更新本项目派生文件，须在版本控制中审核差异。仅导出三种直线窗墙模块和十张实际使用纹理；保留源UV/法线/切线，将共同开间原点x增加1.5m。源节点的位置是模块库展示偏移，不作为建筑装配位置。玻璃JPEG无alpha，合并同源独立透明度；ARM通道分别为AO/粗糙度/金属度。源库未使用的trim_02不进入运行材质。

上层房间深度仅服务窗景，没有新增可进入室内或可玩面积。资源技术检查不等于GTA VI品质或整城性能验收。
