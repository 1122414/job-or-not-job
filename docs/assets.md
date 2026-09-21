# 资产来源与重建

本项目没有购买资产、加入第三方代码库或运行 MakeHuman 程序。人物使用其官方核心数据：正常人体网格、皮肤、服装、头发、眼球和骨骼权重。环境、家具细节、HUD、动作曲线和合成音效由项目代码生成。参考截图只作为构图和风格方向，未提取 GTA 游戏素材。

## 来源与许可

- [MakeHuman 官方许可说明](https://github.com/makehumancommunity/makehuman/blob/master/LICENSE.md)：核心图形资产为 CC0，与应用源代码的 AGPL 区分。
- [核心资产包说明](https://static.makehumancommunity.org/assets/assetpacks/makehuman_system_assets.html)和[实际下载的 CC0 ZIP](https://files2.makehumancommunity.org/asset_packs/makehuman_system_assets/makehuman_system_assets_cc0.zip)。
- 官方仓库 `makehuman/data/3dobjs/base.obj`、`makehuman/data/rigs/default.mhskel`、`makehuman/data/rigs/default_weights.mhw`。
- 原始权利人：Data Collection AB、Joel Palmius、Jonas Hauquier；文件头标明 2020/2021 与 CC0 释放说明。[许可原文](../assets/MAKEHUMAN-CC0.txt)、[署名记录](../assets/CREDITS.txt)随应用打包。

| 交付文件 | 实际组合 |
| --- | --- |
| `casual.glb` | 基础人体、male_casualsuit01 衬衫牛仔裤、shoes01、short02、男性皮肤、棕色眼球 |
| `office.glb` | 基础人体、male_elegantsuit01 西装领带、shoes01、short02、男性皮肤、棕色眼球 |
| `office_female.glb` | 基础人体、female_elegantsuit01 衬衫半裙、shoes01、bob01、女性皮肤、棕色眼球 |

## 重建

正常运行只需仓库中已生成的 GLB 和导入纹理，不需下载源包。若修改服装，准备一个源目录：根目录放 `base.obj`、`default.mhskel`、`default_weights.mhw`，再从官方包保留上述服装/鞋/发型完整子目录，以及 `eyes/low-poly.*`、`eyes/materials/brown_eye.png`、`skins/young_asian_male/young_lightskinned_male_diffuse3.png`、对应女性皮肤。文件名需唯一。

运行 `python3 tools/build_characters.py SOURCE_DIRECTORY`，随后 `sh tools/check.sh`。转换仅用 Python 标准库：衣服按 MHCLO 顶点映射贴合；删除衣下遮挡人体；插值骨骼权重后归一到四权重；转换单位、UV、法线；输出自包含 GLB。Godot 的导入配置与提取 PNG 一起提交，避免机器间重新导入差异。

`scripts/human_visual.gd` 使用 AnimationPlayer/Skeleton3D 生成待机、走、跑、挥击曲线；手持物跟随腕骨。它们是程序骨骼动画，未使用动作捕捉，尚有转身脚滑与手指姿态可以打磨。三套身体重复用于十位 NPC，尚未制作各角色独立面部。
