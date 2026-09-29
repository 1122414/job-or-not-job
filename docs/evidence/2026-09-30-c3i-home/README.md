# C3i 住处与回家生活证据

日期：2026-09-30。范围限本阶段居家场所和既有系统回归；不是完整城区的独立玩家验收。

- [最终运行源码身份](source.json)：513ba886，包含未提交修改的构建身份如实保留。
- [入口修改前](before.json)：原楼体真实前进150帧后受阻，未进行存档写入。
- [最终连续路线](route/route.json)：278.383852m，9张原玩家相机图，实际地图点击/E/选择；18:30至次日09:13。初始位置和时刻为夹具，沙发坐起使用正式交互的有界定位；走路计数排除坐起定位。
- [实际沙发档](route/seated-route.json)、[实际清晨档](route/morning-route.json)：隔离自动路线产生，不是玩家私人存档；分别由新的Godot进程完整重读。
- [入口与交互检查](home-test.json)：测试名称及执行结果在验收文档中列出。
- [沙发初版失败](iteration/before.json)与[正面反例](iteration/sofa-front.png)：裤装穿透0.161693m、鞋0.081319m；[最终蒙皮采样](seat-fit.json)、[最终正面](seat/sofa-front.png)、[最终侧面](seat/sofa-side.png)独立复核。测试限稳定坐姿，不是完整坐起动画。
- `views/`四张房间日夜图使用独立相机夹具，HUD位置仍为原玩家位置；不能把它们记为玩家走到对应机位。
- [最终包GUI](package/verification.json)：实际TodayOff默认Metal，四图含真实E床边与沙发、休息/坐姿JSON恢复。玩家位置为明确夹具，与连续路线分开。
- [最终独立包身份](package-identity.json)：源码、内外清单、PCK、输入及签名后引擎、ZIP CRC/摘要和签名均核对。未把构建时not_yet_verified改成事后通过。
- [同位成本比较](cost-comparison.json)、[实际绘制元数据](cost/render.json)：11视角、1440×900/FOV65、相同Metal后端；东街与总览增加53次调用。冻结绘制计数不是正常FPS。
- `career/`保存最终后台A/B职业路线七张图；实际检查求职、入职、交付、转组、离职/B入职与拒绝/协商/冲突分支。
- [图片清单](images.json)：39张原图、25张实际查看，分别标记，未声称全图已看。
- [早期87项门禁摘要](earlier-suite.json)单独保留；它通过后仍发现坐姿穿透，不能替代[最终88项门禁及专项日志记录](verification.json)。最终进程退出0，全部测试有成功标记、无ERROR/WARNING；日志新鲜度、测试来源和当前运行输入已逐项核对。

主要复现命令（在项目根目录，Godot需指定本机路径）：

```sh
GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot tools/check.sh
python3 -m unittest discover -s tests -p 'test_*.py'
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/city_home_save_test.gd -- --from-route=res://docs/evidence/2026-09-30-c3i-home/route/seated-route.json
/Applications/Godot.app/Contents/MacOS/Godot --headless --fixed-fps 60 --path . --script tests/city_home_save_test.gd -- --from-route=res://docs/evidence/2026-09-30-c3i-home/route/morning-route.json
```

图形使用`tools/render_city_home.gd`，加`--views-only`或`--seat-inspection --source=...`分别复核房间与实际沙发档；工具创建不可聚焦、最小化根窗口，禁根输入、鼠标可见，启动指定Dummy音频。没有扬声器试听或普通帧率结论。完整问题/测试与未完成项见[阶段验收](../../2026-09-30_C3i可进入住处与回家生活验收.md)。
