# 项目经验索引

2026-10-09设计复核：新增[内容入口与叙事资格](patterns/content-entry-eligibility.md)，适用于旧分支测试仍通过而新主线取消其任职前置；B交接入口代码交叉确认一次，新入口及真人体验未验证；用户补充长期实习与HC承诺主题后，该入口改列支线，主线优先。

| 机制 | 适用信号 | 验证状态 | 记录 |
| --- | --- | --- | --- |
| 静态光照输入与活场景分离 | 标记建筑后仍烘入人物/道具，批量网格回弹颜色错误 | C4l.2a真实场景2089代理/7组排除、正负结构变化及独立资源11图一致验证一次；C4l.2b运行599白名单、4资源包与真实像素刷新复验；生命周期开放 | [静态烘焙输入](patterns/static-lighting-inputs.md) |
| 间接光配置与实际后端贡献 | SDFGI已启用但暗面没有回弹 | 2026-09-30本机4.7.1八组正负GPU对照一次；Metal SDFGI未贡献、Vulkan SDFGI/Metal VoxelGI有贡献；产品接入未验收 | [间接光后端验证](patterns/indirect-light-backend-validation.md) |
| 地面碰撞高度差 | 角色在入口停住，视觉上像开放通路 | 本项目验证一次 | [地面接缝](patterns/floor-seams.md) |
| 视觉参考范围与动画观察时序 | HUD 已接近但人物仍是占位；面试字幕叙述未演出的动作；专用曲线被错误分支包住；交叉淡入首帧误判静态 | 状态通过仍不等于品质通过，多轮反例；2026-09-30宏观复核区分工程/体验/整城能力；C3k取餐同帧冻结反例复验一次；2026-10-01主角概念板明确二维/三维边界，用户已接受造型，实际人物品质开放 | [视觉范围](patterns/visual-reference-scope.md) |
| 姿态与碰撞支撑不一致 | NPC倒地后物品仍悬空；沙发坐姿接地通过但裤腿穿家具 | 原有机制多次复用；C3i实际衣装28,993顶点与正侧面验证一次；C2c地板支撑及C4j曲面座椅已验证；C4k实际衣装、轮罩可见面24射线及图形复验一次 | [身体支撑](patterns/body-support.md) |
| 寻路终点、入口投影与重叠步道 | 返岗停住、避人绕圈、同一通路反复回头、扩建后旧活动点落入车道 | 返岗/过街多轮复用；C4i近节点回拉/过街迎面死锁已验证；C2c下客路径验证；C3k重叠长边接入新支路的远端回绕已按真实同伴用餐验证一次 | [工位及公共路网](patterns/navigation-endpoints.md) |
| 内容扩充与 JSON 版本数值 | 新道具导致旧档失效；内存/JSON类型差异、分支前置状态不完整；恢复重置镜头或手持物 | 多轮回归；C2c v23关联须先校验载具，17类坏档/22旧版本通过；C4k八份真实驾驶档复验同一JSON表示比较 | [存档扩充](patterns/save-content-expansion.md) |
| UI 页面状态和来访确认时机 | 叠加面板、暂停快捷键无响应、来访已记而未交谈 | 自动回归通过；UI实机复验，来访整体节奏仍开放 | [未解决观察](unresolved.md) |

| 暂停页面输入归属 | 主页面叠加、暂停帮助失效 | 2026-09-29真实GUI与比例字号复核；C4e滑块Home/End八端点真实输入通过；实体手柄开放 | [页面输入](patterns/panel-input-ownership.md) |

| 交谈对象连续性与附近目标竞争 | 工位抢来访交互，或侧面路人抢正面同伴 | 来访与C3e连续场景分别验证；面向选择两向回归通过 | [来访与同行交谈](patterns/visit-dialogue-continuity.md) |

| 网页平台字体与输入差异 | 中文方框、捕获失败、重复构建扫描产物 | 中文与打包验证一次；边界仍待验 | [网页导出](patterns/web-export-platform-gaps.md) |
| 构建与证据身份 | 旧包反馈、源码回退、零GPU计时、强制绘制计数、平台覆盖被基础配置掩盖、旧生成源漂移 | 多轮包身份复验；C4g实际TodayOff默认Metal、平台清单与后端总完成信号差异各验证一次；C4k外部Parse Error退出0及最终98项输入身份再次复验；R30签名前/后引擎哈希及20/21实际像素一致复验 | [构建证据](patterns/build-evidence-identity.md) |
| 开放资产的安装、材质语义与导航占地 | 导入通过但朝向/支撑/材质用途错误；旧路线被新家具封堵；模块库显示偏移和窗后共面闪烁 | 2026-09-30 C4i重复验证alpha/真实压缩；26壁灯安装、共享Image审计及冻结射线反例验证一次；CH2-B1免费专有许可/FBX缺失材料连接及静态弯曲轴实测一次 | [资产接入](patterns/open-asset-integration.md) |
| 附件几何、蒙皮与表情贴合混用 | 眉片尖角、表情中途穿插、裤脚白块、鞋边碎片 | 2026-09-29三候选43状态采样验证一次；C4j旧居民短裙同机制复用；CH1-A三旧人物负值修复与实际包复验；步态拉伸/材质开放 | [人物附件贴合](patterns/character-attachment-fitting.md) |
| 人物比例与运动支撑 | 同名骨骼的新体型滑脚、悬脚或碰撞托物；走跑切换重起周期 | 三人体型和碰撞验证一次；S4b六体型120次相位切换、上身动作与腿部支撑分离专项验证一次；完整运动品质开放 | [比例适配](patterns/character-proportion-adaptation.md) |
| 活动优先级与所有权交接 | 人物清醒、有路却原地等；已坐下却保存walking；救助接管残留休闲预约 | 工作/活动多次复用；C3h绝对时段边界、约定释放及对话所有权验证一次，388m跨日路线通过 | [活动优先级](patterns/activity-priority.md) |

