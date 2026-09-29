# 天空被雾色覆盖

信号：已创建ProceduralSkyMaterial并更新天顶/地平线颜色，但图中天空仍是一整块灰绿色，改变天空颜色不能明显改善。

机制：Environment的fog_sky_affect默认1，可能将整片天空混成雾色；几何的低fog_density并不保证天空保留渐变。应分别检查真实天空资源、背景模式和天空受雾比例，不能据此断言渲染器没有天空。

处理与证据：C4c检查`main.gd`实际天空和雾设置，保留几何雾密度，将天空受雾比例设为0.18。同镜头昼夜图出现天顶与地平线过渡；`docs/evidence/2026-09-29-c4c-urban/`保存第一版灰天反例和最终图。本机Compatibility验证一次。

参考：[Godot Environment文档](https://docs.godotengine.org/en/4.6/classes/class_environment.html#class-environment-property-fog-sky-affect)。这不证明天气、云层、动态曝光或正式城市光照完成；体积雾和其他渲染器应分别检查。
