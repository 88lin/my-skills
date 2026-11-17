---
name: search-first
description: >-
  在新增有复用可能的功能、依赖、外部集成或工具函数前，先检索仓库、已安装 Skills/MCP，再按需要比较维护中的库和实现，选择采用、扩展或自建。普通文案样式、已明确方案的小修复不自动联网调研。
metadata:
  origin: ECC
---

<!-- LOCAL ROUTING OVERRIDE START -->
## Usage Rule

用于确有方案选择或复用可能的新功能、依赖、集成和工具函数。先搜索当前仓库、已有技能与工具；只有需要外部方案时再联网。

- 仓库已有合适实现时直接复用；需求和方案已明确时不重复广泛调研。
- 比较适配当前版本、维护、许可和依赖成本，不因为找到项目就自动安装。
- 外部资料读取按现有 web-access 的静态检索边界处理；本地代码搜索不加载浏览器流程。
- 使用当前客户端的可用工具；没有子 Agent 或未授权分工时以内联流程完成，缺失通道如实说明。
- 用户只要求调研时输出结论；任务已包含实现时继续已授权的最小实现。
<!-- LOCAL ROUTING OVERRIDE END -->

# /search-first — Research Before You Code

Systematizes the "search for existing solutions before implementing" workflow.

## Trigger

Use this skill when:
- Starting a new feature that likely has existing solutions
- Adding a dependency or integration
- The user asks "add X functionality" and you're about to write code
- Before creating a new utility, helper, or abstraction

## Workflow

```
┌─────────────────────────────────────────────┐
│  0. TOOL AVAILABILITY PREFLIGHT             │
│     Check search channels before relying on │
│     them; report skipped channels honestly   │
├─────────────────────────────────────────────┤
│  1. NEED ANALYSIS                           │
│     Define what functionality is needed      │
│     Identify language/framework constraints  │
├─────────────────────────────────────────────┤
│  2. PARALLEL SEARCH (researcher agent)      │
│     ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│     │  npm /   │ │  MCP /   │ │  GitHub / │  │
│     │  PyPI    │ │  Skills  │ │  Web      │  │
│     └──────────┘ └──────────┘ └──────────┘  │
├─────────────────────────────────────────────┤
│  3. EVALUATE                                │
│     Score candidates (functionality, maint, │
│     community, docs, license, deps)         │
├─────────────────────────────────────────────┤
│  4. DECIDE                                  │
│     ┌─────────┐  ┌──────────┐  ┌─────────┐  │
│     │  Adopt  │  │  Extend  │  │  Build   │  │
│     │ as-is   │  │  /Wrap   │  │  Custom  │  │
│     └─────────┘  └──────────┘  └─────────┘  │
├─────────────────────────────────────────────┤
│  5. IMPLEMENT                               │
│     Install package / Configure MCP /       │
│     Write minimal custom code               │
└─────────────────────────────────────────────┘
```

## Decision Matrix

| Signal | Action |
|--------|--------|
| Exact match, well-maintained, MIT/Apache | **Adopt** — install and use directly |
| Partial match, good foundation | **Extend** — install + write thin wrapper |
| Multiple weak matches | **Compose** — combine 2-3 small packages |
| Nothing suitable found | **Build** — write custom, but informed by research |

## How to Use

### Step 0: Tool Availability Preflight

This is agent guidance, not an executable setup script. Check only the channels
that are relevant to the task and project in front of you.

| Channel | Check | If missing |
|---------|-------|------------|
| Repository search | `rg --files` and targeted `rg` queries | State that only visible files were inspected |
| Package registry | `npm --version`, `python -m pip --version`, or project package manager | Use web/docs search and avoid claiming registry coverage |
| GitHub CLI | `gh auth status` | Use public web or local git history only |
| MCP/docs tools | Available tool list or local MCP config | Fall back to official docs/web search |
| Skills directory | Inspect the current skill catalog and `~/.agents/skills`, plus client-specific directories when relevant | Report only directories actually available |

### Quick Mode (inline)

