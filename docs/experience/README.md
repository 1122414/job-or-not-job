# 项目经验索引

| 机制 | 适用信号 | 验证状态 | 记录 |
| --- | --- | --- | --- |
| 地面碰撞高度差 | 角色在入口停住，视觉上像开放通路 | 本项目验证一次 | [地面接缝](patterns/floor-seams.md) |
| 视觉参考范围与动画观察时序 | HUD 已接近但人物仍是占位；交叉淡入首帧误判静态 | 逻辑验证有限；09-22 实试玩反例已补充 | [视觉范围](patterns/visual-reference-scope.md) |
| 姿态与碰撞支撑不一致 | NPC 倒地后物品仍悬在站立高度 | 本项目多次回归；防御/坐姿互斥已复核 | [身体支撑](patterns/body-support.md) |
| 寻路终点与停止阈值 | 员工到座位附近停住，或细化网格后不前进 | 返岗测试验证一次 | [工位寻路](patterns/navigation-endpoints.md) |
| 内容扩充与 JSON 版本数值 | 新道具导致旧档失效；内存/JSON类型差异 | 本项目验证一次 | [存档扩充](patterns/save-content-expansion.md) |
| UI 页面状态和来访确认时机 | 叠加面板、暂停快捷键无响应、来访已记而未交谈 | 自动回归通过；UI实机复验，来访整体节奏仍开放 | [未解决观察](unresolved.md) |

| 暂停页面输入归属 | 主页面叠加、暂停帮助失效 | 自动及实机验证一次 | [页面输入](patterns/panel-input-ownership.md) |

| 来访确认后的对象连续性 | 确认老板来访后答辩选项消失，附近工位抢交互 | 定向回归验证一次；完整路线见验收记录 | [来访衔接](patterns/visit-dialogue-continuity.md) |

| 网页平台字体与输入差异 | 中文方框、捕获失败、重复构建扫描产物 | 中文与打包验证一次；边界仍待验 | [网页导出](patterns/web-export-platform-gaps.md) |
