# 街道首层设施来源与重建

四项资源来自 Poly Haven，均为 CC0-1.0，允许商用和再分发；Powered by Poly Haven。原页、作者、官方许可、原件大小/MD5/SHA256均记录在 `provenance.json`。原件合计39,372,539字节，`.gdignore`将制作源与运行资源隔离。

| 资源 | 作者 | 原页 |
| --- | --- | --- |
| 素色卷帘门 | MP | https://polyhaven.com/a/rollershutter_door |
| 周转箱 | PierreB3D | https://polyhaven.com/a/plastic_crate_01 |
| 盆栽 | Rico Cilliers | https://polyhaven.com/a/potted_plant_02 |
| 壁灯 | Kuutti Siitonen | https://polyhaven.com/a/industrial_wall_lamp |

重建顺序：

1. `python3 tools/fetch_open_assets.py --set street`，已有原件不匹配时拒绝覆盖。
2. `godot --headless --path . --script tools/prepare_city_street.gd -- --textures`。
3. `godot --headless --path . --editor --import --quit`。
4. `godot --headless --path . --script tools/prepare_city_street.gd`。

运行目录为 `assets/city_street/`。仅选素色卷帘门，排除涂鸦展示变体；保留植物三部分原始相对平移；叶片和灯罩JPEG另合并同源独立alpha，保留ARM通道。十九张实际纹理中门用2K，其余用1K，实际VRAM压缩和mipmap另由定向检查确认。

运行三角形：门552，箱10,206，植物12,408，灯4,446。植物土壤由53,930降至420、盆体5,184降至1,296，叶片10,692完整保留；箱18,320降至10,206。箱的源UV接缝/孔洞限制自动减面，25—180度法线合并诊断都不能降至原拟8K目标；未虚构达标或抹去孔洞。其运行网格没有额外自动LOD，十个场景实例按32米单元批次、70米可见距离控制；其他三资源具有自动LOD。减面仅降低索引，不声称已降低全部顶点驻留。

壁灯壁面基准是源z=0、朝+Z，不能按AABB底部当壁面；每个实际GPU实例须命中背后支撑体。灯光由现有昼夜系统控制，源100倍发光强度未直接带入城区。贴图、网格和物理安装通过不等于正式艺术签收，商店门面也不代表新增可进入商店或营业系统。

玻璃限制：灯罩保留源alpha/法线/粗糙度，但源KHR_materials_transmission未在当前StandardMaterial中等价重建。斜视灰块在关闭LOD后图像相同，未归因为减面；正式透射与近景观感仍需制作验证，见项目未解决体验记录G05/G06-C4i-B。
