# C4e 城区声音证据

日期：2026-09-30。工具：`tools/capture_city_audio.gd`。录音是Godot真实混音PCM，非外部拼接示意；相机为普通玩家相机。环境探针在各地点设置起始位置，只有actual-walking片段使用真实键盘连续行走，因此不称作完整自由游玩。

- `capture.json`：七个场所/时段、行走、左右独立3D声源、暂停/后台/分类静音共13段；753664个双声道采样帧，44100Hz，全部无捕获缓冲丢帧。
- 所有混音峰值<=0.121871，两个方向声源的对应侧RMS约为另一侧1.687倍。暂停、后台和Actions静音三段峰值/RMS均为0。
- `audio-settings.png`：已实际查看；四个音量控件可滚动到达，真实鼠标点击及Home/End共八个端点通过。
- Dummy驱动与Master静音双重保护；根窗口最小化、不可聚焦、无焦点、鼠标可见。没有写玩家游戏档或音量设置。
- WAV可用于后续听音，**本阶段没有完成耳机/扬声器听音签收**。非普通游戏FPS、非完整30—60分钟体验或最终GTA级视听通过。

## 可试听的实际输出

[街道白天](street-day.wav) · [公司A](office-a.wav) · [公司B](office-b.wav) · [书屋](bookshop.wav) · [花园白天](garden-day.wav) · [花园夜晚](garden-night.wav) · [滨水](waterfront.wav) · [实际行走](actual-walking.wav)

[左声源](source-left.wav) · [右声源](source-right.wav) · [暂停](paused.wav) · [动作静音](actions-muted.wav) · [后台](background.wav)

来源和制作：`assets/audio/city/provenance.json`、`production/audio/cc0-2026-09-30/README.md`。底噪、电平与循环接缝的测量只能证明技术条件，不证明素材符合完整城区的最终艺术方向。

后台双公司完整职业及拒绝/协商路线0失败；7张职业图片保存在career/，本轮实际查看defend与handover两张。仍可见人物外观重复和整体画面原型感，本阶段未修改或签收人物美术。
