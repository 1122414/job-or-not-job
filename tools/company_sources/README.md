# 公司场景制作源

这里保存未合并的可编辑公司场景。运行时加载 `scenes/companies/company_a.tscn` 和 `company_b.tscn`，不加载本目录；现有导出规则排除 `tools/*`。

编辑本目录的公司场景后运行：

```sh
godot --headless --path . --script tools/build_company_spaces.gd -- --output=res://build/company-scenes
godot --headless --path . --script tools/verify_company_batches.gd -- --before=res://tools/company_sources --after=res://build/company-scenes --output=res://build/company-equivalence.json
```

核对几何、材质/顶点属性、碰撞、灯光、锚点与面试对象，通过图形和玩法回归后将两份候选复制到 `scenes/companies/`。不要在批处理网格上改动窗框等单件细节后，再用旧制作源覆盖它。

生成器默认使用本目录；`--source=<目录>`可针对其他已编辑场景烘焙；`--unbatched`跳过合并而保留完整制作节点。`--source=`明确使用最初的程序化模板，仅用于模板开发对照，不用于覆盖已经编辑的制作源。

合并只覆盖五个静态分组，按4米格、同一材质与阴影/层设置聚合；透明材质、局部三平面贴图、已导入模型、文字和互动对象保留原表示。合并不会消减三角形。4米格按物件中心归组，不是每个结果包围盒都小于4米；长构件仍可能跨格，需继续实测剔除和灯光成本。

初次验证：C4b，两家公司436个静态网格成为95批，完整103,632个三角形/材质与顶点属性比较通过；见 `docs/2026-09-29_C4b首区渲染成本验收.md`。正式美术和整城性能未因此通过。
