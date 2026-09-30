# S4b 城区人物走跑与周期连续性

[验收](../../2026-09-30_S4b城区人物走跑表现验收.md)。本目录仅记录本阶段直接证据，不代表G05或完整城市完成。

- before：旧版本五套外观的走/跑四相位图，共10张。主角walk、林岚walk/run、旧office_female walk四张已查看，其余仅归档。
- after：同机位、曝光和相位的10张候选，全部查看。上身来自Quaternius，腿部与根支撑保持；原裙装拉伸与局部露肤在前后都存在。
- route：普通玩家相机连续输入27.580694m，六图全部查看，包含模拟摇杆量输入、全量输入、Shift、转向和停止。首次位置/时刻为夹具，此后不传送；不等于实体手柄或独立玩家体验。
- package：实际TodayOff在项目外默认Metal的同一输入路线，六图与已查看源码路线逐字节一致；verification.json记录包身份、真实后端和守卫。
- career：A/B完整职业、拒绝、协商和冲突的七张图；查看范围见image-sha256.json。
- source-before/source-candidate/source-final：基线、全套起点、最终包的完整运行输入。全套期间仅更新CREDITS归属文本，差异在suite-source-boundary.json。
- package-identity：实际包、源码/PCK/输入与签名后引擎、ZIP摘要、CRC与签名核验。

所有图形运行最小化、不可聚焦、禁根输入、鼠标可见、Dummy音频且不写玩家档。39张原图已归档，具体实际查看或同字节验证以image-sha256.json为准。91项Godot与30项Python均通过；[verification.json](verification.json)记录逐项测试源码、日志摘要、成功标记与时序。39张图中28张实际查看或与已查看图片逐字节相同，含职业面试与交付两图。

验证入口反例：发布包排除tools，误传res://tools路径后脚本缺失；无窗口进程退出0仍有ERROR。最终改用绝对路径的独立包外探针，同时检查成功标记、错误日志与返回值。失败尝试不计包通过，包本身未为开发工具改变导出排除规则。
