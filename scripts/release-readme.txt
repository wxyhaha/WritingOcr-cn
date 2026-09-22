手稿 · 手写中文文章数字化工具
================================

启动方式
--------
双击 release-launch.bat。正式安装包安装后，也可以直接从开始菜单启动。

运行环境
--------
Windows 10/11 64 位。Python、Qt、PaddleOCR 和 PP-OCRv5 模型已随发布包携带，
无需在目标电脑上安装开发工具或单独配置 Python。

首次启动
--------
首次启动可能需要几秒钟加载 OCR 模型。若 Windows 防火墙询问局域网访问权限，
允许“专用网络”即可使用手机加图功能。

故障排查
--------
运行 diagnose-release.bat 查看运行库、Python、OCR 依赖和模型缓存状态。
详细日志位于：%USERPROFILE%\Documents\HandwritingOCR\logs\app.log

卸载
----
请从 Windows 设置的“应用”中卸载。用户数据位于文档目录下的
Documents\HandwritingOCR，不会因为卸载程序而自动删除。
