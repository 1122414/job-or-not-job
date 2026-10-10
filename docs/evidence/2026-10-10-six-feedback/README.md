# 本轮证据

`home-minimap.png`、`home-map.png`、`mentor-body.png`来自tools/render_feedback_oct10.gd后台SubViewport，1280×800，兼容渲染器、Dummy音频，未接管指针。已目视复核。

阶段一：vehicle_escape旧基线4个失败（司机1、导师三朝向3）；增加真实紧贴司机条件后旧转向控制又复现倒退1失败。最终专项与十项相关回归退出0、failures=0且无ERROR。具体命令和边界见上级六项反馈验收。玩家存档只读取位置关系，没有复制完整存档到证据中。

阶段二图像：rental-comparison / rental-contracts展示完整滚动比较和两种签约；resume-preview展示本地导入及发送边界；resume-question / resume-answer展示同一实体面试室里的中文输入。简历和题目是工具内的合成协议夹具，不是实际云端生成效果证据。

2026-10-10只读玩家当前存档复核：隔离恢复成功，persistence=false、rental_forced=false；原卡住车辆倒车2秒，沿车后方向实际移动6.910094m。没有写回玩家存档，没有保存完整私人存档或简历到仓库。

实际包 `20261010T080927691900Z-5fe84622-7bd4995f`：项目目录外使用包内引擎与PCK执行verify_macos、vehicle_escape、rental_interview、resume_interview，全部exit0/成功标记/无ERROR。运行输入与清单一致且runtime_dirty=false，PCK哈希一致，见[verification.json](verification.json)。完整源码检查仍待结束。

最终候选已替换为 `20261010T082439733570Z-1046293e-0e051360`，增加读档过期车辆接触修复。实际包六项verify_macos、vehicle_escape、rental_interview、resume_interview、vehicle_motion、city_response_routes全部exit0/成功标记/无ERROR，源码与PCK摘要再次吻合。上述旧5fe8462包只是中间证据，交付以新包为准。

全套源码检查最终累计127项通过。city_response_routes的实际逻辑失败和friend_handover漏租房前置均保留诊断及复验说明，非一次冻结源码全绿。`verification.json`保存逐项状态和日志摘要，不收录玩家原始存档、真实简历或密钥。
