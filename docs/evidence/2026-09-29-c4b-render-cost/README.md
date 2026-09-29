# 首区渲染成本证据

日期：2026-09-29。完整结果和问题/测试表见[验收记录](../../2026-09-29_C4b首区渲染成本验收.md)。

- before/after-profile.json：同一工具、Apple M5 Pro、Compatibility、1440×900，前后各3轮×4视角×90真实绘制样本，另有120预热。保留原始计时、CPU/GPU可用性、完成信号、窗口保护和源码身份。冻结场景诊断，不是游戏FPS或最终双模式性能。
- attribution.json：修改前24组排除诊断，仅用于区分公司几何/道具/人物/公司灯光/太阳阴影的贡献，不代表删掉这些内容后的产品。
- comparison.json：完整前后场景统计、图元守恒和像素差异；viewport render CPU与force_draw墙钟分列，GPU零值不可用。滨水对照仍有约4%墙钟波动，不能全部算成改动收益。
- geometry-equivalence.json：原公司对最终运行场景，103,632三角形/材质与顶点属性比较，碰撞/灯光/锚点元数据/互动对象相同。
- source-rebuild-equivalence.json：从永久保存的未合并制作源默认重建后，再次完整比较，0差异。
- before/after PNG共8张均已逐张查看。最后图与已看候选逐字节一致；image-sha256.json记录校验值。固定镜头/时刻/场景，不是假装自由游玩录像。
- route-interview_hr / route-defend / route-handover为本阶段后台完整职业路线的3张实取图片，均已查看；完整路线、拒绝及协商0失败。其他历史取证未覆盖。
- validation.json保留执行命令、结果、日志摘要与哈希；68项Godot、24项Python、图形路线及两目录实际TodayOff通过。build-manifest/artifact-sha256对应提交前独立包，保留真实dirty标记；验收在包外记录。

两公司仅静态不透明片段合并，所有灯光、阴影、图元和物件保持。不能把这些图片解释为达到GTA VI品质。更广泛移动镜头、整城和玩家体验继续开放。
