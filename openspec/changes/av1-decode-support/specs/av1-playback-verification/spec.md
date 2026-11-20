# av1-playback-verification

## Purpose

钉死「零代码迁移」卖点的两个事实：上游重建解码库落地后，整工程不做任何解码 API 调用点迁移即可完整编译通过；具名真 AV1 样片（来源与批准记录见 clarify User Answers 2026-11-20 条）在运行环境经既有渲染通路正常出画面，根目录样本作补充对照。素材甄别先行于断言，防止按文件名标签想当然。

## ADDED Requirements

### Requirement: zero-migration-real-compile

在上游重建产物（前置 change）就位后，工作区 SHALL 在不改动任何既有解码 API 调用点的前提下完成一次真实整工程编译——「零代码迁移」的结论 MUST 由这次真编译取得，不得以静态阅读代替。

#### Scenario: real-build-with-unchanged-call-sites

- **WHEN** 拉取上游重建后的解码库并执行整工程编译，随后核对新式解码 API 调用点清单
- **THEN** 编译通过，且调用点清单与现状盘点逐字一致（一处未改），「零迁移」成立

### Requirement: modern-codec-real-run-picture

对**具名的真 AV1 样片**（本仓测试资产入库副本，源自上游链条消费方 FTP 目录的已验真 AV1 短片——用户 2026-11-20 指示「ftp目录下有一个av1的」，fourcc av01 当场验过、纯视频轨），运行环境 SHALL 经既有渲染通路产出可断言的画面；根目录样本（4k60.mp4、5k120.mkv）降为补充对照、按甄别结果定夺（第 2 轮审查实测并经分派方复测印证：均不含可靠 AV1 流）；精确编码甄别 SHALL 先行完成，断言对象以甄别结果为准。

#### Scenario: identify-before-assert（先后作用）

- **WHEN** 对仓内样本执行精确编码甄别，发现命中标签混有 VP9/dts 字符串等噪声
- **THEN** 后续断言对象以甄别结果为准，MUST NOT 凭文件名或粗筛标签直接断言

#### Scenario: frame-reaches-render-path

- **WHEN** 按既有测试工程的运行约定，用具名真 AV1 样片（入库副本）在运行环境完成一次真跑
- **THEN** 帧抵达既有渲染通路锚点并可被断言，画面正常产出（AV1 原生软解路由生效）

<!-- 跨接口业务链路：本能力为单动作验证，无多端点串联链路；「甄别先于断言」的先后作用已写成场景。 -->
