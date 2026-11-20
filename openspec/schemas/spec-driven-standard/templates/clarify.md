## Open Questions

<!-- Unknowns surfaced during clarification. One per bullet. Cover: problem & intent,
     scope, related-surface survey, data model, business rules, integration
     boundaries, architecture approaches. Resolve them with the user by
     interviewing in rounds over a decision tree: each round asks every currently
     answerable question (numbered, each with a recommended answer); keep going
     until no doubt is left unresolved and nothing is silently assumed. -->

- <!-- question -->

## User Answers

<!-- The user's responses, captured verbatim or summarized. -->

- <!-- answer -->

## Related-Surface Survey

<!-- 关联场景清点：every consumer of the capability being changed, grounded in
     code evidence (file/class/method): functional entry points (API endpoints,
     import/export entries, scheduled jobs, message consumers, frontend calls),
     shared processing logic reused by multiple entry points, and downstream
     data consumers (readers/writers of the tables, fields, events, or export
     artifacts involved). Every entry carries a scoping verdict (adapted in
     this change, or excluded with a reason) confirmed by the user during the
     interview — the frontier is not empty until every entry has one. When
     shared processing logic changes, every consuming
     entry point must be adapted in the SAME change; splitting into separate
     changes requires an explicit boundary rationale confirmed by the user. -->

- <!-- entry point / shared logic / downstream consumer + code evidence + scoping verdict -->

## Architecture Direction

<!-- The crystallized approach: chosen direction, key decisions, 2-3 alternatives
     considered with tradeoffs, and the plan summary the user explicitly confirmed
     (interview answers alone do not count as confirmation; the summary must be
     structured per the seven elements of the plan confirmation gate — including
     the itemized plain-language change list, the plain-language
     implementation outline, the related-surface verdicts and
     the rule-boundary verdicts —
     presented as a plain message listing the key points, never a question-tool
     prompt, and only AFTER the interview was exhausted: presenting the plan or
     asking for its confirmation mid-interview is forbidden, and the recommended
     answer attached to a question is not the plan). This is
     the HARD-GATE output — proposal, specs, design, and tasks must stay consistent
     with what is recorded here. -->

## Authoring Tier

<!-- SIMPLE or COMPLEX, with a one-line rationale (criteria in the clarify
     instruction's Phase 2). SIMPLE: orchestrating agent writes proposal →
     specs → design → tasks itself. COMPLEX: one generation subagent writes
     them. Recorded here for auditability before Phase 2 starts. -->

- Tier: <!-- SIMPLE / COMPLEX -->
- Rationale: <!-- one line -->

## 执行边界

<!-- 由提案阶段 Phase 3 架构审查产出，主代理在复核 PASS 后写入。按任务组列出
     实施范围，机器可读：本小节内第一个 yaml 围栏由实施流程初始化时解析。
     结构：顶层 task_groups，其下以任务组 id（如 "1"）为键，每项包含
       allowed_directories — 非空字符串数组，相对仓库根的允许改动目录
       allowed_packages    — 非空字符串数组，允许新增/修改的包路径
       notes               — 可空，实施建议
     只列该任务组必须改动的目录与包（含其测试），默认不放开整个仓库。
     写法示例（说明用，非真实数据；实际写入时用 yaml 围栏承载）：
       task_groups:
         "1":
           allowed_directories: ["src/core"]
           allowed_packages: ["src/core/x"]
           notes: "可选实施建议"
     本小节缺失或解析失败时，实施流程按整个 worktree 处理。 -->

## Initial Capabilities

<!-- Preliminary guess of which specs will be created or modified (kebab-case names).
     Finalized in proposal.md Capabilities section. -->

- `<name>`: <!-- what this capability covers -->
