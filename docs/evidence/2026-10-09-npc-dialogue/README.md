# NPC反应与自由对话证据

`runtime/`为源码场景，`packaged/`为最终包20261009T041943424615Z-a3602a5d-8ba34c3b。均由`tools/capture_npc_dialogue.gd`最小化无焦点窗口、独立SubViewport、禁止玩家持久化生成；8张图依次为右拳/左拳/推搡/踢击、导师受伤状态、昏迷状态、自由输入、模型设置。

动作4图使用真实玩家attack及碰撞窗口。导师状态图通过明确hit构造受伤/昏迷，再按真实物理帧恢复。自由输入图用显式固定回复夹具，画面注明“尚未连接真实云端”；它只证明界面，不能证明DeepSeek生成质量。不是imagegen概念图。

`package-probes.json`为实际包综合/反馈/本机TCP聊天/新旧救助验证；`package-integrity.json`记录源/PCK/ZIP/运行二进制一致、签名和两个cwd隔离启动。`readonly-save.json`只记录玩家v27原档只读迁移v28结果，不包含私人档内容。完整回归与定向复验结果见regression-results.json/recheck-results.json。

Metal退出既有7 Texture RID警告保持。固定FPS与构造场景不构成自然玩家体验、帧率或中文IME验收。详细边界见[验收文档](../../2026-10-09_NPC反应状态与自由对话验收.md)。
