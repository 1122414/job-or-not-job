# 城区开放录音原件

日期：2026-09-30。六项来源页均明确标为CC0。仅下载公开免费文件，无采购。下载地址和原件摘要见downloads.json；派生方法与运行文件摘要见assets/audio/city/provenance.json。

| 原件 | 作者 | 来源 | 授权范围 |
| --- | --- | --- | --- |
| traffic.ogg | IgnasD | [high-traffic-road-sounds](https://opengameart.org/content/high-traffic-road-sounds) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| birds.ogg | isaiah658 | [ambient-bird-sounds](https://opengameart.org/content/ambient-bird-sounds) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| engine.wav | domasx2; original pdsounds public-domain recording | [racing-car-engine-sound-loops](https://opengameart.org/content/racing-car-engine-sound-loops) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| waves.flac | jasinski; excerpt by qubodup | [beach-ocean-waves](https://opengameart.org/content/beach-ocean-waves) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| steps.zip | TinyWorlds | [different-steps-on-wood-stone-leaves-gravel-and-mud](https://opengameart.org/content/different-steps-on-wood-stone-leaves-gravel-and-mud) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |
| shop.zip | LEGIT Audio; only the free OpenGameArt files are CC0 | [the-shop](https://opengameart.org/content/the-shop) | [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) |

发动机作者说明为pdsounds公有领域启动录音的剪辑；仅取循环段。The Shop只有OpenGameArt免费文件声明CC0，未把该授权推广到付费音效库。脚步石材只有一个原录音，运行中小幅音调/音量变化；木地板3条、草叶2条交替。地毯由石材样本低通派生，属于暂用拟音，最终材质匹配仍待听音。

处理：44.1kHz单声道、去直流、循环首尾交叉淡入、峰值-6.02dBFS；道路低通降低近处路过感，室内设备声作为低电平房间底声。现有ffmpeg无libvorbis编码器，使用无损PCM WAV和Godot导入，不新增依赖。

原件隔离在.gdignore目录，不进入运行PCK。耳机/扬声器听音及最终品质尚未验收。
