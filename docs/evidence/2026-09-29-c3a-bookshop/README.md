# 社区书屋与多解活动证据

日期2026-09-29；实施提交20cf272。运行源码a1887c451ab6c08d06b9118a82d44a5f9adff0a89ac4326747ec560d71ca3ee6，与构建2173965基线含未提交修改的独立包相同。详细问题/测试表见[C3a验收](../../2026-09-29_C3a社区书屋与多解活动验收.md)。

- bookshop-entrance、screen-diagnosis：开放入口/公告与实际E检查设备。
- screen/paper/garden-sharing及completed：三种准备方式的实际展示和不同参与位置；居民自然行走到现场，至少两人在场才推进。文字字幕与原创新图册可见。
- bookshop-closed、bookshop-map：20时闭馆、灯光变化、保留出口，以及城区地图的场所入口。
- before-paper-sharing、before-screen-sharing：纸本初版沿用投影站位、故事只靠远处小字，修正为桌边目标和字幕。
- before-bookshop-closed：图形夹具冻结主进程后改变时间，却没有同步日光。夹具补update_daylight后重新拍摄20时画面；没有改运行时日夜规则。
- checks.json：63项Godot、24项Python及后加真实地图点击的定向结果、事件首到场/参与人数、真实攻击中断、JSON/旧版本/坏档与日志摘要。
- build-manifest、package-verification、artifact-sha256：实际TodayOff启动器两目录、签名/ZIP CRC、源码一致；构建清单保持提交前dirty事实，不改写签名包。

10张最终图及3张反例均逐张查看。最终8张入口/三路线图来自build/c3a-bookshop-final；同源码的闭馆/地图两图来自补日光同步后的build/c3a-bookshop-verified；后者完整三路线同样成功，render.json来自后者，具体归档文件摘要见image-sha256.json。

生成工具为tools/render_city_bookshop.gd，隐藏NO_FOCUS根窗口/1440×900子视口，鼠标保持可见。观察相机与玩家近处交互位置用于取证，居民没有为合照而传送；连续玩家行走另由tests/city_bookshop_test.gd从书屋门外验证。共享时钟固定09:00，闭馆时手动推进到20:00并同步日光。本轮未执行最终正常呈现帧率或双模式长期性能验收。

仍可见原型环境、重复人物和通用站立手势；这些画面证明场所/事件工程运行，不证明最终GTA VI视听或玩家体验通过。
