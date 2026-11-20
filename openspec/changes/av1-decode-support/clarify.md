# Clarify — av1-decode-support

访谈与结构化在上游会话（CYFileBrowser 仓）由主代理完成，决策以用户原话逐字记录于此；本仓 openspec 由用户初始化，三仓同规（spec-driven-standard）。本仓无 AGENTS.md（空集，承母仓先例）；architecture/interface/database 技能类别均无匹配（降级记录在案）。

## Open Questions

决策树逐轮走到的分支（每轮问当时前提已落定的全部问题；顺序按访谈实录）：

- 「解码失败显式报错」的行为契约归谁？（错误码产自本仓——消费方只能显示本仓给得出的东西）
- 「零代码迁移」卖点的既有前提（CYPlayer 早已在用新解码 API）如何用真编译＋真跑钉死？
- AV1 播放路由怎么验证？用什么素材？
- 报错出口机制走哪条？（现存 delegate 协议只挂在音频管理器上；面向消费者的错误面机制需设计阶段勘察后定夺）
- 测试基建放哪？（TestVideoTests 现为纯脚手架 stub）
- 素材真实性归属：根目录 4k60.mp4 / 5k120.mkv 确含现代编码流吗？（当场命中，精确编码甄别在实施时做）
- 复杂度分层判断（SIMPLE/COMPLEX）与撰写方式。

## User Answers

- **「选A1」**——解码库升级到 FFmpeg 4.4 LTS（原生 av1dec 自 4.3 起），消费侧代码零迁移为核心卖点，以一次真编译＋真跑钉死（该验证即本变更职责）。
- **「拆成两个change。无法播放是黑屏，具体报错信息不知道」**——现场核实后确认：错误其实已被检测到（找不到解码器的错误码早就存在），只是没接到界面上；黑屏＝内部知道、外部沉默。接线活归本仓（生产者契约）。
- **「我建议是在CYFFmpeg和CYPlayer中分两个change，这个CYFileBrowser其实是文件浏览器，引入了CYPlayer」**——按所有权拆分：重编归 CYFFmpeg 仓、真编译真跑＋接线归本仓、CYFileBrowser 退纯消费方。
- **「确认」**——对结构化方案摘要（七要素）的直接文字回复，含：显式报错契约归本仓（此前一轮默认假设已明示，用户未反对即视为确认）。
- **「三仓同规。你直接进AB对应的仓库跑propose。」**——三仓统一 spec-driven-standard（schema/config 已同步完毕），用户指示主代理直接进本仓跑 propose 管线；剩余未知项均为事实勘察（无需向用户新提问），答案以上游会话记录为准。
- 链条顺序 A（CYFFmpeg 重编）→ **B（本变更）** → C（CYFileBrowser 端到端钉）仅在各仓 tasks 用前置 change 标注表达；本变更前置 = CYFFmpeg 仓 `ffmpeg-44-lts-rebuild`。
- **「ftp目录下有一个av1的」**（2026-11-20，答第 2 轮审查 Medium 三出路之问）——采纳该已验真 AV1 短片（Big Buck Bunny，约 5MB、纯视频轨）作本仓运行期正向样片：其副本纳入本仓测试资产（入库动作落素材任务），此为「不新建大素材」承诺的唯一例外项、由用户点定。来源系 gitignore 覆盖的运行目录且脚本全管清理——实施启动时先抓取再动手，此脆弱性记录在案；C 仓自有的入库拷贝归 C 的任务，两不相扰。根目录两样本降为补充对照。

## Related-Surface Survey

关联场景清点，逐条附代码位置证据；划定结论均经上游访谈确认（✅=划入本 change，⛔=排除并附理由）：

