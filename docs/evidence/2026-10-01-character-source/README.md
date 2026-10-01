# CH2-B1：免费绑定人物的实际制作基准

2026-10-01。范围只覆盖Renderpeople免费FBX包中的Eric z-up A-pose；另外两名女性未解包/审查。这是Blender真实网格渲染，不是生成概念图、游戏截图或新主角验收。技术检查应用asset-review，视觉观察单列；未给整个项目或未测维度打分。

## 来源与交付边界

[作者免费页](https://renderpeople.com/free-3d-people/)提供无需账号的绑定人物。[实际官方FBX包](https://renderpeople.com/sample/free/renderpeople_free_rigged_people_FBX.zip)395,419,456字节，SHA256 `dadbe6fb83345566ff1d2822c0fa38e05aaa09c17d7f1340719a4c8e01dbadcd`；外包与Eric内包CRC、安全路径通过。具体FBX与六种变体、五张源纹理的身份见[provenance.json](provenance.json)，下载时刻为UTC，本地日期2026-10-01。

它是免费专有许可，不是开源或CC0。[官方条款](https://renderpeople.com/general-terms-and-conditions/)版本13.12.2024：2.5免费资产适用同一条款；4.1允许普通渲染和游戏用途；4.2b、4.3b限制原始/改制三维数据转交及易提取分发，4.2a另限制CV/ML研究，4.3a限制特定冒犯用途。本次只做本地中性Blender审查和普通渲染，未训练模型、未采购、未发送外部消息。正式游戏的分发保护与具体角色用途未判定通过，不能从“允许游戏”推导当前未加保护PCK自动合规。

原ZIP、FBX、纹理与可编辑工程只留在忽略的`build/character-route-2026-10-01/`，未提交或镜像。工程：`build/character-route-2026-10-01/studio/candidate-studio.blend`。Git交付仅工具、审查摘要和渲染图；证据不包含顶点、UV或权重逐行数据。若本地build清理，按官方链接重新下载，用摘要确认同一输入，不能依靠仓库镜像取得源模型。

## 技术结果与直接观察

实测10,353顶点、20,542三角面、1个网格/材质/UV层、88根骨骼；身高约1.8635m。负值/非有限权重、未绑定顶点、权重和异常、退化三角形与零长骨均为0，最大8个正影响。包括眼睑、眼球、下颌和手指骨；这不证明眨眼、张嘴或交谈已经合格。没有shape key、动作片段或命名LOD。来源只承诺四边面规模，不能把作者polycount当作三角面实测值。

三张实际接入纹理均8192×8192，RGBA8基准合计768MiB（不含mipmap、不是实测显存）；源制作可保留，运行派生需≤4K、压缩及LOD预算后重新审查。20.5K面低于最初30—100K主角参考范围，面数本身不构成美术失败或成功。

FBX默认只加载diffuse；默认normal节点没有源normal输入，gloss也未接入。工具显式建立sRGB颜色、Non-Color法线和`1-gloss`粗糙度；mask01/02语义未验证，不猜成透明或皮肤遮罩。法线保持原RGB，绿色方向/皮肤散射/眼材质仍待进一步验证。默认厘米骨架scale0.01保持，未缩放骨长去拟合设计图。

实际正/侧/背：人体轮廓连续，肩颈、四肢和衣褶可辨，没有旧候选的明显眉片尖刺；本次已看五张最终图。面部近景有明显高光，发型是贴图与实体表面，缺少细致发丝/皮肤层次，眼部仍显静态。仅一个整人网格，脸、服装和头发没有独立对象可直接换装；是否有内部独立拓扑岛未审查。外貌与正式衬衫马甲不符合已定东亚毕业生，不能作为默认玩家形象。

静态左肘70°、左膝65°检查产生1981个移动顶点，最大位移0.623m，全部有限；实测方向夹角分别70.000007°、65.000008°，原骨长保持。画面能看到确实弯曲，但不证明自然运动/衣装穿插全部合格。首版固定局部X只造成扭转，已改为从实际骨方向计算弯曲轴；失败试图未作为最终证据交付。

| 视图 | 实际产物 |
| --- | --- |
| 正面/侧面/背面 | [front.png](front.png) · [side.png](side.png) · [back.png](back.png) |
| 面部/关节 | [face.png](face.png) · [joint_probe.png](joint_probe.png) |
| 数据与重开 | [audit.json](audit.json) · [reopen.json](reopen.json) |

渲染Blender4.5.9 LTS、Cycles CPU24samples、AgX、中性三面积灯，1000×1200；离线画面不是Godot实时表现或游戏FPS。后台无游戏窗口与鼠标捕获。

## 问题表

| ID / 优先级 | 问题与证据 | 修前表现 | 处理 / 预期 | 留置风险 / 改动风险 | 状态 |
| --- | --- | --- | --- | --- | --- |
| CH2-B1-01 / P1 | 用户Epic登录报错；本地无可动新主角工程 | 制作停在登录 | 独立FBX→Blender→保存重开/真实渲染 | 留置：等待账号；改动：另一路线仍需资产授权 | 基准管线已完成，Epic错误未诊断 |
| CH1-B/C / P1 | 已定毕业生概念与Eric脸/马甲不同，近景皮肤/头发层次不足 | 只有已确认二维主角，无合格三维主角 | 基准单列；正式脸、服装、材质和连续动作另做 | 留置：身份偏离；改动：整人扫描网格不能靠换色可靠改成概念造型 | 开放，不接入 |
| CH2-B1-02 / P1 | 免费专有条款含分发/用途约束 | 易误认CC0并提交源文件 | 本地忽略源工程，仅交付摘要/普通渲染；正式用途先核查 | 留置：误用许可；改动：本地源不随仓库恢复 | 来源核查完成；游戏许可/保护开放 |
| CH2-B1-03 / P1 | 实际FBX只加载diffuse，无normal/gloss输入 | 导入成功但材质缺失 | 显式贴图语义与材料连接，重开确认 | 留置：塑料/平面效果；改动：法线方向和光泽观感仍需艺术检查 | 基准节点修复通过，正式材质开放 |
| CH2-B1-04 / P2 | 8K×3、最大8影响、无LOD/动作 | 未具备已验收运行派生 | 以后4K/压缩/LOD、骨架适配与动作回读；不在本阶段假装导出通过 | 留置：运行成本/表现不可控；改动：降采样/减面损失，影响限制须实测 | 开放 |
| CH2-B1-05 / P2 | 首版局部X造成扭转，位移非零不足以证明弯曲 | 会误报关节探针通过 | 按实际方向确定轴，验证两骨夹角再渲染 | 留置：假验收；改动：两静态姿态仍不覆盖运动 | 已修复，限定静态探针 |

## 定向验证

预修结果标注观察/预测，不恢复游戏旧缺陷。

| ID | 任务/命令 | 修前预期 | 修后预期 | 实际证据 | 状态 |
| --- | --- | --- | --- | --- | --- |
| CH2-B1-01/02 | 外ZIP与Eric内ZIP `ZipFile.testzip()`；绝对/父目录路径拒绝；源摘要 | 预测无已核对源 | CRC无坏项、路径安全、来源匹配 | provenance两包与文件摘要；395,419,456字节 | 通过 |
| CH2-B1-01/03 | 下方Blender审查命令 | 观察只diffuse、无编辑样板 | 骨/权重/三张有效纹理、显式节点、五张渲染、可保存 | `CHARACTER_SOURCE_REVIEW_OK`退出0，audit.json | 通过 |
| CH2-B1-05 | 两骨方向角、形变与rest骨长核对，观察joint图 | 观察首版仅扭转 | 肘70°、膝65°且有限，骨长不变 | 最终70.000007°/65.000008°，1981移动顶点 | 通过；不代表动作验收 |
| CH2-B1-01/03 | 同工具`--reopen`、禁用文件脚本 | 预测外部纹理/连接可能丢失 | 保存后网格统计、权重、骨架、图片摘要/颜色空间与节点连接同原审计 | `CHARACTER_REOPEN_OK`退出0；metrics_identical=true | 通过 |
| CH2-B1-02 | `--private-dir docs/evidence/.../rejected-private` | 预测原工程可能误放提交目录 | 在创建目录前拒绝 | ValueError明确提示，`--python-exit-code 1`退出1，无新目录 | 通过 |
| CH1-B/C/04 | 五图直接观察并对照已定概念；不导出 | 观察二维与旧模型问题 | 如实记录不符合、预算和未验收项 | 正常轮廓但身份/服装/脸发品质不符合，8K/无LOD/动作 | 审查完成；正式主角未通过 |
| CH2-B1-01/02 | `py_compile`、diff检查、输入SHA/原工具字节比较 | 预测可能改到旧资产或用户编辑 | 工具语法有效、无运行改动/原源泄漏 | 运行SHA cbe44750保持；两原候选工具字节保持，原模型在gitignored build | 通过；Git提交前复查 |

可复现命令（先从官方包解压Eric；仅普通本地审查）：

```sh
build/tools/Blender-4.5.9.app/Contents/MacOS/Blender -b --disable-autoexec --python-exit-code 1 --python tools/review_character_source.py -- --source build/character-route-2026-10-01/source/eric/rp_eric_rigged_001_zup_a.fbx --private-dir build/character-route-2026-10-01/studio --evidence-dir docs/evidence/2026-10-01-character-source
build/tools/Blender-4.5.9.app/Contents/MacOS/Blender -b --disable-autoexec --python-exit-code 1 --python tools/review_character_source.py -- --private-dir build/character-route-2026-10-01/studio --evidence-dir docs/evidence/2026-10-01-character-source --reopen
```

工具仅支持这类单套`tex/*_dif/_norm/_gloss.jpg`材质映射，遇到缺失/多重同名须停止并适配。局部骨名不同则探针明确未执行，不把此规则推广到任意模型。沙箱内Blender初次崩溃；正常文件权限升级后完成导入/渲染/重开，未绕过Gatekeeper或文件脚本限制。FBX `Short`自定义属性警告保留；本次没有验证来源控制器的Blender功能。
