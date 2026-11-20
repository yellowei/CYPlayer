## Why

<!-- Explain the motivation for this change. What problem does this solve? Why now? -->

## What Changes

<!-- Describe what will change. Be specific about new capabilities, modifications, or removals. -->

## Related Surface

<!-- 关联场景：survey conclusions from clarify.md — each entry point / shared
     processing logic / downstream consumer with code evidence and its scoping
     verdict (adapted in this change, or explicitly justified out with a boundary
     rationale confirmed by the user). Verdicts must match the user-confirmed
     verdicts from the clarify.md interview. Shared processing logic changes must
     cover all consuming entry points in this change. A bare "no related impact"
     without search evidence counts as an incomplete proposal. -->

## Implementation Outline

<!-- 实施逻辑：how the change plays out, step by step, in plain business
     language (人话) — where the data comes from, what validation and processing
     it goes through, where it lands, and how each related path scoped in above
     is adapted. Numbered steps. No code-level identifiers (class/method/function
     names) unless the user explicitly asked for technical depth; contract facts
     (table/column/endpoint names) are exempt and stay precise. -->

## Rule Boundary

<!-- 规则边界：required when this change adds or alters a business rule,
     validation or blocking check, or introduces/reorders an execution path;
     otherwise write 「不适用」 + a one-line reason. One table row per rule, plus
     the equivalent-path list. The table form is required so each conclusion can
     be checked item by item. The reasoning method lives in the Rule boundary
     branch of the clarify instruction in schema.yaml - point there, do not
     restate it here.

     | 规则 | 该拦的条件 | 该放的例外与合法反例（附应有处理） | 判定挂载点 |
     |---|---|---|---|
     | <rule> | <minimal condition that blocks> | <exception / legitimate counter-example + intended handling> | <business-intent action the check sits on> |

     Equivalent execution paths: one line per path - the intent, the path, and
     whether the check fires correctly on it. -->

## Capabilities

### New Capabilities
<!-- Capabilities being introduced. Replace <name> with kebab-case identifier (e.g., user-auth, data-export, api-rate-limiting). Each creates specs/<name>/spec.md -->
- `<name>`: <brief description of what this capability covers>

### Modified Capabilities
<!-- Existing capabilities whose REQUIREMENTS are changing (not just implementation).
     Only list here if spec-level behavior changes. Each needs a delta spec file.
     Use existing spec names from openspec/specs/. Leave empty if no requirement changes. -->
- `<existing-name>`: <what requirement is changing>

## Impact

<!-- Affected code, APIs, dependencies, systems -->
