# Design — av1-decode-support

## Context

动机与关联面见 proposal.md（Why / Related Surface）。此处只记支撑方案的关键现状锚点（均已复核）：

- 错误码枚举在 `CYPlayerDecoder.h:35`（cyPlayerErrorCodecNotFound），人话文案目录在 `CYPlayerDecoder.m:103`；返回点硬解路 `CYPlayerDecoder.m:1400-1432`，软解路另有 `CYPlayerDecoder.m:1517/1598/1698`——证明错误码目录是全解码器共享出口，不止 AV1。
- 新式解码 API 调用点共 **14 处**（`CYPlayerDecoder.m:3471,3474,3687,3690,3754,3757,3997,4000,4044,4047,4160,4163,4202,4205`，2026-11-20 命令复测补全，原稿仅列 5 行子集；零迁移断言基线）；渲染通路 sws_scale 锚点在 `CYPlayerDecoder.m:2354,2502,2601`（出画面断言基线）。
- 面向消费者的协议先例就在管线主类头文件上（`CYFFmpegPlayer.h:57` CYFFmpegPlayerDelegate，含状态变化回调等——D1 所引先例即此，第 3 轮亲验）；公共包装类上另有一个（`CYVideoPlayer.h:22`，2026-11-20 亲验），delegate 协议实际分布于多处（还有 slider、控制视图组等）；其中挂在音频管理器上的两个（`CYAudioManager.h:20/44`、`CYPCMAudioManager.h:20/26/31`）为空壳、无报错方法。
- 公共包装类的可观察 error 属性有文档承诺（support observe），服务 AVFoundation 路线；FFmpeg 管线的公开面上没有错误出口——黑屏＝内部知道、外部沉默，缺口正在这里。
- 测试基建：TestVideoTests target 现为纯脚手架 stub（testExample/testPerformanceExample，不得弄坏）；演示 app TestVideo 存在。

## Goals / Non-Goals

**Goals:**
- 把早已存在的「找不到解码器」等错误码经既有文案目录接到消费者可见出口（行为增量＝接线，不新增错误码）。
- 真编译＋真跑各一次，钉死「零代码迁移」与「AV1 原生软解路由生效」。
- 规则边界三面（拦截/放行/等价路径）各有可执行断言，落 TestVideoTests target。

**Non-Goals:**
- 不动上游解码库构建产物（归前置 change ffmpeg-44-lts-rebuild）。
- 不为下游 CYFileBrowser 端到端钉排任务（归其 change ftp-av1-playback）。
- 不改既有错误码枚举成员；不弄坏 TestVideoTests 既有 stub 方法；不新建大素材。

## Decisions

### D1 上报机制：采用面向消费者协议的可选回调（勘察后定夺）

勘察结论：仓内候选三条——delegate 协议、通知通路（全局广播）、CYObserverHelper（KVO 观察者生命周期助手）。定型选 **FFmpeg 管线面向消费者协议上新增一个可选上报回调**（建议签名见 proposal 契约变更点）。理由：

- delegate 是面向消费者类的既定推送通道（状态变化回调先例在前），@optional 扩展对既有 conformer 零影响，向后兼容。
- KVO 路线落不下：文档承诺的可观察 error 属性只在公共包装类上有、且服务 AVFoundation 路线；FFmpeg 管线公开面无此属性——选 KVO 等于给管线也加一个公开属性，同一契约两处重复定义。CYObserverHelper 本体只是「自动移除观察者」的助手，不是事件总线，作为该路线的配套被一并否决。
- 全局通知广播的先例（设置变更通知）是字符串键的全局广播，不适合逐实例错误；为上报单独引入新模式不划算。
- 取舍代价：弱引用 delegate 意味着未登记回调的消费者收不到上报——这是契约边界而非缺陷，已由 spec 的 non-registering-consumers-unaffected 场景钉住不破坏语义。

### D2 判定挂载点：挂在「播放失败落定」业务动作（汇聚动作，接受其天然宽于「启动失败」）

所有失败原因都汇入同一个汇聚动作（`_itemPlayFailed`，定义于 `CYFFmpegPlayer.m:3386`，内部调 `_playFailedState` 落定状态）后才落定状态；上报投递挂在这个汇聚点上（填充报错内容后、状态落定前回调已登记消费者）。口径为第 1 轮审查采纳定稿（2026-11-20，方案 (b)）：该汇聚动作被非启动期喂入者复用（全量调用点清单见 Rule Boundary Attachment），采纳「接受更宽挂载」——凡进入此动作者一律投递；clarify 基线、proposal 等价路径清单与 spec 场景已相应补全。不挂底层共享函数——详见 Rule Boundary Attachment。

