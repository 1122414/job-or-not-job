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

`scripts/human_visual.gd` 使用 AnimationPlayer/Skeleton3D 驱动人物；手持物跟随腕骨。除下述开放库烘焙的待机、交谈和走跑上身外，其余为程序骨骼动画，未使用动作捕捉。走跑腿部按体型生成支撑，转身、精细接触和正式表演继续开放。三位关键人物已有独立体型与基础表情，其余角色仍复用旧资源，不等于正式人物制作完成。

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

原件目录由`.gdignore`隔离，游戏不直接引用原件；后续已接入下述四个烘焙衍生片段。`tools/inspect_animation_source.gd`核验摘要并生成片段/骨架/根运动清单与四个预览。源演示人物只用于制作检查，不是正式角色；原件验收阶段未替换HumanVisual，后续适配另记如下。详见[动作源验收](2026-09-29_P1动作源资产验收.md)。


### 已接入的动作衍生资源

`assets/animations/quaternius_upper_body.res`使用相同CC0源的Idle_Loop/Idle_Talking_Loop/Walk_Loop/Jog_Fwd_Loop，通过`tools/character_retarget.gd`映射和`tools/bake_character_animations.gd`以60Hz烘焙上半身。走跑按源左脚前伸对齐目标周期，保留按体型生成的腿部和根高度支撑；专用交互片段保持程序动作。三衣装骨架相同，重建时验证目标rest；三位关键人物独立烘焙。目标GLB或源文件改变后必须重新验收。S4b走跑工程、全套与实际包验证通过；正式人物与完整动作品质仍开放，详见[验收](2026-09-30_S4b城区人物走跑表现验收.md)。

`assets/animations/provenance.json`记录源版本、文件、目标三GLB摘要和输出摘要；独立包附`ANIMATION-SOURCES.json`及CREDITS。重建命令：`godot --headless --path . --script tools/bake_character_animations.gd`，会覆盖本项目的派生动画资源，应在版本控制工作区内运行；不覆盖原始源模型。验收见[骨架适配与待机交谈](2026-09-29_P1骨架适配与待机交谈验收.md)。


## 2026-09-29 双公司场景制作资源

