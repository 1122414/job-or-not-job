# 动作接入后性能抽样

M5 Pro，1280×800，600帧/样本、预热60帧，每公司每渲染器3轮；同先前夹具。非最终密度、非20分钟双模式验收；GPU计时不可用。

| 公司 | 渲染器 | 轮 | 状态 | FPS | P95 ms | P99 ms |
| --- | --- | --- | --- | --- | --- | --- |
| a | forward_plus | 1 | normal | 119.98 | 10.328 | 10.501 |
| a | forward_plus | 1 | chaos | 119.48 | 9.759 | 10.818 |
| a | forward_plus | 2 | normal | 119.84 | 10.382 | 10.531 |
| a | forward_plus | 2 | chaos | 119.41 | 9.960 | 10.652 |
| a | forward_plus | 3 | normal | 119.95 | 10.318 | 10.514 |
| a | forward_plus | 3 | chaos | 119.47 | 9.913 | 10.763 |
| a | gl_compatibility | 1 | normal | 59.84 | 17.256 | 18.123 |
| a | gl_compatibility | 1 | chaos | 53.49 | 19.595 | 24.775 |
| a | gl_compatibility | 2 | normal | 59.70 | 17.354 | 17.808 |
| a | gl_compatibility | 2 | chaos | 53.48 | 19.620 | 23.709 |
| a | gl_compatibility | 3 | normal | 59.70 | 17.367 | 18.124 |
| a | gl_compatibility | 3 | chaos | 54.36 | 19.334 | 24.076 |
| b | forward_plus | 1 | normal | 120.01 | 10.400 | 10.632 |
| b | forward_plus | 1 | chaos | 119.38 | 9.841 | 11.298 |
| b | forward_plus | 2 | normal | 119.80 | 10.414 | 10.554 |
| b | forward_plus | 2 | chaos | 119.45 | 9.905 | 10.420 |
| b | forward_plus | 3 | normal | 120.01 | 10.385 | 10.528 |
| b | forward_plus | 3 | chaos | 119.49 | 9.995 | 11.110 |
| b | gl_compatibility | 1 | normal | 65.50 | 16.020 | 17.536 |
| b | gl_compatibility | 1 | chaos | 56.38 | 19.023 | 25.718 |
| b | gl_compatibility | 2 | normal | 64.55 | 16.370 | 17.963 |
| b | gl_compatibility | 2 | chaos | 56.05 | 19.184 | 23.391 |
| b | gl_compatibility | 3 | normal | 64.57 | 16.164 | 17.770 |
| b | gl_compatibility | 3 | chaos | 56.54 | 18.950 | 22.852 |
