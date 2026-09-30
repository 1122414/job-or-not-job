# 间接光开关与真实后端贡献

## 信号与机制

环境的SDFGI开关已打开、几何标为Static、灯光配置正确，画面却没有回弹。不能只查属性或降低环境亮度推定有效。后端可在渲染资源写入阶段丢失贡献，另一GI算法可能仍正常。

## 本项目证据

2026-09-30，本机Godot4.7.1 / M5 Pro / Metal Forward+：在同一无环境光四盒场景中，基础、SDFGI间接强度0和1的PNG完全相同，暗面RGB均0。同引擎Vulkan下强度0仍为0，强度1暗面约0.511；Metal VoxelGI强度0为0，强度1约(0.316,0.301,0.301)。SSIL只有局部回弹，不能据此替代结构GI。

完整正负对照验证一次，前置探索同样观察到后端差异；范围仅限该引擎、设备与夹具。官方#120496描述相同症状，#122675修复列在4.8；本项目未逐行审计引擎二进制，不能据工单已关闭断言本机已修复，也不将观察外推到所有Metal功能或后续版本。

## 诊断与处理

使用`tools/probe_indirect_lighting.gd`：固定相机、几何和直接光；关闭天空/环境贡献；明确Static网格和Dynamic灯光；预热128次真实绘制，采样32次，以固定暗面像素区域和零间接强度为控制。`frame_post_draw`逐样本确认绘制，后台不可聚焦、禁根输入、鼠标可见。使用相同引擎更换单次诊断后端，不先改项目默认配置。

小场景证明算法通路，不证明产品画质。再用`tools/profile_city_indirect.gd`比较真实城区、昼夜和局部探针，记录原始指标及画面。Metal GPU计时0记不可用；本次Vulkan可返回非零GPU计时，两者不能混为同一监视器。强制绘制耗时不等于正常游戏帧率。新增光照会改变明暗与反射，正式接入须继续检验移动、边界、动态物体、读档、材料和打包。

## 适用边界与来源

不用于推导GTA品质完成度、不代替持续性能与玩家验收。VoxelGI需烘焙，静态几何改变须重烘；这条路线仍需制作管线与画面验收，不能仅因夹具可见就默认启用。

- `docs/evidence/2026-09-30-c4l-indirect/probes/verification.json`
- `docs/2026-09-30_C4l城区间接光验证与接入计划.md`
- [官方问题](https://github.com/godotengine/godot/issues/120496)、[修复](https://github.com/godotengine/godot/pull/122675)、[VoxelGI边界](https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/using_voxel_gi.html)