| 手物接触点、蒙皮与更新时序 | 掌心接近但指尖穿模；物件落后一帧；转向不可达；静止托书通过而进出页叠穿透或回手过快 | 六体型/四物件及方向盘已验证；2026-09-30 C3f完整190帧与三体型皮肤采样验证一次，C3k五人物餐勺方向/托底与锅内长柄勺验证一次；R30玩家限长挥击/接触窗口及握拳近景验证一次；完整取放与细致握姿开放 | [手物接触](patterns/hand-prop-contact.md) |
| 移动载具与角色位置修复 | 乘车读档被当成卡墙出生点；相对座位丢失；旧油门输入继续 | 公交/C2a恢复多次验证；C2c公共座位关联与同帧下客当前节点检查已复验，最终93项及实际包/六档恢复通过，跨区开放 | [乘客恢复](patterns/vehicle-passenger-restoration.md) |

| 公共现场实际转运与路权交接 | 死亡居民不再消费跨路段；小组末段斜向地面停住 | C3b三处真实车流及书屋转运验证一次；正式服务生态开放 | [公共导航与现场路权](patterns/navigation-endpoints.md) |
| 图形窗口启动覆盖 | 初始化隐藏/最小化后仍可见，运行中hide报错 | 本机Godot4.7.1修正后最小化/无焦点/鼠标可见验证一次 | [后台窗口状态](patterns/background-window-state.md) |

| 程序化地表细节与像素足迹 | 近处砖缝正常，远处出现点线，MSAA未改善材质内部混叠 | C4a静态同位对比验证一次，移动镜头待验 | [地表过滤](patterns/procedural-surface-filtering.md) |

| 扩建后的旧落点与地面恢复 | 旧档位于新楼芯，查询安全但角色在地板下 | C4c三处验证；C4f补公共居民及座位/救助所有权，六处家具旧落点验证一次，范围限当前平地 | [地面支撑与恢复](patterns/floor-seams.md) |
| 天空的雾色覆盖 | 天空资源已配置但实际仍是单色 | C4c同位昼夜图片验证一次 | [天空与雾](patterns/sky-fog-coverage.md) |
| 独立枝叶减面与连通性 | 整体自动LOD使树冠变秃；局部LOD拆断叶柄；裸枝裁切片误判为管状 | C4d三级连通、独立几何重建及330次实际LOD绘制验证一次；最终观感/预算开放 | [枝叶减面](patterns/foliage-simplification.md) |

| 空间声音输出与音频线程生命周期 | playing但声像无证据、退出WAV泄漏、后台声音 | C4e真实PCM方向/静音和固定FPS释放验证一次；最终听音开放 | [声音输出](patterns/audio-output-lifecycle.md) |

| 灯罩透射与LOD归因 | 灯罩斜视灰块，关闭LOD后图像相同 | 灰块可复现；透射是待验证因素，正式美术未验收 | [G05/G06-C4i-B](unresolved.md) |

| 静态司机初始化与动画混合 | 单次advance后pause；腿部穿出车体 | C4k旧版关节偏差0.571649m；三司机零混合与40帧自然收敛腿部差0，确认同因；头部注意力不作为腿姿门槛 | [观察时序](patterns/visual-reference-scope.md) |

| 时间驱动灯光与暂停恢复 | 暂停读夜档不亮、跨日一直亮 | C4j暂停JSON及18个跨日晨昏样本验证一次 | [时间表现](patterns/time-dependent-presentation.md) |

| 延后承诺与实际作业 | 对话说次日完成却没有发送；旧档日期不明；未答复邀请变成约定 | C3j实体作业、源码/实际包跨日路线及六档独立恢复验证一次；整城离线模拟开放 | [延后世界行为](patterns/deferred-world-actions.md) |

2026-10-08复用补充：[内容扩充与存档迁移](patterns/save-content-expansion.md)记录v26新旧叙事隔离、阶段关联及本轮RefCounted循环；[平台字体边界](patterns/web-export-platform-gaps.md)补桌面新增汉字缺字反例，定向字符检查与四页实际图形验证一次。

