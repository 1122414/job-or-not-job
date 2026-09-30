# 三关键人物的独立动作烘焙

来源与许可沿用[Quaternius CC0记录](../../../production/quaternius/standard-2025-06-10/README.md)。每人四段上身动作：待机、交谈、步行和跑动。走跑按源左脚前伸对齐周期，并保留程序生成、按体型校正的腿部支撑和根高度；不能复用旧三衣装的共同骨架假设。现阶段仍是作者动作与程序支撑的组合，未声称完整写实运动或动作捕捉。

在仓库根以Godot无窗口分别执行`tools/bake_character_animations.gd -- --cast=protagonist`、`--cast=lin_lan`、`--cast=a_cheng`；不传cast参数重建旧衣装共享资源。每份`*-provenance.json`记录源摘要、目标GLB摘要、上身60Hz采样、源时长/相位、循环接缝和结果摘要；走跑归一为1秒，保留原腿部支撑轨道的采样密度。改变目标模型必须重烘焙；不含运行时重定向开销。

`tests/authored_motion_test.gd`同时检查旧三衣装与三新人，覆盖脚部固定、有效手势和交叉淡出残留；`gait_test.gd`与`seating_test.gd`分别验证步态和坐姿。手势不是手物表面接触验证，精细动作与布料仍待制作。
