# 资产来源与重建

本项目没有购买资产、加入第三方代码库或运行 MakeHuman 程序。人物使用其官方核心数据：正常人体网格、皮肤、服装、头发、眼球和骨骼权重。环境基础几何、HUD、动作曲线和合成音效由项目代码生成；2026-09-29加入下述Poly Haven开放环境样本。参考截图只作为构图和风格方向，未提取 GTA 游戏素材。

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

2026-09-23 新增 `assets/audio/interview/` 中纸张、椅子、纸箱、手机四个短音效。它们以 Python 标准库数学函数在本地合成，未使用第三方录音或外部素材。场景通过 `scripts/interview_audio.gd` 以低音量定位播放；目前只完成事件对时和资源释放验证，耳机/扬声器的主观混音验收仍需执行。

## 2026-09-29 Poly Haven环境样本

用户明确授权下载开放许可资产。以下5项从官方API下载原始文件，[官方许可](https://polyhaven.com/license)为CC0，允许商用和再分发；不包括该网站的示例渲染图、文字或标志。未下载付费包、未加入网络运行时依赖。

| 资产 / 作者 | 使用位置 | 制作适配 |
| --- | --- | --- |
| [Modern Arm Chair 01](https://polyhaven.com/a/modern_arm_chair_01) / Vibrant Nordic | A/B候场区共4张 | glTF原始米制，8916三角形；独立tscn碰撞包装 |
| [Desk Lamp Arm 01](https://polyhaven.com/a/desk_lamp_arm_01) / Kuutti Siitonen、Yann Kervran | A/B接待台各1盏 | glTF，24102三角形；缩至0.7、夹具对齐桌后沿，简化碰撞；不宣称可操作开关 |
| [Painted Plaster Wall](https://polyhaven.com/a/painted_plaster_wall) / Amal Kumar | 两家公司外墙/内侧墙面 | 2米世界投影，A中性色/B暖色；2K颜色、OpenGL法线、ARM |
| [Concrete Floor 01](https://polyhaven.com/a/concrete_floor_01) / Rob Tuytel | 公共地面 | 2米世界投影，保留A/B既有地毯；2K三贴图 |
| [Clean Asphalt](https://polyhaven.com/a/clean_asphalt) / Dimitrios Savva | 公共街道路面 | 2.1米世界投影；2K三贴图 |

原始文件共44,725,248字节。`assets/polyhaven/provenance.json`记录作者、许可页、每个原始URL、上游MD5、长度和本地SHA-256。MD5仅用于与源站传输校验一致，SHA-256用于项目清单；下载不是美术品质通过。材质使用VRAM压缩和mipmap，glTF导入保留LOD生成；原文件不改，材质和碰撞在独立资源中维护。

重建：`python3 tools/fetch_open_assets.py --output assets/polyhaven`，已存在同摘要文件直接使用；不同文件保留并报错，禁止覆盖美术编辑。工具只接受官方HTTPS域名、拒绝跨域重定向及路径越界，下载完成才原子改名；中断的`.tmp`需核查后处理。普通游戏离线使用已入库资源，不需要运行下载器。验证：`tests/environment_assets_test.gd`、`tests/test_open_assets.py`及完整职业/行走回归。

macOS包的`ASSET-SOURCES.json`和`CREDITS.txt`保存来源；通用CC0原文随原有`MAKEHUMAN-CC0.txt`分发。候场椅和台灯暂为固定环境家具，没有擅自变更114件可破坏道具及存档ID。正式场景还需要碰撞精修、材质连续性/使用痕迹、光照与声音；正式主角/林岚/阿诚及动作表情没有由此完成。