Before writing a reusable utility or adding a dependency:

1. Search the relevant repository code and tests first; check the current skill and MCP tool catalog.
2. If the need remains and external reuse is plausible, inspect maintained packages, official documentation, or implementations appropriate to the project's language and versions.
3. Compare compatibility, maintenance, license, dependency cost, and the amount of custom code required.
4. Adopt, extend, compose, or build based on the evidence. A research-only request stops at the recommendation; implementation proceeds when included in the current task authorization.

Inspect configuration keys or tool names only when needed; do not print credentials from client settings. Unavailable search channels are reported honestly.

### Full Mode (optional delegation)

For a substantial investigation, delegate independent searches only when the active host supports and authorizes delegation. Otherwise run the same comparison inline. The following is an example for clients exposing a compatible agent tool, not a required command:

```
Agent(subagent_type="general-purpose", prompt="
  Research existing tools for: [DESCRIPTION]
  Language/framework: [LANG]
  Constraints: [ANY]

  Search: npm/PyPI, MCP servers, Claude Code skills, GitHub
  Return: Structured comparison with recommendation
")
```

Older Claude Code docs may call this `Task(...)`; use the current agent/subagent
tool name exposed by the active harness.

## Search Shortcuts by Category

### Development Tooling
- Linting → `eslint`, `ruff`, `textlint`, `markdownlint`
- Formatting → `prettier`, `black`, `gofmt`
- Testing → `jest`, `pytest`, `go test`
- Pre-commit → `husky`, `lint-staged`, `pre-commit`

### AI/LLM Integration
- Claude SDK → Context7 for latest docs
- Prompt management → Check MCP servers
- Document processing → `unstructured`, `pdfplumber`, `mammoth`

### Data & APIs
- HTTP clients → `httpx` (Python), `ky`/`undici` (Node)
- Validation → `zod` (TS), `pydantic` (Python)
- Database → Check for MCP servers first

### Content & Publishing
- Markdown processing → `remark`, `unified`, `markdown-it`
- Image optimization → `sharp`, `imagemin`

## Integration Points

### With planner agent
The planner should invoke researcher before Phase 1 (Architecture Review):
- Researcher identifies available tools
- Planner incorporates them into the implementation plan
- Avoids "reinventing the wheel" in the plan

### With architect agent
The architect should consult researcher for:
- Technology stack decisions
- Integration pattern discovery
- Existing reference architectures

### With iterative-retrieval skill
Combine for progressive discovery:
- Cycle 1: Broad search (npm, PyPI, MCP)
- Cycle 2: Evaluate top candidates in detail
- Cycle 3: Test compatibility with project constraints

## Examples

### Example 1: "Add dead link checking"
```
Need: Check markdown files for broken links
Search: npm "markdown dead link checker"
Found: textlint-rule-no-dead-link (score: 9/10)
Action: ADOPT — npm install textlint-rule-no-dead-link
Result: Zero custom code, battle-tested solution
```

### Example 2: "Add HTTP client wrapper"
```
Need: Resilient HTTP client with retries and timeout handling
Search: npm "http client retry", PyPI "httpx retry"
Found: got (Node) with retry plugin, httpx (Python) with built-in retry
Action: ADOPT — use got/httpx directly with retry config
Result: Zero custom code, production-proven libraries
```

### Example 3: "Add config file linter"
```
Need: Validate project config files against a schema
Search: npm "config linter schema", "json schema validator cli"
Found: ajv-cli (score: 8/10)
Action: ADOPT + EXTEND — install ajv-cli, write project-specific schema
Result: 1 package + 1 schema file, no custom validation logic
```

## Anti-Patterns

- **Jumping to code**: Writing a utility without checking if one exists
- **Ignoring MCP**: Not checking if an MCP server already provides the capability
- **Silent skipping**: Reporting "nothing found" when a search channel was unavailable
- **Over-customizing**: Wrapping a library so heavily it loses its benefits
- **Dependency bloat**: Installing a massive package for one small feature