追加两套 Poly Haven CC0 原始 2K 贴图：[Wood Floor](https://polyhaven.com/a/wood_floor)（Dimitrios Savva，1.7m）与 [Brick Wall 001](https://polyhaven.com/a/brick_wall_001)（Dimitrios Savva/Rob Tuytel，3m）。木材用于 B 地板和固定木饰面，砖墙用于 B 改造办公室；原图不改，颜色/法线/ARM 使用压缩、mipmap 与米制投影。新来源独立保存在 `assets/company_materials/provenance.json`；重建 `python3 tools/fetch_open_assets.py --set company`，既有五项来源清单不被改写。独立包附 `COMPANY-MATERIALS.json`。

`scenes/companies/company_a.tscn`、`company_b.tscn` 是可编辑运行时场景，包含建筑、灯光、固定物件与 `Anchors`、`PropSpawns`、`PeopleSpawns`。职业实体由标记生成，原 114 件物品、10 名 NPC 的稳定 ID 保留；运行时不执行制作脚本。脚本 `tools/build_company_spaces.gd` 和 `company_room_source.gd` 保留首轮制作来源，默认只生成到 `build/company-scenes`，不自动覆盖已编辑场景。需要重建时先生成到新目录并比较人工编辑，再选择性更新；不能用生成器覆盖设计师修改。

场景保存遵循 [Godot PackedScene 的节点 owner 规则](https://docs.godotengine.org/en/stable/classes/class_packedscene.html)，外部家具场景保留实例引用；位置转换遵循 [Node3D 父子坐标](https://docs.godotengine.org/en/stable/classes/class_node3d.html)。`OfficeRooms.point()` 返回锚点世界位置，动态纸箱写入 `global_position`，避免 B 场景父节点偏移再次叠加。旧常量仍用于 v11 基线/迁移和历史夹具，不驱动新运行时面试位置。

本轮制作不是 GTA VI 品质签收。当前街道远景、玻璃反射、家具网格和人物仍有原型限制，正式人物/演出及用户视听关卡继续开放。

## 2026-09-29 三关键人物候选制作源（未接运行时）

[CC0制作包](../production/characters/cc0-2026-09-29/README.md)保存88原件、59.9MB，包含MakeHuman官方CC0 ZIP选择集及官方Git固定提交`a8bc2d54ff0ac92e78ff71431b1023eda42bf482`的体型/表情/骨架源；逐文件来源、作者原始声明、URL/包内位置与SHA256在同目录provenance.json。原件与下载ZIP/固定Git已逐一核对，不包含应用程序代码。三配方通过`tools/build_character_cast.py`生成候选，保留原始文件；没有新增依赖或付费采购。

候选结构通过但外观拒收：眼睛透明材质和衣装方向已修，眉部、张口/口腔、发边和鞋裤仍有问题。163骨骼和四表情接口不代表正式表演；未制作LOD、未测驻留显存、未替换`assets/characters`、未加入游戏包。旧三模型重建逐字节一致，完整限制见[S2复核](2026-09-29_S2人物制作管线与候选复核.md)。

## 2026-09-29 城区植被制作

新增Poly Haven CC0的[Tree Small 02](https://polyhaven.com/a/tree_small_02)（Rico Cilliers）与[Leafy Grass](https://polyhaven.com/a/leafy_grass)（Charlotte Baglioni）。原始2K文件及逐文件摘要保存在`production/environment/polyhaven_nature`，由`.gdignore`排除运行导入；制作说明见[植被制作源](../production/environment/polyhaven_nature/README.md)。未引入新依赖或付费素材。

`CityTree`在原23处树位使用共享的三级派生网格和压缩材质。保留源30,250个独立枝叶组；叶色和官方alpha合并，采用深度裁切；枝、干保留独立法线和ARM。草地按2米尺度投影；人行铺地复用现有Concrete Floor 01材质细节，长凳复用现有木材。原始树模型不直接随游戏分发，独立包另附`NATURE-SOURCES.json`；最终品质与性能状态以阶段验收为准。

## 2026-09-30 中心街段建筑模块

新增Poly Haven CC0的[Modular Urban Apartments Facade](https://polyhaven.com/a/modular_urban_apartments_facade)，作者James Ray Cock。完整原始库和独立玻璃alpha在[制作源](../production/environment/polyhaven_architecture/README.md)，运行时只加载三种选定窗墙开间、十张2K压缩贴图及网格LOD。`CityArchitecture`将真实模块装配到三处中心连廊上方；上层碰撞、首层通路、六张长凳及原物品身份保留。

玻璃使用原始独立alpha，窗后有退进的房间背墙和部分窗帘；这属于外观深度，没有新增可进入房间或可玩面积。单套实际压缩贴图含mipmap合计30,758,376字节，独立包附`ARCHITECTURE-SOURCES.json`。重建顺序、源节点展示偏移和运行导出范围见制作说明。正式环境品质、人物/演出、整城内容和持续性能继续按完整目标验收。


## 2026-09-30 街道首层设施

新增四项 Poly Haven CC0 街道资源：MP 的素色卷帘门、PierreB3D 的周转箱、Rico Cilliers 的盆栽和 Kuutti Siitonen 的壁灯。原页与重建步骤见[制作源记录](../production/environment/polyhaven_street/README.md)，全部原件有作者、许可及摘要。运行资源四网格/十九贴图，源alpha、植物分部位置及安装基准分别检查；十处现有建筑首层和三连廊背面使用，未新增商店营业或可玩城区面积。正式整区艺术签收仍开放。


## 2026-09-30 社区公交与居民裙装适配

101公交使用[原创离线制作源](../tools/prepare_city_bus.gd)，运行加载五种共享网格，车门和四轮独立运动。无第三方车辆下载、无新增依赖。制作清单记录源摘要、生成面数和派生摘要，独立包附BUS-PRODUCTION.json；车辆自身含运行方向盘和地板74,160三角形，司机按独立人物计。材质、驾驶员与上下客完整表演仍非最终写实品质，见[车辆制作说明](../assets/vehicles/city_bus/README.md)。

旧office_female居民源已按原SHA保留在[制作目录](../production/characters/resident-skirt-2026-09-30/README.md)，仍为既有MakeHuman CC0资产。重绑只改独立短裙420个导出顶点的JOINTS_0/WEIGHTS_0，不改位置、UV、拓扑、材质、纹理、骨架或其他网格。原件排除运行包，派生和配方摘要在resident_skirt_provenance.json及独立包RESIDENT-SKIRT-SOURCES.json；走跑布料伸缩仍有局限。

## 2026-09-30 城区汽车制作

五辆汽车共用[原创汽车运行资产](../assets/vehicles/city_car/README.md)。`tools/prepare_city_car.gd`复用公交的离线几何辅助方法，六份网格按材质合批，烘焙整车78,040三角形、82条实际LOD，人物及运行方向盘另计。内外轮罩、透明车窗、座舱、转向轮组与头尾灯分别制作；没有第三方汽车源、付费采购或新增依赖。

`production.json`记录汽车及公交辅助制作源、六份网格摘要和座位/碰撞合同。实际包附`CAR-PRODUCTION.json`且排除制作脚本。原型材质、正式上下车/握姿、悬架与车损仍待制作，不能将资源和工程通过当作写实车辆验收。


## 2026-09-30 路边摊与餐具

`CityMealScene`新增原创运行几何：三张站立小桌、实体菜单牌、锅、长柄勺、餐碗、餐食与用餐勺。继续使用既有角色与字体，没有外部下载、付费采购或新增依赖。餐具显示与接触由唯一订单状态派生，不添加第二份物品所有权。锅内搅拌与五位人物的掌点/蒙皮已作专项检查；素材仍为原型，不能据此宣称正式写实材质、取放或口部表演完成。
