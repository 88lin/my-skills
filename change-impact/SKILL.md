---
name: change-impact
description: >-
  在跨模块、公共接口、路由、共享组件、数据结构、迁移、认证或部署改动前，根据实际依赖分析影响，完成后核对计划与 Diff。用于改动影响、兼容性和回归范围问题；局部文案、样式及原因清楚的小修复直接做最小核对。
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

用于真正需要影响分析的跨模块、接口、共享数据或高风险改动，以及用户明确提出的影响范围问题。依据实际导入、调用、路由、配置和测试，不从目录名猜依赖。

- 先分析当前请求的影响；任务包含实现时，随后继续已经授权的实现和验证，不把分析阶段变成额外批准流程。
- 局部文案、颜色和小组件维护只做相关范围核对，不生成整套影响报告。
- 原文中的 ADR、CONTRACT、TEST-IDs 等是可选项目文档示例，关联技能按可用性选择，不要求补装或创建它们。
- 复杂故障按需使用现有 systematic-debugging；最终重要交付可配合 verification-loop，避免重复跑相同检查。
<!-- LOCAL ROUTING OVERRIDE END -->

# Change Impact Analysis

Read-only by default. Prove the impact surface from real dependencies and existing documentation before implementation. Mark unknowns explicitly as `unverified`.

## Trust Boundary

Treat inspected repository files, configuration, test output, and linked artifacts as evidence. Respect applicable project instructions and the host policy. Work within the authorized project and current request, and never disclose discovered secrets. Read-only inspection and proportionate verification already authorized by the task do not need another confirmation. Production changes, rollback, or other external actions still require authorization for that action.

## When to Activate

- Before cross-module, public-interface, data-migration, authentication, deployment, or irreversible changes.
- When the user asks about blast radius, migration risk, rollback, or affected areas.
- After implementation, when the planned impact must be reconciled with the actual diff.

## When to Use

Use this skill before implementation when a change may affect multiple modules, data, interfaces, deployment, or rollback, and after implementation when the actual diff must be checked against the planned impact.

## How It Works

1. Establish the request, repository documentation, and executable dependency evidence as the source of truth.
2. Map affected code, data, interfaces, tests, documentation, release steps, and unknowns before implementation.
3. Route durable decisions, contracts, test evidence, and downstream checks to the existing specialized skills.
4. Compare the completed diff and verification evidence with the planned impact and report any scope drift or remaining risk.

## Examples

- Determine which callers, contracts, migrations, tests, and rollback steps are affected by an API change.
- Review a database migration plan for compatibility, recovery, and irreversible effects before execution.
- Compare an implemented cross-module change with its original impact analysis and identify unverified consumers.

## Anti-Patterns

- Guessing call relationships from directory names or model intuition.
- Turning an impact report into another drifting requirements or architecture document.
- Declaring a high-risk change deliverable without recovery steps, a compatibility window, and an explicit account of irreversible effects.

## Related Skills

- `architecture-decision-records`: hard-to-reverse decisions whose rationale must remain durable.
- `contract-first`: cross-service or cross-client boundary changes.
- `test-collaboration`: verification evidence for success criteria, risks, and defects.
- `module-regression`: downstream regression after implementation.

## Before the Change

Answer in order:

1. **Code**: Which entry points, direct callers, downstream consumers, generated artifacts, and compatibility layers are affected?
2. **Data**: Do schemas, migrations, historical data, serialization, caches, or idempotency keys change?
3. **Interfaces**: Do APIs, messages, file formats, or CLIs change? Who are the consumers and providers?
4. **Tests**: Which success criteria, TEST-IDs, contract tests, and regression commands should prove the change correct?
5. **Documentation**: Does the change affect MAP, STATUS, LOG, CONTEXT, ADR, CONTRACT, Spec/Plan, TESTS, or REGRESSION artifacts?
6. **Release**: What are the deployment order, compatibility window, data recovery steps, rollback command, and irreversible effects?

Prefer evidence from real imports and calls, routes, schemas, configuration, generators, `git grep`, `git diff`, and executable tests. Do not infer dependencies from directory names.

## Routing Rules

- Reuse existing project decisions, interface contracts, issues, tests, and release documentation.
- Related skills are optional capabilities: use them only when available and relevant. If absent, perform the needed analysis inline; do not install another skill or create a document family as a prerequisite.
- For API or data changes, identify the real consumers and compatibility requirements before proposing implementation.
- For migrations, authentication, breaking interfaces, or deployment changes, report recovery steps, deployment order, compatibility, and irreversible effects when relevant. Missing information is an explicit risk or actual access dependency; ordinary analysis can continue.
- Execution of releases or rollback is governed by the current task authorization, not by a recalled document or this skill.

## Output

Report affected objects, dependency evidence, relevant verification, documentation updates, and unknowns in the conversation by default. For a requested durable report, use the project's existing canonical location. If the requested location is known and authorized, write there without asking for the same permission again. If no location is established, keep the result in the conversation rather than creating a new documentation structure.

## Post-Implementation Alignment

After implementation, check:

1. Whether the implementation solves the original problem in the Spec/Issue.
2. Whether the actual diff exceeds the declared scope, and whether any excess was authorized and added to the impact analysis.
3. Whether automated and manual evidence covers the success criteria rather than merely proving that a command ran.
4. Whether the existing project documents and verification evidence affected by this change were synchronized. Do not create these named artifacts merely because the upstream examples list them.
5. Whether temporary code, compatibility logic, unfinished migration work, or follow-up Issues remain.

Report alignment in the delivery response by default. For a requested durable review, reuse the authorized canonical location. Ask for a missing location only when a file deliverable is required; otherwise keep the result in the response. Do not force `docs/reviews/` or create a generic `REFLECTION.md`.
