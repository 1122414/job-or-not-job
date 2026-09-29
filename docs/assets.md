# 资产来源与重建

本项目没有购买资产、加入第三方代码库或运行 MakeHuman 程序。人物使用其官方核心数据：正常人体网格、皮肤、服装、头发、眼球和骨骼权重。环境基础几何、HUD、多数专用动作曲线和合成音效由项目代码生成；2026-09-29加入下述Poly Haven开放环境样本。参考截图只作为构图和风格方向，未提取 GTA 游戏素材。

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

`scripts/human_visual.gd` 使用 AnimationPlayer/Skeleton3D 生成待机、走、跑、挥击曲线；手持物跟随腕骨。除下述开放库烘焙的站立待机/交谈外，其余为程序骨骼动画，未使用动作捕捉，尚有转身脚滑与手指姿态可以打磨。三套身体重复用于十位 NPC，尚未制作各角色独立面部。

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


## 2026-09-29 Quaternius动作制作原件

[Universal Animation Library原作者页面](https://quaternius.com/packs/universalanimationlibrary.html)标明CC0。本项目保留2025-06-10免费Standard的固定镜像版本，在`production/quaternius/standard-2025-06-10/`附许可、原始README、53骨骼/46片段的glTF与bin、来源和SHA256。镜像提交`e24c23cf2a1323488a3faa226ea7ea21f644b73e`，各文件Git blob SHA1已匹配；未证明与官方现版本逐字节一致，不宣称2026最新版或120+片段均免费。

原件目录由`.gdignore`隔离，游戏不直接引用原件；后续已接入下述两个烘焙衍生片段。`tools/inspect_animation_source.gd`核验摘要并生成片段/骨架/根运动清单与四个预览。源演示人物只用于制作检查，不是正式角色；原件验收阶段未替换HumanVisual，后续适配另记如下。详见[动作源验收](2026-09-29_P1动作源资产验收.md)。


### 已接入的动作衍生资源

`assets/animations/quaternius_upper_body.res`使用相同CC0源的Idle_Loop/Idle_Talking_Loop，通过`tools/character_retarget.gd`映射和`tools/bake_character_animations.gd`以60Hz烘焙为待机/站立交谈上半身。保留现有腿和根支撑；其余19专用片段保持程序动作。三衣装骨架相同，重建时验证目标rest；目标GLB或源文件改变后必须重新验收。

`assets/animations/provenance.json`记录源版本、文件、目标三GLB摘要和输出摘要；独立包附`ANIMATION-SOURCES.json`及CREDITS。重建命令：`godot --headless --path . --script tools/bake_character_animations.gd`，会覆盖本项目的派生动画资源，应在版本控制工作区内运行；不覆盖原始源模型。验收见[骨架适配与待机交谈](2026-09-29_P1骨架适配与待机交谈验收.md)。


## 2026-09-29 双公司场景制作资源

追加两套 Poly Haven CC0 原始 2K 贴图：[Wood Floor](https://polyhaven.com/a/wood_floor)（Dimitrios Savva，1.7m）与 [Brick Wall 001](https://polyhaven.com/a/brick_wall_001)（Dimitrios Savva/Rob Tuytel，3m）。木材用于 B 地板和固定木饰面，砖墙用于 B 改造办公室；原图不改，颜色/法线/ARM 使用压缩、mipmap 与米制投影。新来源独立保存在 `assets/company_materials/provenance.json`；重建 `python3 tools/fetch_open_assets.py --set company`，既有五项来源清单不被改写。独立包附 `COMPANY-MATERIALS.json`。

`scenes/companies/company_a.tscn`、`company_b.tscn` 是可编辑运行时场景，包含建筑、灯光、固定物件与 `Anchors`、`PropSpawns`、`PeopleSpawns`。职业实体由标记生成，原 114 件物品、10 名 NPC 的稳定 ID 保留；运行时不执行制作脚本。脚本 `tools/build_company_spaces.gd` 和 `company_room_source.gd` 保留首轮制作来源，默认只生成到 `build/company-scenes`，不自动覆盖已编辑场景。需要重建时先生成到新目录并比较人工编辑，再选择性更新；不能用生成器覆盖设计师修改。

场景保存遵循 [Godot PackedScene 的节点 owner 规则](https://docs.godotengine.org/en/stable/classes/class_packedscene.html)，外部家具场景保留实例引用；位置转换遵循 [Node3D 父子坐标](https://docs.godotengine.org/en/stable/classes/class_node3d.html)。`OfficeRooms.point()` 返回锚点世界位置，动态纸箱写入 `global_position`，避免 B 场景父节点偏移再次叠加。旧常量仍用于 v11 基线/迁移和历史夹具，不驱动新运行时面试位置。

本轮制作不是 GTA VI 品质签收。当前街道远景、玻璃反射、家具网格和人物仍有原型限制，正式人物/演出及用户视听关卡继续开放。

## 2026-09-29 三关键人物候选制作源（未接运行时）

[CC0制作包](../production/characters/cc0-2026-09-29/README.md)保存88原件、59.9MB，包含MakeHuman官方CC0 ZIP选择集及官方Git固定提交`a8bc2d54ff0ac92e78ff71431b1023eda42bf482`的体型/表情/骨架源；逐文件来源、作者原始声明、URL/包内位置与SHA256在同目录provenance.json。原件与下载ZIP/固定Git已逐一核对，不包含应用程序代码。三配方通过`tools/build_character_cast.py`生成候选，保留原始文件；没有新增依赖或付费采购。

候选结构通过但外观拒收：眼睛透明材质和衣装方向已修，眉部、张口/口腔、发边和鞋裤仍有问题。163骨骼和四表情接口不代表正式表演；未制作LOD、未测驻留显存、未替换`assets/characters`、未加入游戏包。旧三模型重建逐字节一致，完整限制见[S2复核](2026-09-29_S2人物制作管线与候选复核.md)。
