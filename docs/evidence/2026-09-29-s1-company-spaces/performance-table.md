# 双公司短时性能记录

M5 Pro，1280×800，预热120帧，3轮×每情景600帧，顺序运行，窗口置顶。Schema3全部24情景共14,400样本均有实际绘制帧增量。不是1440p/1080p长路线验收。

| 渲染器 | 公司 | 轮次 | 情景 | FPS均值 | P95 ms | P99 ms | 最大 ms | 未绘制样本 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| forward_plus | a | 1 | normal | 142.56 | 8.990 | 12.347 | 23.090 | 0 |
| forward_plus | a | 1 | chaos | 137.52 | 10.778 | 11.961 | 18.591 | 0 |
| forward_plus | a | 2 | normal | 142.83 | 8.949 | 10.217 | 12.510 | 0 |
| forward_plus | a | 2 | chaos | 143.11 | 8.975 | 10.610 | 18.246 | 0 |
| forward_plus | a | 3 | normal | 141.91 | 9.001 | 10.783 | 12.195 | 0 |
| forward_plus | a | 3 | chaos | 139.84 | 10.120 | 12.036 | 18.852 | 0 |
| forward_plus | b | 1 | normal | 133.78 | 10.828 | 13.130 | 13.354 | 0 |
| forward_plus | b | 1 | chaos | 138.12 | 10.250 | 12.755 | 19.168 | 0 |
| forward_plus | b | 2 | normal | 135.18 | 10.693 | 12.886 | 13.763 | 0 |
| forward_plus | b | 2 | chaos | 136.68 | 10.608 | 12.795 | 18.069 | 0 |
| forward_plus | b | 3 | normal | 131.63 | 11.619 | 13.172 | 14.147 | 0 |
| forward_plus | b | 3 | chaos | 138.42 | 10.229 | 12.810 | 16.461 | 0 |
| gl_compatibility | a | 1 | normal | 53.58 | 21.465 | 22.596 | 27.441 | 0 |
| gl_compatibility | a | 1 | chaos | 103.01 | 20.920 | 24.637 | 39.784 | 0 |
| gl_compatibility | a | 2 | normal | 52.97 | 21.380 | 23.403 | 25.940 | 0 |
| gl_compatibility | a | 2 | chaos | 48.64 | 23.888 | 25.994 | 46.822 | 0 |
| gl_compatibility | a | 3 | normal | 45.11 | 31.149 | 34.339 | 68.568 | 0 |
| gl_compatibility | a | 3 | chaos | 57.99 | 20.500 | 23.218 | 34.139 | 0 |
| gl_compatibility | b | 1 | normal | 56.76 | 20.269 | 23.022 | 25.936 | 0 |
| gl_compatibility | b | 1 | chaos | 48.46 | 24.432 | 29.563 | 41.425 | 0 |
| gl_compatibility | b | 2 | normal | 57.33 | 19.950 | 21.316 | 28.222 | 0 |
| gl_compatibility | b | 2 | chaos | 102.47 | 14.712 | 17.393 | 28.751 | 0 |
| gl_compatibility | b | 3 | normal | 55.81 | 20.390 | 22.243 | 26.713 | 0 |
| gl_compatibility | b | 3 | chaos | 49.47 | 22.409 | 25.609 | 40.299 | 0 |

两种渲染器的GPU计时仍全零，仅记不可用。Compatibility样本波动较大；不能归因于单项GPU/CPU瓶颈或据此宣布正式双模式达标。原始帧、绘制增量、内存和绘制量保存在相邻JSON。首次无绘制守卫的数据留于build诊断，未计入此表。

默认渲染器保留Compatibility；Forward+短测有成本优势，但正式GI/反射/密度尚未接入，需要同位画面与最终路线再选型。

此表记录用户纠正前实际采样条件。之后禁止自动验证置顶/拉前台/捕获鼠标；不是后续操作建议。
