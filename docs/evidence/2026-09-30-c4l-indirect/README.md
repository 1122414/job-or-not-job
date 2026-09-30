# C4l.1 间接光技术对照证据

2026-09-30，Godot4.7.1 / M5 Pro。运行输入前后相同，见`source.json`与`source-after.json`。仅图形验证工具和记录修改；没有新游戏包、完整自由试玩或最终画质签收。

## 最终证据

- `probes/`：8组四盒对照，800×600，128次预热+32次采样；各组`probe.png`、`probe.json`；`verification.json`记录完整命令、工具摘要、固定暗面RGB、PNG摘要和后台守卫。五张前置探索中实际查看的主要图与最终同名图字节完全相同；零回弹图经像素测量确认。
- `city/`：baseline、voxel、voxel-biased三候选，每组11机位、3轮、每轮每机位30样本；33原图、99条/2970样本。`verification.json`绑定三个分析工具的实际摘要。
- `cost-summary.json`：从最终原始数组汇总每机位90样本均值/P95，单位为force_draw墙钟毫秒；不是正常游戏帧时间。
- `original-profiler-regression.json`、`tool-checks.json`：旧分析器仍默认10帧预热，9机位/90样本；正常权限无窗口导入无错误/警告。原sandbox导入失败已在技术记录单列，不混作通过。
- `exploratory/`：五次前置9机位单轮探索的原指标，各保留老街/公司A/书屋白天三图。工具当时仍迭代，不与最终工具身份混用。Vulkan运行报告过pipeline cache错误，其结果仅用于诊断。

## 图形观察范围

实际查看了探索阶段基础/SSIL的公司A与老街、Vulkan的公司A/老街及回弹3的书屋、VoxelGI的公司A/书屋昼夜/老街；最终查看了VoxelGI公司A、偏移校准公司A/住处白天/书屋夜间。其余图像只归档，不声称全面人工验收。窗面反射伪影在两种VoxelGI候选中都可见，偏移校准还改变了顶面和接触阴影。

## 复现

从项目根目录先执行：

```sh
python3 tools/build_manifest.py --output build/c4l-new-source.json
```

使用Godot4.7.1，图形工具在真实GPU上运行；保持独立输出目录，禁止覆写本证据。最小示例：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/probe_indirect_lighting.gd --rendering-driver metal --rendering-method forward_plus --disable-render-loop --fixed-fps 60 --audio-driver Dummy -- --no-mouse-capture --mode=sdfgi --indirect=1 --output=res://build/c4l-new-probe
/Applications/Godot.app/Contents/MacOS/Godot --path . --script tools/profile_city_indirect.gd --disable-render-loop --fixed-fps 60 --audio-driver Dummy -- --no-mouse-capture --mode=voxel --identity=res://build/c4l-new-source.json --samples=30 --runs=3 --output=res://build/c4l-new-city
```

探针切换`--mode=baseline|sdfgi|ssil|voxel`、`--indirect=0|1`；SDFGI后端控制使用`--rendering-driver vulkan`。城区偏移控制添加`--voxel-bias=0 --voxel-normal-bias=2`，默认1.5/0。所有正式结果还须检查成功标记、错误日志和工具/输入身份，不能只看退出码。

探针证明算法响应；城区冻结图证明限定机位差异。Metal零GPU计时不可用；Vulkan探索非零GPU另存原指标。没有普通移动/跨探针边界/读档/动态物件/长期帧率证据。下一步按[技术验证记录](../../2026-09-30_C4l城区间接光技术验证.md)继续C4l.2。
