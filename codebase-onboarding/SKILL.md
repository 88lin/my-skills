---
name: codebase-onboarding
description: >-
  分析陌生代码库，说明用途、技术栈、架构、入口、构建测试命令和已有约定。首次接手项目、看懂仓库或生成项目 Agent 说明时使用；已熟悉项目的普通修复、文案或样式修改不自动触发。
metadata:
  origin: ECC
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

适用于首次接触、接手或明确要求理解代码库的任务。先用包清单、配置和代表性调用确认结构，按任务范围读取，不逐文件扫描整个仓库。

- 支持当前客户端，不把 Claude 专属路径或命令强加给 Codex、OpenCode、WorkBuddy、Qoder。
- 默认在对话中输出上手报告。用户要求生成或更新项目约定时，复用已有 AGENTS.md / CLAUDE.md 和文档位置，保留现有规则。
- 普通改动直接读取相关模块；大型多仓库知识库任务可按需使用当前可用的 team-wiki-codebase。
- 脚本和版本依据当前配置确认；示例目录、框架和命令不能当成已经发现的事实。
<!-- LOCAL ROUTING OVERRIDE END -->

# Codebase Onboarding

Systematically analyze an unfamiliar codebase and produce a structured onboarding guide. Designed for unfamiliar projects in Codex, Claude Code, OpenCode, WorkBuddy, and Qoder. Preserve the current project conventions and instruction files.

## When to Use

- First time opening an unfamiliar authorized repository.
- Joining a project or asking for its architecture, entry points, or build and test commands.
- Generating or updating project agent guidance when the user requests it.
- Skip this workflow for a routine change in a repository whose relevant structure is already understood.

## How It Works

### Phase 1: Reconnaissance

Gather raw signals about the project without reading every file. Run these checks in parallel:

```
1. Package manifest detection
   → package.json, go.mod, Cargo.toml, pyproject.toml, pom.xml, build.gradle,
     Gemfile, composer.json, mix.exs, pubspec.yaml

2. Framework fingerprinting
   → next.config.*, nuxt.config.*, angular.json, vite.config.*,
     django settings, flask app factory, fastapi main, rails config

3. Entry point identification
   → main.*, index.*, app.*, server.*, cmd/, src/main/

4. Directory structure snapshot
   → Top 2 levels of the directory tree, ignoring node_modules, vendor,
     .git, dist, build, __pycache__, .next

5. Config and tooling detection
   → .eslintrc*, .prettierrc*, tsconfig.json, Makefile, Dockerfile,
     docker-compose*, .github/workflows/, .env.example, CI configs

6. Test structure detection
   → tests/, test/, __tests__/, *_test.go, *.spec.ts, *.test.js,
     pytest.ini, jest.config.*, vitest.config.*
```

### Phase 2: Architecture Mapping

From the reconnaissance data, identify:

**Tech Stack**
- Language(s) and version constraints
- Framework(s) and major libraries
- Database(s) and ORMs
- Build tools and bundlers
- CI/CD platform

**Architecture Pattern**
- Monolith, monorepo, microservices, or serverless
- Frontend/backend split or full-stack
- API style: REST, GraphQL, gRPC, tRPC

**Key Directories**
Map the top-level directories to their purpose:

<!-- Example for a React project — replace with detected directories -->
```
src/components/  → React UI components
src/api/         → API route handlers
src/lib/         → Shared utilities
src/db/          → Database models and migrations
tests/           → Test suites
scripts/         → Build and deployment scripts
```

**Data Flow**
Trace one request from entry to response:
- Where does a request enter? (router, handler, controller)
- How is it validated? (middleware, schemas, guards)
- Where is business logic? (services, models, use cases)
- How does it reach the database? (ORM, raw queries, repositories)

### Phase 3: Convention Detection

Identify patterns the codebase already follows:

**Naming Conventions**
- File naming: kebab-case, camelCase, PascalCase, snake_case
- Component/class naming patterns
- Test file naming: `*.test.ts`, `*.spec.ts`, `*_test.go`

**Code Patterns**
- Error handling style: try/catch, Result types, error codes
- Dependency injection or direct imports
- State management approach
- Async patterns: callbacks, promises, async/await, channels

**Git Conventions**
- Branch naming from recent branches
- Commit message style from recent commits
- PR workflow (squash, merge, rebase)
- If the repo has no commits yet or only a shallow history (e.g. `git clone --depth 1`), skip this section and note "Git history unavailable or too shallow to detect conventions"

### Phase 4: Generate Onboarding Artifacts

