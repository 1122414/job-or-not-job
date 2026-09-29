# C4f 生活街区场景证据

日期：2026-09-30。修改前基线 main / 48d41ab；最终运行源码及逐文件摘要见[source-manifest.json](source-manifest.json)，总摘要de252c0e048aad55d3c4a8c43ea27d429ffbae9efd996801863d5bd842c91b94。所有图片为实际Godot Compatibility渲染，未生成或后期改图。

## 同位前后

| 场景 | 修改前 | 最终 |
| --- | --- | --- |
| 书屋入口 | [原实墙前窗](before/bookshop.png) | [真实窗洞和入口](final/bookshop.png) |
| 书屋内部 | [原室内](before/bookshop-inside.png) | [书架、投影与阅读灯](final/bookshop-inside.png) |
| 住宅 | [原住宅立面](before/homes.png) | [住宅窗/阳台/入口差异](final/homes.png) |
| 城区总览 | [原楼体](before/district-overview.png) | [最终楼体](final/district-overview.png) |

修改前保留4张；最终13张包含老城、住宅、滨水、公司出口、城区总览、夜间老城/滨水、书屋入口/内部/展陈侧/窗口/傍晚及中心轴，已逐张实际查看。固定相机、FOV65、1440×900和MSAA2；参数及绘制计数见[修改前](before/render.json)、[最终](final/render.json)。改造前JSON保留全部13个采样点的统计，图片仅归档上述4张。

最终615组实际非空MultiMesh变换和23棵树位两次场景重建一致，其中包括书屋陈设批次；这证明确定性与实际提交，不能证明美术达标或普通FPS。当前夜景偏暗、人物复用、重复建筑及空间活动不足仍可直接从画面看到。

## 原玩家镜头的连续路线

工具`tools/render_city_places_walk.gd`只在开始设置一次起点，之后真实移动输入经过八个点；自然时钟与居民/车流运行，中途不传送、不移走障碍。实际E/1打开实体图册，再合上并走出书屋。路线累计145.501313m、最大单步0.083336m、10:30→10:45；[逐点记录](walk/walk.json)。

- [走到入口](walk/route-3.png)
- [实际打开图册](walk/actual-reading.png)
- [离开书屋](walk/route-7.png)

三张均已查看。工具总共采样9图，本目录保留以上3张。模拟时间15分钟不等于真实游玩15分钟；这一段不代替30—60分钟独立玩家自由体验。

## 迭代反例与修正

- [透窗反向文字](rejected/mirrored-window-sign.png)：真实窗洞暴露原双面Label3D背面，最终固定文字改为单面。
- [远处浮动提示](rejected/distant-activity-labels.png)：普通活动标签改为4.5m内显示，公告由实体底板与单面文字承载；实体公告不随近距离提示一起消失。

首轮路线工具曾冻结路人，导致正常通路被人为固定的角色占据。修正夹具让公共居民继续运行，保留真实碰撞及原路线，并未把它登记为运行时寻路修复。玻璃射线首次打到窗棂，调整采样点进入真实玻璃面后继续要求实际碰撞与透明材质同时成立，没有削弱玻璃检查。

## 自动验证与范围

[验证记录](verification.json)保留78个Godot测试的脚本/日志摘要及独立包检查；[验收报告](../../2026-09-30_C4f生活街区场景验收.md)解释每项检查的原触发、边界和结果。新增公共居民旧档回归先实际失败，随后修复；不是从代码推测出的“修改前失败”。

自动工具主窗口初始化与deferred入口均为最小化、NO_FOCUS，根输入禁用，鼠标可见；使用Dummy音频，不输出桌面声音、不写玩家存档。正常玩家操作规则保持。画面复核是本场景范围内的制作检查，整体GTA VI视觉/性能/玩家签收仍开放。

## 三种分享与职业回归

最终三种分享及闭馆已通过，居民自然行走赴约，实际结果见[活动状态](activities/render.json)。该工具将玩家放在各互动点附近，用于检查现场画面；连续玩家移动另由上面的145米路线验证。

已实际查看并保留[本地投影](activities/screen-sharing.png)、[纸本共读](activities/paper-sharing.png)、[花园展览](activities/garden-sharing.png)三图。三种活动的角色仍以站立和字幕表达为主，正式参与动作未因此完成。

最终`tests/full_route_test.gd`完成A/B职业及帮助、拒绝、协商和冲突分支，failures=0。保留并实际查看[入职](career/join_a.png)、[转正](career/defend.png)、[B交接](career/handover.png)三图；工具原共生成7图。全部28张归档图已查看，逐图摘要见[image-sha256.json](image-sha256.json)。最终图形、78项Godot全套和两目录实际包日志均无ERROR/WARNING。

完整观感仍未验收：职业截图中的动作/人物重复与HUD在明亮背景下的对比度属于整体品质后续；不能将路线成功解释为正式人物演出完成。