### D3 测试落点与运行约定

单元测试落 TestVideoTests target（既有 stub 方法保留，按能力各新增测试文件）。现状勘察（第 2 轮审查实测）：全仓没有任何 scheme 挂 TestableReference、共享 scheme 的 TestAction 为空——「按现有约定直接跑」今天并不成立，故新增可运行性接线任务（tasks 1.7）：先把测试 target 接入可执行的 scheme/TestableReference，再经 xcodebuild test 在接线后的 scheme 与选定 destination 上执行；podspec 为模拟器排除 arm64（Intel Mac 时代约定），Apple Silicon 上按 Rosetta x86_64 destination 或真机执行。

### D4 素材策略

主断言对象＝**具名真 AV1 样片的入库副本**（用户 2026-11-20 点定 FTP 目录已验真短片，fourcc av01 当场验过、纯视频轨断言更干净；约 5MB，系「不新建大素材」承诺的唯一例外项，批准记录在 clarify User Answers）。来源是 gitignore 覆盖、脚本全管清理的运行目录——实施启动时第一件事就是抓取入库，防蒸发。根目录 4k60.mp4、5k120.mkv 降为补充对照（第 2 轮实测＋分派方复测印证：4k60 为 MPEG-TS 壳混 VP90/dts 噪声、5k120 为真 Matroska 装 AVC/x264，均不含可靠 AV1 流），精确编码甄别先行、断言对象以甄别结果为准；test.mp4（avc1）作「正常播放不上报」的对照组。

## Data Model

本变更不涉及持久化。

## Rule Boundary Attachment

判定挂在「播放失败落定」这一业务动作上——即管线侧的汇聚动作 `_itemPlayFailed`（定义于 `CYFFmpegPlayer.m:3386`，内部调 `_playFailedState` 落定状态）。全量活调用点为分派方自查清单（2026-11-20 grep 命令核实，均属 `CYFFmpegPlayer.m`）：启动期入口分支（`:349` 一带 openFile 出错分支、硬解路返回簇 `:1423`）、运行期监视快照（EOF/缓冲监视 `:2353`、缓冲超时 `:2373`）、音频管线运行期判定点（`:3761/3765`）、切流失败分支（`:402`）、切清晰度失败分支（`:446/489`）；另有两处注释掉的调用点（`:2445/3847`）不计。挂载点就是这个汇聚动作本身，故凡进入它的路径都获得投递——运行期与切换期路径包含在内，这是契约的明示语义（第 1 轮审查采纳方案 (b)，逐条判定记录于 clarify 基线与 proposal 等价路径清单，场景落于 spec）。为何不会被清单之外的流程误触：不属于上述调用点的控制流不会进入本汇聚动作；底层共享函数（逐帧解码循环、共享错误码目录）不挂任何判定、只负责产生原因材料，因此健康流的正常解码等仅复用底层函数而不触及失败落定的流程不会误触。三面场景见 specs/decode-failure-reporting。

## Risks / Trade-offs

- [样本文件名标签与实际流不符（混标）] → 主断言已锚定具名真 AV1 样片（fourcc 当场验过），残余风险转为来源易失（运行目录 gitignore 覆盖＋脚本全管清理）——实施启动即抓取入库（tasks 1.4）；根目录样本仅作补充对照，精确编码甄别先行、断言以甄别结果为准（spec 已把先后作用写成场景）。
- [真跑类断言受运行环境约束（模拟器架构排除）] → 沿用既有测试工程运行约定（D3）；确需人工执行的回归留档于此、不进 tasks：在真机上手动播一次甄别后的现代编码样片，肉眼确认出画面且报错送达。
- [弱引用 delegate 未登记 → 上报不送达] → 契约边界如此（D1）；spec 钉住未登记者行为与今日一致。
- [上游产物未落地时真编译无意义] → 前置 change 标注锁死顺序 A→B，不可并行。

## Migration Plan

链条顺序：A（CYFFmpeg 仓 ffmpeg-44-lts-rebuild）→ B（本变更）→ C（CYFileBrowser ftp-av1-playback），仅以 tasks 顶部前置标注表达。回滚：revert 本变更提交（协议追加＋挂载点实现＋测试文件），无数据状态、无配置残留；回滚后消费者回到「内部知道、外部沉默」的原状。

## Open Questions

- 根目录样本 4k60.mp4 / 5k120.mkv 的最终精确编码标签（实施期甄别即可，仅影响补充对照的取位）；AV1 主断言对象已锚定具名真样片，此未知项不再触契约。