Produce the onboarding guide. Produce or write project instruction files only when the user requests that output.

#### Output 1: Onboarding Guide

```markdown
# Onboarding Guide: [Project Name]

## Overview
[2-3 sentences: what this project does and who it serves]

## Tech Stack
<!-- Example for a Next.js project — replace with detected stack -->
| Layer | Technology | Version |
|-------|-----------|---------|
| Language | TypeScript | 5.x |
| Framework | Next.js | 14.x |
| Database | PostgreSQL | 16 |
| ORM | Prisma | 5.x |
| Testing | Jest + Playwright | - |

## Architecture
[Diagram or description of how components connect]

## Key Entry Points
<!-- Example for a Next.js project — replace with detected paths -->
- **API routes**: `src/app/api/` — Next.js route handlers
- **UI pages**: `src/app/(dashboard)/` — authenticated pages
- **Database**: `prisma/schema.prisma` — data model source of truth
- **Config**: `next.config.ts` — build and runtime config

## Directory Map
[Top-level directory → purpose mapping]

## Request Lifecycle
[Trace one API request from entry to response]

## Conventions
- [File naming pattern]
- [Error handling approach]
- [Testing patterns]
- [Git workflow]

## Common Tasks
<!-- Example for a Node.js project — replace with detected commands -->
- **Run dev server**: `npm run dev`
- **Run tests**: `npm test`
- **Run linter**: `npm run lint`
- **Database migrations**: `npx prisma migrate dev`
- **Build for production**: `npm run build`

## Where to Look
<!-- Example for a Next.js project — replace with detected paths -->
| I want to... | Look at... |
|--------------|-----------|
| Add an API endpoint | `src/app/api/` |
| Add a UI page | `src/app/(dashboard)/` |
| Add a database table | `prisma/schema.prisma` |
| Add a test | `tests/` matching the source path |
| Change build config | `next.config.ts` |
```

#### Optional Output 2: Project Agent Guidance

When requested, generate or update the instruction file used by the current project and client, such as AGENTS.md or CLAUDE.md. Read existing instructions first, preserve their rules, and use one canonical set of project facts. A request to understand a repository produces a guide in the conversation by default; it does not by itself request a new root instruction file. Existing session authorization for a requested edit is sufficient.

```markdown
# Project Instructions

## Tech Stack
[Detected stack summary]

## Code Style
- [Detected naming conventions]
- [Detected patterns to follow]

## Testing
- Run tests: `[detected test command]`
- Test pattern: [detected test file convention]
- Coverage: [if configured, the coverage command]

## Build & Run
- Dev: `[detected dev command]`
- Build: `[detected build command]`
- Lint: `[detected lint command]`

## Project Structure
[Key directory → purpose map]

## Conventions
- [Commit style if detectable]
- [PR workflow if detectable]
- [Error handling patterns]
```

## Best Practices

1. **Don't read everything** — reconnaissance should use Glob and Grep, not Read on every file. Read selectively only for ambiguous signals.
2. **Verify, don't guess** — if a framework is detected from config but the actual code uses something different, trust the code.
3. **Respect existing CLAUDE.md** — if one already exists, enhance it rather than replacing it. Call out what's new vs existing.
4. **Stay concise** — the onboarding guide should be scannable in 2 minutes. Details belong in the code, not the guide.
5. **Flag unknowns** — if a convention can't be confidently detected, say so rather than guessing. "Could not determine test runner" is better than a wrong answer.

## Anti-Patterns to Avoid

- Generating a CLAUDE.md that's longer than 100 lines — keep it focused
- Listing every dependency — highlight only the ones that shape how you write code
- Describing obvious directory names — `src/` doesn't need an explanation
- Copying the README — the onboarding guide adds structural insight the README lacks

## Examples

### Example 1: First time in a new repo
**User**: "Onboard me to this codebase"
**Action**: Analyze the relevant structure and conventions → produce the onboarding guide; add agent guidance only if requested
**Output**: Onboarding guide in the conversation; project instruction edits are a separate requested output

### Example 2: Generate CLAUDE.md for existing project
**User**: "Generate a CLAUDE.md for this project"
**Action**: Run Phases 1-3, skip Onboarding Guide, produce only CLAUDE.md
**Output**: Project-specific `CLAUDE.md` with detected conventions

### Example 3: Enhance existing CLAUDE.md
**User**: "Update the CLAUDE.md with current project conventions"
**Action**: Read existing CLAUDE.md, run Phases 1-3, merge new findings
**Output**: Updated `CLAUDE.md` with additions clearly marked
