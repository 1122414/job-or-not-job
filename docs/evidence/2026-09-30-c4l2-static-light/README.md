# C4l.2a 静态光照制作证据

2026-09-30。源码运行输入b58fe7c6，正式游戏没有接入此次候选。对应G05-C4l-C/E与G06-C4l-F/G；详见[验收表](../../2026-09-30_C4l2a静态光照制作管线验收.md)。

- `city/baked`：现场烘焙的配置、源审计和11机位性能记录。原图与`city/loaded`的11图逐字节相同，双摘要见`reload-comparison.json`，不重复存储同一图片。
- `city/loaded`、`city/no-reflection`、`city/baseline`：每组11张原图和完整逐样本；`city/zero-reflection`保留公司A/B及住处白天三图、完整11机位数据。零/非零强度像素差见`reflection-comparison.json`。
- `controls`：三组反射夹具，每组强度0/1原图及实际完成数。环境0是诊断陷阱反例；有效环境下Metal/Vulkan均有彩色反射。
- `final-runs.json`：最终加载、对照、控制的逐进程命令、退出码、成功标记与警告。
- `targeted-checks.json`：静态输入测试、旧分析器、两项预期拒绝检查的命令与结果。
- `tool-checks.json`：最终工具/测试与四资源摘要、检查日志摘要及开放边界。正常图形的7 Texture RID警告明确保留，没有将其算作无警告通过。
- `source-before.json`与`source-after.json`：本阶段运行源码身份。`manifest.json`校验本目录原图与JSON，不包含自己或可继续补充的README。
- `production-load-profile.json`与`production-load-comparison.json`：从最终交付目录直接加载的11机位记录及11张同字节图片摘要，避免只验证临时build路径。

正式制作数据位于`production/lighting/2026-09-30-room-gi/baked`，共8.55MB；文档同步不表示这些二进制资源已进入游戏安装包。

图形进程最小化、不可聚焦、禁根输入、鼠标可见、Dummy音频；游戏放在独立SubViewport，不是当前主场景，不读写玩家档。固定时步60、离线强制绘制与普通玩家FPS不可混用。实际人工查看范围以验收记录为准；自动摘要相同证明文件相同，不替代动态体验验收。
