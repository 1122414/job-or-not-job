# 最新实际包核心路线后台复核

2026-10-10，在7264974b不可变PCK上完成九项检查，全部exit0、成功标记存在且无ERROR/SCRIPT ERROR。运行输入及PCK前后相同，源码HEAD为41a3584（包含实现9f5f7a8），无运行输入未提交修改。

- [逐项命令、日志和耗时](results.json)，[身份](identity.json)，[外部驱动来源](external-drivers.json)，[实际存档摘要](save-hashes.json)。
- 包外十个脚本只替换`res://tests/`依赖路径和朋友事件`res://build/friend-handover`输出目录；产品`res://scripts`/`res://scenes`仍由TodayOff启动器从PCK加载。断言未改。原测试见`tests/autumn_prologue_test.gd`、`autumn_full_story_test.gd`、`friend_handover_test.gd`、`departure_response_test.gd`、`free_chat_context_test.gd`，结尾探针见`tools/verify_autumn_ending.gd`。
- 工作目录为/tmp，headless固定60Hz；没有创建前台窗口，没有云端请求。实际隔离存档保留在`build/core-package-recheck/`，不涉及用户存档。
- [首次尝试](initial-attempt/results.json)：序章/主线通过；朋友夹具遗漏创建目录路径迁移，引擎报告三次无法创建res://build。虽然exit0/断言0失败，日志扫描仍拒收。纠正外部路径后重新执行所有九项，没有把失败结果补写成通过。

九项为五个原测试、一次独立结尾恢复和三次独立朋友结果恢复；不计作九个新测试文件，也不计作124项完整套件重跑。本机HTTP验证上下文与协议，不验证真实模型语义。完整目标未完成，系统IME、自然体验/听音、前台长路线性能及云端质量继续开放。详见[验收](../../2026-10-10_最新包核心路线后台复核验收.md)。