| # | 关联面 | 代码证据 | 划定结论 |
|---|---|---|---|
| 1 | 核心面：解码失败上报接线 | `CYPlayerDecoder.h:35` cyPlayerErrorCodecNotFound 枚举；返回点 `CYPlayerDecoder.m:103`、约 `:1400-1432`（openHWVideoStream 硬解路，LoggerVideo 只记日志——「内部知道、外部沉默」现场） | ✅ 纳入（把已有错误码接到可见出口；挂载点见 Architecture Direction） |
| 2 | 解码管线已用新 API（零迁移直接证据） | `avcodec_send_packet`/`avcodec_receive_frame` 调用共 **14 处**（`CYPlayerDecoder.m`）：`:3471,3474,3687,3690,3754,3757,3997,4000,4044,4047,4160,4163,4202,4205`（原稿仅列前 5 行子集，按第 1 轮审查 Issue 3 补全；2026-11-20 命令复测） | ✅ 纳入（验证能力主体：真编译＋真跑各一次，钉死「零迁移」卖点） |
| 3 | 上报机制候选 | delegate 协议分布在多处（公共包装类 `CYVideoPlayer.h:22`、slider、控制视图组等），其中挂在音频管理器上的（`CYAudioManager.h:20/44`、`CYPCMAudioManager.h:20/26/31`）为空壳、无报错方法；通知通路 / CYObserverHelper 为候选 | ✅ 纳入（机制在设计阶段勘察现存结构后定夺，附取舍理由） |
| 4 | 测试基建与素材 | `TestVideoTests/TestVideoTests.m` 纯脚手架 stub（testExample/testPerformanceExample，不得弄坏）；演示 app `TestVideo`；根目录样本 `4k60.mp4`、`5k120.mkv`（AV1 标签命中 34/37 处，混有 VP9/dts 字符串，精确编码甄别属实施步骤）；根目录 `test.mp4` = avc1 | ✅ 纳入（既有 stub 保留；验证测试落 TestVideoTests；正向样片采用具名真 AV1 短片入库副本——唯一例外项，见 User Answers 2026-11-20 条；根目录样本降为补充对照） |
| 5 | 渲染通路（出画面的证据锚） | sws_scale 渲染位于 `CYPlayerDecoder.m:2354,2502,2601` | ✅ 纳入（真 AV1 样片出画面的断言锚点） |
| 6 | 上游依赖：CYFFmpeg | podspec 依赖 Masonry + CYFFmpeg | ⛔ 排除，归 CYFFmpeg 仓 change ffmpeg-44-lts-rebuild（前置，顺序 A→B 在 tasks 标注） |
| 7 | 下游消费者：../CYFileBrowser | 其 Podfile :path 引用本仓 | ⛔ 排除，端到端钉归其 change ftp-av1-playback |

共享处理逻辑判定：第 1 行的错误码是全解码器共享出口（不止 AV1），故本次接线的行为契约按规则型变更处理，逐条消费方联动见下方规则边界基线。

## Architecture Direction

**定型**：两能力——`decode-failure-reporting`（规则型：把早已存在的「找不到解码器」错误码接到可见出口）＋ `av1-playback-verification`（真编译＋真跑钉死零迁移与 AV1 原生软解路由）。上报机制候选（delegate 协议 vs 通知通路）由撰写者勘察现存结构后定夺并记录理由。