2026-10-09反馈复用：[保存校验与原始现场保全](patterns/save-content-expansion.md)、[救助接近点及自动玩家步速适配](patterns/navigation-endpoints.md)、[普通步行/髋高](patterns/character-proportion-adaptation.md)、[接管后公交乘客位置](patterns/vehicle-passenger-restoration.md)。上述定向反例验证一次，完整发布检查与体验边界见当日验收文档。

2026-10-09 NPC/LLM：新增[特殊人物与异步对话](patterns/npc-free-chat-boundaries.md)（特殊NPC覆盖、取消/过期回复、严格模型数据边界，定向验证一次）；复用[页面输入](patterns/panel-input-ownership.md)、[存档版本](patterns/save-content-expansion.md)，并用实际高度日志修正[地面恢复](patterns/floor-seams.md)的瞬时抬升边界。

2026-10-09 U01/U02：按用户纠正撤换独立聊天页，复用[输入归属](patterns/panel-input-ownership.md)与[异步对话边界](patterns/npc-free-chat-boundaries.md)，记录原对话内输入、GUI点击坐标及请求前超时配置；协议成功不能替代产品入口验收。

2026-10-09 NEXT08：复用[存档扩充](patterns/save-content-expansion.md)，补充恢复借用调用者字典导致原快照被后续职业状态改写的实际反例。原序章3失败修复后与新定向检查通过一次；12周日历和岗位/承诺关联、两种评审入口、旧档不补记经历分别验证，完整门槛见阶段验收。

2026-10-09 NEXT05-C1：新增[渲染装饰与相机间隙](patterns/camera-render-collision-clearance.md)，真实见证视角稳定遮挡、侧窗三角形命中及球形探针原位对照验证一次；正式接入后720图/800真实会面、10项相关回归与30/120Hz通过一次，动态自然度仍开放。


2026-10-09 NEXT05-L1/L2：复用[页面输入](patterns/panel-input-ownership.md)，补充按内容布局、真实控件换行边界和滚轮验收；中文字符事件与系统IME组合明确分开，后者未验收。


2026-10-09 NEXT06-C1/C2：复用[异步聊天边界](patterns/npc-free-chat-boundaries.md)，补本人stable_id原话来源、岗位替换/未来记录隔离，以及已发生事实与自由聊天执行权限的区别；五项回归通过一次，真实云端质量开放。


2026-10-09 NEXT07：复用[构建证据](patterns/build-evidence-identity.md)和[后台窗口](patterns/background-window-state.md)，实际包3600活场景绘制完成与窗口守卫通过；补引擎消费启动参数、短预热监视器旧值反例及边界。正常帧率/长期路线仍开放。


2026-10-09 NEXT02：复用[内容入口与叙事资格](patterns/content-entry-eligibility.md)、[延后实际行为](patterns/deferred-world-actions.md)和[存档迁移](patterns/save-content-expansion.md)。朋友事件独立资格/原人物/实际发送与旧员工任务分开，三分支与独立磁盘恢复验证一次；完整120项通过，自然体验仍开放。

2026-10-09回应动态取证：复用[声音输出](patterns/audio-output-lifecycle.md)，补初始化apply_levels覆盖提前静音的单次验证反例；后台守卫、3份实际PCM与音画时长边界已核对。

2026-10-09统一候选包：复用[构建身份](patterns/build-evidence-identity.md)，同运行输入关联120项源码回归，实际包另执行七项与五次独立档恢复；五图四张字节一致，差异图保留并目视复核，未推定原因。

2026-10-10 CHAT01—03：复用[异步自由对话边界](patterns/npc-free-chat-boundaries.md)，补充JSON历史协议、缺关系字段的台词保留、单次恢复及无正文诊断。旧版4断言失败，修复后定向HTTP通过一次；截图云端具体根因与真实成功率仍未确认。

2026-10-10 INPUT01：复用[页面输入归属](patterns/panel-input-ownership.md)，确认WebSupport在_enter_tree禁用处理无效、桌面误跑网页失锁菜单，以及current_scene为空的旧夹具盲区。旧版2失败、修复后实际E事件定向通过；网页仅状态验证。


2026-10-10 MOT01—03：复用并补充[载具与乘客恢复](patterns/vehicle-passenger-restoration.md)、[时间表现](patterns/time-dependent-presentation.md)、[存档扩展](patterns/save-content-expansion.md)。记录路线位置覆盖冲量、展示时钟与一次结算分离、JSON子结构版本数字类型反例；专项验证一次，物理/动画适用边界见各条目。

2026-10-10后台核心路线：复用[构建证据](patterns/build-evidence-identity.md)，最新包九项及四次独立恢复通过；外部夹具遗漏创建目录迁移时，退出0/断言0失败仍被日志扫描拒收。纠正后全部重跑，游戏运行输入未变。
