# CH1-A 蒙皮修复证据

2026-09-30。只覆盖旧三类人物负权重修复；不证明外观重制合格。

- `full-check.log`：104个Godot测试脚本完成、进程0、无SCRIPT ERROR/ERROR；101项使用failures=0标记，另3项不同标记。GLB及动作内容与最终包一致。来源JSON随后更新为最终配方摘要，最终Python与包另验。
- `python-final.log`：34项通过，包括原GLB重建、限定字节改动、归一化、幂等、坏数值拒绝。
- `package-probe-final.log`：实际TodayOff完成PACKAGED_SMOKE_OK及3类导入皮肤数组检查。
- `package-import-probe.log`：GLB原文件在导出包不存在，但导入资源存在；身份通过包manifest源摘要及实际加载网格联合检查。首次错误的原文件hash检查失败，不混作最终通过。
- `package-locomotion.gd`与日志：独立包6类人物×走跑×4相位，12张图；保留3张人工查看的受影响样本。最小化、无焦点、鼠标可见。
- 前后各3张同位PNG：女性裙摆依然拉宽，不能据负值归零关闭CH1-C。没有把所有截图都宣称人工逐张接受。
- manifest与artifact摘要记录实际包fa2b0735。PCK摘要匹配、ZIP CRC通过、签名验证通过（打包器强制执行）。原始更多图位于build/character-rework。

已观察：服装/头发仍是原外观，跑步肩背/裙摆轮廓仍不自然。当前提交只处理非法权重。未来人体/衣装样板必须独立近景和动作检查。
