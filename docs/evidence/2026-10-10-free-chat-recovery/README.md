# 自由对话修复证据

- [检查摘要](checks.json)：旧版4个实际失败断言与修复后定向检查。
- [运行输入](source.json)：构建前固定运行代码，基于8a4dfac加本轮修改。
- [实际包三项聊天结果](packaged-results.json)：从/tmp运行新包TodayOff，游戏资源来自PCK，非开发目录。
- [外部测试来源](external-drivers.json)：仅将测试继承路径改为外部路径，不替换游戏逻辑。
- [包完整性](integrity.json)：当前输入/PCK/签名后引擎/ZIP摘要、签名检查及CRC。

原日志在项目logs及build/free-chat-package-check，摘要保留在此。不保存云端原始文本、凭据或用户私人请求。HTTP均为本机协议夹具；真人云端成功率未测，不能用本记录替代。

完整[121项回归](full-suite.json)exit0，导入与隔离启动均无ERROR，运行输入全程保持03d01c5a。修复提交42a292b；当前包创建在提交前，其真实运行输入与提交后相同。
