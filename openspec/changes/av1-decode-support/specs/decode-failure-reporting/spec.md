# decode-failure-reporting

## Purpose

定义「播放启动失败必须抵达可见出口」的消费者侧契约：哪些最小条件必须拦截上报、哪些合法情形必须放行、共用同一机制的其它执行路径如何统一抵达。错误码与人话文案目录早已存在，本能力确立的是把它们投递到消费者眼前的义务，而非新增错误码本身。

## ADDED Requirements

### Requirement: visible-outlet-on-decode-failure

当播放失败的成因是「流的编码器在升级后的解码库中没有可用解码器」时，系统 SHALL 在「播放失败落定」这一业务动作上判定并投递（该动作为各类失败原因共同经过、落定状态前的汇聚动作）：把该错误码经既有文案目录填成人话报错内容，通过消费者已登记的回调通道送达；判定 MUST NOT 挂在底层共享函数上。

#### Scenario: blocked-minimal-condition（应当拦截）

- **WHEN** 待播文件的视频流单独命中「库里没有可用解码器」（最小条件即成立，例如损坏文件、或编码标签与实际流不符的文件），消费者已登记上报回调
- **THEN** 消费者收到与「找不到解码器」错误码对应的报错内容（文案来自既有目录，逐字引用），不再静默黑屏

#### Scenario: allowed-decodable-streams（应当放行）

- **WHEN** 流的编码器在升级后的库中有可用解码器（含现代编码——升级后不再命中拦截条件），消费者已登记上报回调
- **THEN** 正常播放出画面，不触发上报；既有状态通知语义照旧

### Requirement: backward-compatible-reporting-channel

面向消费者的上报通道以可选方式扩展既有协议：未实现上报回调的消费者 SHALL NOT 受任何影响，既有状态通知与编译兼容语义 MUST 保持不变。

#### Scenario: non-registering-consumers-unaffected

- **WHEN** 消费者未登记上报回调而发起播放，且发生启动失败
- **THEN** 其行为与今日一致（状态通知照旧、编译不破），无新增强制义务

### Requirement: equivalent-paths-unified-delivery

共用同一上报机制的其它路径（音频解码失败、解封装/打开文件失败，以及复用同一汇聚动作的运行期路径——缓冲超时、EOF/缓冲监视边缘判定——和切换期路径——切流/切清晰度失败）SHALL 经「播放失败落定」同一业务动作统一抵达可见出口，上报内容与其各自触发原因一一对应。

#### Scenario: allowed-on-equivalent-path-audio-decode（同一业务意图的其它执行路径）

- **WHEN** 音频流命中无可用解码器（含音频管线运行期判定点命中）并导致播放失败落定，消费者已登记上报回调
- **THEN** 上报照常经同一挂载点投递，内容与音频侧触发原因一致

#### Scenario: allowed-on-equivalent-path-demux-open（同一业务意图的其它执行路径）

- **WHEN** 解封装/打开文件环节失败导致播放失败落定，消费者已登记上报回调
- **THEN** 上报照常经同一挂载点投递，内容对应该环节的既有错误码文案

#### Scenario: allowed-on-equivalent-path-runtime-buffer-timeout（复用同一汇聚动作的运行期路径）

- **WHEN** 播放进入既有缓冲超时判定（等待超过上限）导致失败落定，消费者已登记上报回调
- **THEN** 上报照常经同一挂载点投递，内容对应其触发原因，既有状态落定语义不变

#### Scenario: allowed-on-equivalent-path-runtime-eof-monitor（复用同一汇聚动作的运行期路径）

- **WHEN** 播放经 EOF/缓冲监视的边缘判定走到失败落定，消费者已登记上报回调
- **THEN** 上报照常经同一挂载点投递，内容对应其触发原因，既有状态落定语义不变

#### Scenario: allowed-on-equivalent-path-switching-failure（复用同一汇聚动作的切换期路径）

- **WHEN** 消费者已登记上报回调，播放中途切流或切清晰度失败并走到失败落定
- **THEN** 上报照常经同一挂载点投递，内容对应切换失败的触发原因；切换成功的既有显式反馈不变

<!-- 跨接口业务链路：不适用——本变更为单仓库内单一业务动作的行为契约，无多端点按业务顺序串联的链路；素材甄别先于断言的先后作用已在 av1-playback-verification 能力中写成场景。 -->
