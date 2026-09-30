# C4l.2b 运行室内光照证据

`source.json`是最终运行输入；`verification.json`保留104项测试源码/日志摘要、32项Python结果、实际包摘要与已知警告。`runtime-on/off.json`和`compatibility.json`记录实际后端及逐样本；GPU计时无效不冒充正常FPS。

`final-on-*.png`与`runtime-off-*.png`为同机位开关对照。`walk-*.png`来自实际包玩家镜头连续路线；源码/包12图对照见`walk-comparison.json`。`package-walk.json`及`final-walk.json`保留真实移动/输入/时间/保护状态；`restore.json`是新进程的途中存档恢复。

`atlas-comparison.json`确认atlas容量改为4后11图字节不变；`refresh.json`确认旧反射保持及节点刷新实际变色。`lifecycle.json`为4独立世界，`refresh-lifecycle-node.json`和`limited-atlas.json`为单世界40刷新。单世界退出仍7 Texture RID，4世界28；释放后的纹理计数为负，不作为内存量证据。

完整原始实验在build/c4l2b；本目录只保留可复核的阶段证据，失败探索不计入通过。详细边界见[验收](../../2026-09-30_C4l2b室内光照运行接入验收.md)。
