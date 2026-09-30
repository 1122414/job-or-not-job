# 四处室内静态光照制作资源

2026-09-30，C4l.2a。两家公司、社区书屋和住处的256级VoxelGI离线数据，共8,551,325字节。仅为制作候选，未被正式游戏加载，不在安装包中；整体品质与运行接入尚未验收。

`baked/`保存四份压缩VoxelGIData；`bake-provenance.json`保存引擎、运行源码、制作器和资源校验和；`bake-inputs.json`记录候选结构节点、动态排除对象与低频材质处理。当前运行输入为b58fe7c6，Godot4.7.1官方a13da4feb。源或制作器变化后必须重烘，不能编辑摘要冒充新资源。

静态代理展开批量网格并保留实例材质；排除人物、可移动道具、面试手机/纸张/盒子、翻页图册和窗帘。世界三平面纹理仅在烘焙代理中以线性空间平均色表示；可见材质保持不变。透明面不作为不透光遮挡，混合表面或不支持的材质会拒绝制作。这是低频回弹近似，不是精确纹理烘焙或动态遮挡解决方案。

在项目根目录复现加载：

```sh
python3 tools/build_manifest.py --output build/room-light-identity.json
/Applications/Godot.app/Contents/MacOS/Godot --path . --fixed-fps 60 --audio-driver Dummy --disable-render-loop --script tools/profile_city_baked_light.gd -- --mode=baseline --samples=10 --runs=1 --identity="$PWD/build/room-light-identity.json" --load-baked="$PWD/production/lighting/2026-09-30-room-gi" --output="$PWD/build/room-light-preview" --no-mouse-capture
```

移除`--load-baked`并选择新的输出目录可重新制作。`--without-reflections`提供无局部反射对照，`--reflection-strength=0`保留探针但关闭其反射强度。工具只创建隔离的后台场景，不接管鼠标、不读写玩家存档。真实图形需要正常本机权限；headless不能验证画面。

局部反射仍有退出时7个Texture RID释放警告，固定机位验证不代表普通移动或持续性能通过。详见[验收边界](../../../docs/2026-09-30_C4l2a静态光照制作管线验收.md)。
