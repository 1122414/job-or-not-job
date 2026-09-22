# 项目经验索引

| 机制 | 适用信号 | 验证状态 | 记录 |
| --- | --- | --- | --- |
| 地面碰撞高度差 | 角色在入口停住，视觉上像开放通路 | 本项目验证一次 | [地面接缝](patterns/floor-seams.md) |
| 视觉参考范围与动画观察时序 | HUD 已接近但人物仍是占位；交叉淡入首帧误判静态 | 本项目验证一次，外观待用户反馈 | [视觉范围](patterns/visual-reference-scope.md) |
| 姿态与碰撞支撑不一致 | NPC 倒地后物品仍悬在站立高度 | 本项目验证一次，16 项回归通过 | [身体支撑](patterns/body-support.md) |
| 寻路终点与停止阈值 | 员工到座位附近停住，或细化网格后不前进 | 返岗测试验证一次 | [工位寻路](patterns/navigation-endpoints.md) |
| 内容扩充与 JSON 版本数值 | 新道具导致旧档失效；内存验证通过而文件读回失败 | 本项目验证一次 | [存档扩充](patterns/save-content-expansion.md) |
