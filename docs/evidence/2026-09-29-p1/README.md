# P1开放环境样本证据

日期2026-09-29，起始提交8be115f，运行时工作区含本阶段修改。正式签收状态见[阶段记录](../../2026-09-29_P1开放资产接入与场景样本验收.md)。

- `compatibility/`与`forward-plus/`：各6张最终图，A/B分别包含街道、接待、候场。街道使用正常玩家镜头；接待/候场是独立资产检查特写，隐藏主角并另设Camera3D，不能称作玩家默认构图。
- `profile-<a/b>-<compatibility/forward-plus>.json`：各3轮普通/混乱，600帧/轮、预热60帧、1280×800；与P0夹具相同，保留原始帧时间和运行时源码摘要。图形性能采样顺序执行，不同时构建/下载。
- `checks.json`：44项Godot、8项Python与新增资产回归摘要；保留新家具导致路线失败及修复记录。
- `before-model-texture-fix/`：模型jpg未压缩/无mipmap时的4份实测，保留反例；最终与修前摘要不同。
- `performance-table.md`：最终24个样本汇总。
- `build-manifest.json`、`artifact-sha256.json`、`package-verification.json`及`packaged-menu.png`：最终独立包身份、摘要和项目外验证。

复现截图：Godot运行`tools/capture_environment.gd -- --output=res://build/environment-preview`；Forward+另加`--rendering-method forward_plus --rendering-driver metal`。均不设置current_scene，确认persistence=false；正式玩家存档不写入。

许可与源文件：`assets/polyhaven/provenance.json`；原始资源未修改，布局与材质在本项目资源中适配。拒收的混凝土02不进入运行时；最终01仅用于公共地面，室内保留地毯。

限制：本目录只证明本轮资源接入、局部观感、逻辑及原型性能。正式人物/动画、整体建筑美术与光照、声音、20分钟路线、最终密度及用户/独立玩家签收仍开放。两种渲染器GPU计时未返回有效数据，不能把零记为GPU开销零。