**规则边界基线**（必须逐条落进 proposal Rule Boundary 表与 design 挂载点）：
- 最小拦截条件：流的编码器在升级后的库里没有可用解码器（功能上成立的例：损坏文件、编码标签与实际流不符；真 VP9 流在升级前后都有可用解码器——现用库符号表已含原生 vp9 解码器，属放行侧例子，原稿误作拦截例，按第 1 轮审查修正；如需第三个例，用甄别后确认「升级后仍无解码器」的真实编码，以符号表为准；AV1 升级后不再命中——这正是验证能力要证的）。
- 应当放行的例外：升级后可解码的流正常播放、不上报。
- 判定挂载点（第 1 轮审查 Issue 1 采纳方案 (b) 定稿，2026-11-20）：挂在「播放失败落定」这个业务动作上——即管线侧所有失败原因共同经过、落定状态前的汇聚动作（`_itemPlayFailed`，定义于 `CYFFmpegPlayer.m:3386`），不挂底层共享函数。该汇聚动作天然宽于「启动失败」，采纳「接受更宽挂载」口径：凡进入此动作的路径一律投递。
- 等价执行路径（逐条结论；含分派方自查全量调用点核实出的全部真实喂入者，判一律「报」；以下行号均属 `CYFFmpegPlayer.m`）：
  - 启动期错误码路径：音频解码失败、解封装/打开文件失败等 → 报，内容与触发原因一一对应（承原结论）。
  - 运行期路径：缓冲超时（`:2373` 分支）、EOF/缓冲监视边缘判定（`:2353`）、音频管线运行期判定点（`:3761/3765`）→ 报；用户投诉「黑屏，具体报错信息不知道」本就涵盖播放中途饿到判定失败的边缘场景，这是选 (b) 不选 (a) 的直接理由。
  - 切换期路径：切流失败（`_isChangingSelections` 分支，`:402`）、切清晰度失败（`_isChangingDefinition` 分支，`:446/489`）→ 报；失败侧原本沉默，判定以不沉默原则为据——成功侧既有显式反馈（showTitle）仅切清晰度为活代码（`:442/485`），切流的在约 `:398` 系注释态，故判定不依赖成功侧状态。
  - 备注：另有两处注释掉的调用点（`:2445/3847`）不计活路径；上述三族加启动期即该汇聚动作的全部活调用点全集（2026-11-20 grep 命令核实）。

**spec 边界**：两个新能力各立条款；测试与被测实现同组。本仓无 DDL/API 端点契约。

## Authoring Tier

- Tier: COMPLEX
- Rationale: 两能力（上报契约为规则型 ＋ 验证契约）、跨 change 前置（整个变更依赖上游 CYFFmpeg 产物落地；第 3 轮 Info② 采纳——合并后已无「跨组」可言）、测试基建从零建，符合 COMPLEX 判据；由全新单会话生成代理撰写其余四件套，本文件（clarify）由主代理亲写。

## 执行边界

第 6 轮（加赛核验轮）架构审查产出；本小节第一个 yaml 围栏为机器可读段。封笔记录：第 1–5 轮均未达 PASS、全部修法已由分派方逐字采纳落地（含计数裁决 14、BBB 具名正向样片、切换期成功侧 showTitle 论据收窄等），第 6 轮对落地后现文全量重审零 findings、validate --strict 绿，正式 PASS。

```yaml
task_groups:
  "1":
    allowed_directories:
      - "CYPlayer/CYVideoPlayer/Player"
      - "TestVideoTests"
      - "CYPlayer.xcodeproj"
    allowed_packages:
      - "CYPlayer/CYVideoPlayer/Player"
      - "TestVideoTests"
      - "CYPlayer.xcodeproj/project.pbxproj"
      - "CYPlayer.xcodeproj/xcshareddata/xcschemes"
    notes: "新增测试文件须同步登记 pbxproj target membership；scheme/TestableReference 接线落共享 scheme（任务 1.7）。入库副本建议落 TestVideoTests/ 下（如 Resources/）；若按老样本惯例落仓根请先扩界。BBB 源今日在盘（../CYFileBrowser/Scripts/dev_fs/ftp/Big_Buck_Bunny_1080_10s_5MB.mp4，易失运行目录），组 1 开工第一件事即抓取（任务 1.4 措辞）。模拟器排除 arm64，真跑用 x86_64/Rosetta destination 或真机。"
```

## Initial Capabilities

- `decode-failure-reporting`: 无可用解码器时必须抵达可见出口——错误码早已存在，接线是增量；规则型契约（最小拦截条件/放行例外/等价路径/挂载点齐备）。
- `av1-playback-verification`: 对升级后的解码库真编译＋真跑各一次，钉死「零代码迁移」与「AV1 原生软解路由生效」。

