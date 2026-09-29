# S2 候选人物制作证据

本目录证明制作管线与实际候选复核，**不证明正式人物通过**。候选未替换游戏资源。

- `candidates.json`：第二轮三 GLB 摘要、网格/骨骼/材质与完整配方。GLB 在 build 中，按制作源可重建，不重复提交大文件。
- `inspection.json`：三人结构检查0失败；该检查故意只判断接口，不将外观列为通过。
- `capture-manifest.json`：运行时、工具/配方摘要，900×1000、FOV32、光照与正侧背/脸部机位、26 PNG 摘要。预览是单独背景中的候选，不是公司实景或游玩镜头；没有音轨。
- 24 个 `protagonist/lin_lan/a_cheng-*.png`：第二轮实际渲染，正侧背、中性、眨眼、抬眉、皱眉、张口。全部已逐张查看。眼睛修复可见；嘴角穿面、眉部尖角、鞋裤接缝和发片边缘仍可见，整体拒收。
- `rejected-v1-*`：首轮两张反例和三人候选摘要，分别保留眼球外层遮挡、林岚服装不符；不可拿首轮图片作为最新候选。
- `checks.json`：50项Godot/14项Python、原件/重建一致性、结构及未通过外观的分开结论。

截图使用后台隐藏、不可聚焦窗口和 SubViewport，不捕获指针、不置顶或切前台。原始运行日志在 `logs/characters-offscreen-v2.log`，完成标记 `OFFSCREEN_CHARACTERS images=24 pointer_visible=true`；关键设置和结果已在此保存，不能以其渲染循环衡量游戏性能。
