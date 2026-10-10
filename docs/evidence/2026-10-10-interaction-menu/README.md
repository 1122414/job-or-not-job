# E交谈误开菜单证据

旧版实际Godot4.7.1桌面autoload仍处理帧；使用current_scene与Viewport E事件、合成上一帧捕获标志（不捕获实际桌面）复现2失败。修复后同测试通过。

[source-results.json](source-results.json)记录八项相关源码回归及导入/隔离启动。原日志在build/interaction-menu-check，以摘要关联。

[packaged-results.json](packaged-results.json)记录实际新PCK在/tmp运行E交谈、页面、聊天恢复和启动检查；[external-drivers.json](external-drivers.json)记录外部驱动来源，仅替换测试继承路径；[integrity.json](integrity.json)记录源码/PCK/引擎/ZIP、签名和CRC。

网页只做指针状态样本验证，未做真实浏览器锁定。上一轮121项属于聊天阶段，此轮八项定向回归不冒称全套。
