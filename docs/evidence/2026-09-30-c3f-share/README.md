# C3f 街区分享现场参与证据

日期：2026-09-30。最终运行源码摘要：`a0466bc0d3c6b11cffde54ddd21e82dcdcd30ebee2c1c5372246cd02bff07b6e`；逐文件身份见[source-manifest.json](source-manifest.json)。全部图像为实际Godot Compatibility渲染，未生成或后期改图。此前ad5cf696是回手节奏修正前的中间版本，不作为最终运行交付。

## 现场画面

| 场景 | 证据 | 观察 |
| --- | --- | --- |
| 投影讲述 | [指向投影](final/screen-1.4.png)、[回看听众](final/screen-5.6.png)、[下一讲述者](final/screen-7.4.png) | 指示、听众朝向和转述姓名随现场变化 |
| 围桌共读 | [阅读](final/paper-1.4.png)、[翻页](final/paper-5.6.png)、[下一段](final/paper-7.4.png) | 居民持实体图册，图像与故事对应 |
| 三种现有人物 | [休闲](final/reading-casual.png)、[女职员](final/reading-office_female.png)、[男职员](final/reading-office.png) | 后缘托书；这是现有原型人物和动作，未达到正式写实标准 |
| 普通玩家镜头 | [现场观看](final/paper-player-camera.png) | 保留玩家自由视角；图册和参与者可见 |
| 花园展览 | [指示第一幅](final/garden-1.4.png)、[面向邻居](final/garden-5.6.png)、[第二位讲述](final/garden-7.4.png) | 听众随讲述/指示转向，展品保持实体位置 |
| 玩家阅览 | [第一页](final/player-browse-first.png)、[纸页转动近景](final/player-page-turn.png)、[第二页](final/player-browse-second.png) | 实际E/数字键打开、逐页、合上；近景使用取证相机，游戏不自动切镜头 |

`final/render.json`记录三方案、自然到场、实际转述者和窗口守卫。工具在准备点放置玩家，居民自然行走；1.4/5.6/7.4秒是固定相位诊断采样，不能称为连续普通游玩录像。最终源码重拍16图与此前审看的16图SHA-256逐项相同；回手时序改变主要在这些静止采样之间，由连续190帧专项另行检查。

## 原玩家镜头路线

`tools/render_city_places_walk.gd`使用正常玩家镜头、自然推进的时钟和真实方向/E/数字输入，开始后没有中途传送。最终源码路线145.501313m，最大单步0.083336m，游戏时间10:30→10:45，实际打开图册、合上并出门；[逐点记录](walk/walk.json)。保留并查看[入口](walk/route-3.png)、[实际阅读](walk/actual-reading.png)、[离开](walk/route-7.png)。这是工具控制的连续路线，游戏内15分钟不能当作真实15分钟或独立玩家验收。

## 回归及反例

- `career/`保留7张A/B完整图形路线图；实际查看interview_hr、defend、handover，其余4张仅归档。此路线在ad5cf696运行源码执行，之后只调整纸本回手路径时长及相应检查窗口；不能称为最终源码逐像素职业复拍。最终16张分享图、3张连续路线图和2张反例均已查看，总计查看24张、归档28张。
- [提示条盖住字幕](rejected/subtitle-toast-overlap.png)、[首轮托书](rejected/initial-reading-contact.png)为中间迭代反例，未绑定最终源码摘要；不能当作最终版本。首轮静止皮肤穿透3.2286mm，后续连续翻页也暴露进出路径穿透；数值不能只由截图推断。
- 前一版本基线见[C4f三活动图片](../2026-09-30-c4f-places/README.md)及其源码清单。镜头与本轮不同，只作版本行为例证，不作同位像素或性能比较。
- [图片校验](image-sha256.json)覆盖28张归档PNG；[接触与连续位移](contact-metrics.json)记录最终专项数据；[检查身份与结果](verification.json)记录79项Godot、29项Python、图形与两目录实际包验证。

最终三方案专项0失败。纸本五个静止相位双掌点误差最大0.007629mm；导入人体皮肤相对两侧固定封面/页叠的采样穿透最大0.953842mm；连续190帧最大右手单帧位移29.981744mm，未拉长手臂骨骼。皮肤采样不覆盖每帧、服装和转动薄纸全表面；这些指标不证明细致捏纸或自然表演。第一次全套曾在55.283mm回手位移处失败，延长回手至1.2秒后最终专项通过，未放宽35mm门槛。

所有自动图形取证使用最小化/不可聚焦根窗口、禁用根输入、可见鼠标、Dummy音频。没有测正常游戏FPS、最终声音或独立玩家体验。仍可观察到人物重复、静态体态和空旷场所；现场道具尚无完整取放/收纳演出，不能视为GTA VI品质通过。
