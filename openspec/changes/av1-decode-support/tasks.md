<!--
  每个 ## N. 是一个独立迭代（task group）：实现 + 测试 + 质量门，组内全部完成后编译通过、测试通过。
  测试并入被测实现所在组；文档/验证/质量门只是随行工作，不构成组的实质内容。
  每个源文件在本文件中最多出现一次。任务按依赖链排列：定义 → 实现 → 测试 → 质量门。
-->

> **前置 change：** 本 change 依赖 CYFFmpeg 仓（同级目录 `../CYFFmpeg`）的 change `ffmpeg-44-lts-rebuild` 完成后才可开始（顺序 A→B，不可并行）。参见该仓 `openspec/changes/ffmpeg-44-lts-rebuild/`。

## 1. 解码失败上报接至可见出口，并钉死零迁移与 AV1 路由（真编译＋真跑）

<!-- 单组为第 1 轮审查 Issue 4 采纳方案 (a) 的合并结果（2026-11-20），8 个任务：协议定义 → 挂载点实现 → 接线测试 → 素材抓取与甄别 → 静态钉死 → 运行期断言 → 可运行性接线 → 质量门。原组 2 无生产代码任务（纯验证），并入本组；两道相同的质量门合并为一道；可运行性接线源自第 2 轮审查 Low④。 -->

- [ ] 1.1 在 FFmpeg 管线面向消费者的协议上新增可选上报回调（向后兼容追加，签名见 proposal 契约变更点第 1 条），落点 `CYPlayer/CYVideoPlayer/Player/CYFFmpegPlayer.h` [spec:decode-failure-reporting#backward-compatible-reporting-channel]
- [ ] 1.2 在「播放失败落定」汇聚动作上实现上报投递：填充既有文案目录的报错内容、状态落定前回调已登记消费者；启动期错误码路径（音频解码失败、解封装/打开文件失败等）、运行期路径（缓冲超时、EOF/缓冲监视边缘、音频管线判定点）与切换期路径（切流/切清晰度失败）均经同一挂载点统一汇入，落点 `CYPlayer/CYVideoPlayer/Player/CYFFmpegPlayer.m` [spec:decode-failure-reporting#visible-outlet-on-decode-failure] [spec:decode-failure-reporting#equivalent-paths-unified-delivery]
- [ ] 1.3 TestVideoTests target 新增测试文件（如 `TestVideoTests/ReportWiringTests.m`）：三面断言——应拦截（无可用解码器最小条件，含损坏文件）、应放行（可解码流正常播放不上报）、等价路径（音频解码失败/解封装失败/运行期缓冲超时/EOF 监视边缘/切流切清晰度失败均经同一挂载点照常送达）＋未登记者不破坏语义；既有 stub 方法保留 [spec:decode-failure-reporting]
- [ ] 1.4 把具名真 AV1 短片的副本抓取入本仓测试资产（来源与批准记录见 clarify User Answers 2026-11-20 条；源目录易失，实施启动即先抓取），作为运行期断言唯一正向样片；并对根目录样本 `4k60.mp4`、`5k120.mkv` 完成精确编码甄别（命中处混有 VP9/dts 字符串，实测均不含可靠 AV1 流，降为补充对照），甄别结果作为补充断言常量的基准（凭甄别结果选断言对象，不凭标签）[spec:av1-playback-verification#modern-codec-real-run-picture]
- [ ] 1.5 TestVideoTests target 新增静态钉死测试文件（如 `TestVideoTests/AV1MigrationPinTests.m`）：真编译通过后，断言新式解码 API 调用点清单与现状盘点逐字一致（**全部 14 处**，`CYPlayerDecoder.m`：`:3471,3474,3687,3690,3754,3757,3997,4000,4044,4047,4160,4163,4202,4205`，一处未改）——「零代码迁移」由此钉死 [spec:av1-playback-verification#zero-migration-real-compile]
- [ ] 1.6 TestVideoTests target 新增运行期测试文件（如 `TestVideoTests/AV1RuntimePlaybackTests.m`）：按既有测试工程运行约定真跑具名真 AV1 样片（入库副本），断言帧抵达渲染通路锚点（`sws_scale` 位点出画面）；对照组 `test.mp4`（avc1）正常播放不上报 [spec:av1-playback-verification#modern-codec-real-run-picture]
- [ ] 1.7 TestVideoTests 可运行性接线：现状无任何 scheme 挂 TestableReference、共享 scheme 的 TestAction 为空（第 2 轮实测），需把测试 target 接入可执行的 scheme/TestableReference 后方可跑断言（落点 xcodeproj 与 scheme 配置）[infra]
- [ ] 1.8 质量门：整工程编译通过＋单元测试全绿（含既有 stub 方法 testExample/testPerformanceExample 未弄坏；运行约定见 design D3）[infra]
