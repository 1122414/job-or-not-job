# 回应动作与声音记录

当前运行源码c34942f（运行摘要7f9a5bca）；从实际十二周完整路线的v30结尾档正常恢复，邀请见证者和负责人实际走到投影旁。玩家初始取景位置为夹具，再通过游戏内移动接近目标；不是自然玩家走完主线的录像。三条4秒序列各121帧，所有窗口/静音守卫通过。

[检查摘要](checks.json)、[逐帧数据](capture.json)；[起始](before.png)、[接触](contact.png)、[离场](return.png)已目视检查。非冲突无伤害；冲突只有一次100→88、一次字效，镜头偏移0.12后回落；三条路线均移动4.6米，职业与工资不变。受击人物会追近反击，离开不等于没有后果。效果存在与回落可证，不代表舒服或解气。

短视频在本地build/response-motion-v6/{written,leave,conflict}.mp4，为保留逐帧时间差的无声文件，SHA与编码尺寸记在checks.json。音频独立保存为[书面回应](written.wav)、[离开](leave.wav)、[冲突](conflict.wav)。Dummy驱动只捕获实际PCM，Master静音，不播放到设备；三份非零、无缓冲丢帧、峰值低于0.1。音频长度3.62/3.72/3.62秒，与4秒画面不同，未拉伸或伪造同步。未进行主观听音验收。

30Hz画面没有采到短暂hit_pause，不能据此断言不存在，也不把既有反馈测试结果当成此次动态观察。系统IME、真实模型、正常FPS、自然真人体验均未由本次记录验证。

复现：Godot --disable-render-loop --audio-driver Dummy --path . --script tools/capture_response_motion.gd -- --background --output=res://build/新目录 --from-save=实际主线结尾存档。该工具禁止前台捕获，不访问玩家存档和设置。首次无窗口沙箱启动异常退出，正常权限解析检查exit0；最终新增单次效果断言已在本次逐帧数据上独立执行，通过后语法检查通过，未重新录制相同序列。
