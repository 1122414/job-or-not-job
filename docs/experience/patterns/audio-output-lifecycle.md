# 空间声音的输出与生命周期

信号：播放节点显示playing但位置声没有输出；固定FPS无窗口测试退出时报AudioStreamPlaybackWAV泄漏；音量界面可点击但键盘端点失效。

诊断与处理：

- 总线项目设置的完整键为`audio/buses/default_bus_layout`，错误缩短名称会保留唯一Master；启动后必须检查实际总线索引，不能只看tres存在。
- 独立SubViewport必须开启`audio_listener_enable_3d`并使用实际Camera3D。通过Master上的AudioEffectCapture取真实混音，再测左右声道，节点playing不证明空间方向可用。
- 捕获使用Dummy驱动及Master静音双重保护；capture_only只在Master静音时允许混音，设置变更继续保持该静音。正式游戏仅当前主场景且窗口有焦点时播放；暂停/失焦停止已有声音。
- 固定FPS脚本很快执行完两帧，真实音频线程可能尚未消费stop。C4e专项在queue_free后等待120ms真实时钟并继续process_frame后退出，原两条WAV/Playback泄漏消失。此为测试退出同步，不建议把任意延时加到正常游戏交互里。

适用范围：本机Godot4.7.1/macOS。真实录音捕获首轮验证一次：左右声道方向、暂停/后台/分类静音通过；最终增强GUI鼠标点击和四滑块Home/End八端点全部通过，见C4e验收。不能由PCM通过推断耳机/扬声器混音或独立玩家体验通过。

支持：`scripts/city_soundscape.gd`、`tests/city_soundscape_test.gd`、`tools/capture_city_audio.gd`。


2026-10-09动态取证反例：Soundscape._ready/start_settings的apply_levels会根据音量解除提前设置的Master静音。隔离Dummy录制需等初始化完成后启用capture_only并明确重新静音，再在输入/每帧前检查守卫；仅设置capture_only不能保证输出条件成立。三条最终PCM非零且丢帧0，验证一次；本次PCM时长短于画面，尚未对齐时钟，不能由无丢帧推断音画同步。支持：tools/capture_response_motion.gd、docs/evidence/2026-10-09-response-motion/checks.json。
