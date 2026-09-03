# Language-Agnostic Migration Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor workflow migration hiện tại thành framework không phụ thuộc công nghệ, hỗ trợ onboarding, greenfield/incremental và project migration pack nhưng giữ nguyên runtime thuần Superpowers.

**Architecture:** `commands/*.md` tiếp tục là launcher mỏng; `skills/aitoolkit/*/SKILL.md` là orchestrator chứa bảng bước, mode policy và gate; step-skill giao tiếp qua artifact Markdown trong `docs/aitoolkit/<run>/`. Project profile và project pack nằm trong `docs/aitoolkit/`; không tạo workflow manifest, state engine, `.aitoolkit/run-*` hoặc resume interpreter.

**Tech Stack:** Markdown skills/templates, YAML project profile, JSON plugin metadata, PowerShell development validator, Claude Code plugin validation.

## Global Constraints

- Không thêm `workflows/*.manifest.yaml`, `state.json`, `--resume`, `.aitoolkit/run-*` hoặc engine điều phối.
- Migration core không chứa `QML`, `Luna Service`, `Flutter`, `Riverpod`, `Clean Architecture`, `flutter analyze` hoặc `flutter test`.
- `greenfield` bắt buộc dùng `architecture_policy: design-new`.
- `incremental` bắt buộc dùng `architecture_policy: preserve-existing` và ưu tiên `reuse → extend → create`.
- Step thiếu evidence/input/decision bắt buộc ghi `result: blocked`; orchestrator dừng và hỏi người dùng.
- Command resolution: explicit profile → project scripts/config → marker detection → human gate.
- Profile, pack và run artifact nằm dưới `<project>/docs/aitoolkit/`.
- Feature và bugfix orchestrator không đổi bảng bước hoặc gate.
- Skills được sửa/tạo phải dùng `superpowers:writing-skills`; behavior change phải theo TDD.
- Mỗi task kết thúc bằng verification xanh và commit riêng.
- Mọi lệnh `Run:` chạy từ source root `AIToolkit/AIToolkit-main` trừ khi ghi rõ chạy từ git root.

---

## File Map

| Khu vực | Trách nhiệm |
|---|---|
| `aitoolkit/tests/validate-migration-framework.ps1` | Static regression suite; không phải runtime dependency |
| `aitoolkit/skills/aitoolkit-schemas/SKILL.md` | Project profile và artifact contract |
| `aitoolkit/templates/migration/*` | Generic migration artifact templates |
| `aitoolkit/skills/migration/*` | Generic/mode-aware migration steps |
| `aitoolkit/skills/aitoolkit/migrate/SKILL.md` | Migration orchestrator và conditional policy |
| `aitoolkit/commands/migration-onboarding.md` | Claude launcher cho onboarding |
| `aitoolkit/skills/aitoolkit/migration-onboarding/SKILL.md` | Onboarding orchestrator |
| `aitoolkit/skills/migration-onboarding/*` | Inspect, classify mode và create pack |
| `aitoolkit/examples/project-packs/webos-qml-flutter/*` | Compatibility knowledge tách khỏi core |
| `aitoolkit/skills/shared/*` | Rule resolution từ project pack/profile |
| `aitoolkit/codex/skills/aitoolkit/SKILL.md` | Codex workflow router |

### Task 1: Static validation harness và contract baseline

**Files:**
- Create: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit-schemas/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/templates/migration/project-profile.yaml`

**Interfaces:**
- Produces: validator `-Check Encoding|Contracts|Templates|Skills|Orchestrators|Onboarding|Compatibility|Docs|All`.
- Produces: profile v1 và artifact field `result: complete | partial | blocked`.

- [ ] **Step 1: Viết validator RED cho contract**

Tạo PowerShell script với root suy từ `$PSScriptRoot`, collection `$errors`, dispatcher theo `-Check`, và `Test-Contracts` kiểm tra:

```powershell
param(
  [ValidateSet('Encoding','Contracts','Templates','Skills','Orchestrators','Onboarding','Compatibility','Docs','All')]
  [string]$Check = 'All'
)
$ErrorActionPreference = 'Stop'
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$errors = [Collections.Generic.List[string]]::new()

function Require-Token([string]$Text, [string]$Token, [string]$Context) {
  if ($Text -notmatch [regex]::Escape($Token)) { $errors.Add("$Context missing: $Token") }
}

function Test-Contracts {
  $schemaPath = Join-Path $root 'skills/aitoolkit-schemas/SKILL.md'
  $profilePath = Join-Path $root 'templates/migration/project-profile.yaml'
  if (-not (Test-Path $profilePath)) { $errors.Add('Missing project profile template'); return }
  $text = (Get-Content -Raw -Encoding utf8 $schemaPath) + (Get-Content -Raw -Encoding utf8 $profilePath)
  @('schema_version: 1','migration:','mode: unknown','architecture_policy: unknown',
    'project_pack:','docs/aitoolkit/migration-project','result: complete | partial | blocked') |
    ForEach-Object { Require-Token $text $_ 'Contracts' }
  if ($text -notmatch 'greenfield.*design-new' -or $text -notmatch 'incremental.*preserve-existing') {
    $errors.Add('Missing migration mode invariant')
  }
}
```

Script gọi function khi `$Check -in 'Contracts','All'`, in tất cả errors và exit 1; nếu sạch in `PASS: migration framework ($Check)`.

- [ ] **Step 2: Chạy RED**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts`

Expected: FAIL `Missing project profile template`.

- [ ] **Step 3: Mở rộng schema và tạo profile template**

Giữ project-profile hiện có để shared verification tương thích, thêm contract đúng spec §6–7. Profile template chứa đầy đủ:

```yaml
schema_version: 1
project: { id: unknown }
change_type: migration
migration: { mode: unknown, unit: feature, architecture_policy: unknown }
legacy: { path: null, language: unknown, framework: unknown }
target: { path: null, language: unknown, framework: unknown }
documents: { requirements: [], migration: [], uiux: [] }
base_branch: null
test_cmd: null
lint_cmd: null
build_cmd: null
coverage_cmd: null
review_focus: []
verification: { behavior_parity: required, regression: optional, visual_fidelity: optional }
project_pack: { path: docs/aitoolkit/migration-project, reviewed_at: null, review_evidence: null }
# invariants: greenfield => design-new; incremental => preserve-existing
```

Artifact contract giải thích `status: draft|approved` khác `result: complete|partial|blocked`; `blocked` dừng orchestrator, lỗi thực thi không được coi là artifact hoàn tất.

- [ ] **Step 4: Thêm Encoding check**

Scan `.md`, `.yaml`, `.yml`, `.json`, `.ps1`; fail khi gặp mojibake regex `Ã.|Â.|â†|â€”|Ä‘|Æ°`. Không sửa file nếu check không báo evidence.

- [ ] **Step 5: Chạy GREEN**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Contracts`

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Encoding`

Expected: cả hai PASS.

- [ ] **Step 6: Commit**

```powershell
git add AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1 AIToolkit-main/aitoolkit/skills/aitoolkit-schemas/SKILL.md AIToolkit-main/aitoolkit/templates/migration/project-profile.yaml
git commit -m "feat: define native migration contracts"
```

### Task 2: Generic migration templates

**Files:**
- Create: `AIToolkit-main/aitoolkit/templates/migration/{input-report,discovery,requirements-uiux,inventory,mapping,gaps-conflicts,technical-design,migration-plan,bootstrap-report,implementation-report,parity-report,regression-report,onboarding-input,project-inspection,mode-proposal,project-pack-review}.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`
- Retain: existing top-level templates for feature/bugfix compatibility.

**Interfaces:**
- Produces: 16 generic templates with `status`, `result`, evidence and unknowns.

- [ ] **Step 1: Thêm Templates assertions RED**

Validator duyệt exact name list; mỗi file phải chứa `result:`, `## Evidence`, `## Unknowns`, `## Verdict`. Mapping phải chứa `reuse | extend | create | replace | omit`; implementation phải chứa changed files và trace IDs; parity/regression phải chứa scenario, command/evidence và verdict.

- [ ] **Step 2: Chạy RED**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates`

Expected: FAIL, liệt kê 16 template thiếu.

- [ ] **Step 3: Tạo templates tối thiểu theo contract**

Mỗi template dùng:

```yaml
---
step_id: <orchestrator-provided>
status: draft
result: complete
produced_at: <yyyy-mm-dd>
---
```

Các bảng/section cụ thể:

- discovery: features/screens/components/states/services/dependencies;
- requirements-uiux: requirement ID, UIUX ID, state/interaction, source;
- inventory: stable ID, source refs, target refs, migration status;
- mapping: requirement IDs, source/target refs, strategy, rationale, approval;
- gaps-conflicts: evidence, impact, options, owner, decision;
- design: mode/policy, target conformance/new architecture, trace IDs;
- plan: ordered migration units, dependencies, acceptance;
- implementation: changed files, trace IDs, commands/results;
- parity/regression: scenarios, baseline, actual, verdict.

- [ ] **Step 4: Chạy GREEN**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Templates`

Expected: PASS.

- [ ] **Step 5: Commit**

```powershell
git add AIToolkit-main/aitoolkit/templates/migration AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: add generic migration artifacts"
```

### Task 3: Generic front-half migration skills

**Files:**
- Create: `AIToolkit-main/aitoolkit/skills/migration/validate-inputs/SKILL.md`
- Replace: `AIToolkit-main/aitoolkit/skills/migration/discovery/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/skills/migration/analyze-requirements-uiux/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/skills/migration/build-inventory/SKILL.md`
- Replace: `AIToolkit-main/aitoolkit/skills/migration/feature-mapping/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/skills/migration/analyze-gaps-conflicts/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: profile path, project-pack path, source/docs và previous artifact path do orchestrator truyền.
- Produces: artifacts 01–06.

- [ ] **Step 1: Dùng writing-skills tạo pressure scenarios RED**

Chạy baseline scenarios không nạp skill mới, ghi kết quả vào scratch ngoài repo:

1. Legacy không có marker rõ: agent có đoán framework không?
2. Requirements mâu thuẫn legacy behavior: agent có tự chọn một nguồn không?
3. Incremental mapping có target component dùng lại được: agent có tạo mới song song không?

Expected RED: source hiện tại hardcode webOS/Flutter hoặc không có contract conflict/evidence.

- [ ] **Step 2: Thêm Skills validator RED**

Yêu cầu sáu skill tồn tại và mỗi skill chứa `Core principle`, `Evidence`, `Unknowns`, `result: blocked`, `Hợp đồng đầu ra`. Scan riêng sáu skill và sáu template tương ứng, fail technology tokens trong Global Constraints.

- [ ] **Step 3: Chạy RED**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills`

Expected: FAIL do thiếu/generic contract chưa có.

- [ ] **Step 4: Viết sáu generic skills**

Mỗi skill bắt buộc:

```markdown
**Core principle:** Không có evidence thì ghi unknown; unknown chặn quyết định thì ghi `result: blocked`.

1. Đọc `aitoolkit-schemas`, project profile, project pack và artifact path orchestrator truyền.
2. Chỉ dùng taxonomy/mapping/toolchain có evidence hoặc do project pack cung cấp.
3. Ghi stable ID và evidence cho từng record.
4. Ghi artifact theo template tương ứng trong `RUN_DIR`.
```

`feature-mapping` giữ route cũ nhưng output `05-mapping.md`; incremental dùng mặc định `reuse → extend → create`, `replace` cần approved conflict decision.

- [ ] **Step 5: Chạy GREEN và pressure scenarios**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills`

Expected: PASS. Chạy lại ba scenarios với skill mới; agent phải ghi unknown/conflict, ưu tiên reuse và không nhắc stack cụ thể nếu pack không cung cấp.

- [ ] **Step 6: Commit**

```powershell
git add AIToolkit-main/aitoolkit/skills/migration AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: make migration discovery and mapping generic"
```

### Task 4: Mode-aware design, execution và verification skills

**Files:**
- Replace: `AIToolkit-main/aitoolkit/skills/migration/technical-design/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/skills/migration/plan-waves/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/skills/migration/bootstrap-target/SKILL.md`
- Replace: `AIToolkit-main/aitoolkit/skills/migration/code-migration/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/skills/migration/verify-parity/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/skills/migration/verify-regression/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: gaps/conflicts, mode/policy, target baseline, commands và approved plan.
- Produces: artifacts 07–10, 13–14.

- [ ] **Step 1: Dùng writing-skills tạo pressure scenarios RED**

Scenarios:

1. Greenfield chưa duyệt design nhưng được yêu cầu implement ngay.
2. Incremental target dùng architecture A nhưng requirement gợi architecture B.
3. Regression command thiếu hoặc baseline đã fail sẵn.

Expected RED: skill cũ hardcode architecture/commands và không phân mode/baseline.

- [ ] **Step 2: Thêm mode-policy assertions RED**

Validator yêu cầu:

- technical-design có `design-new`, `preserve-existing`, `Tech Lead gate`;
- bootstrap-target có `greenfield` và từ chối mode khác;
- code-migration có `approved migration unit`, `trace ID`, command resolution order;
- verify-parity không PASS khi baseline bắt buộc thiếu;
- verify-regression có `incremental`, `baseline failure`, waiver.

- [ ] **Step 3: Chạy RED**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills`

Expected: FAIL.

- [ ] **Step 4: Viết mode-aware skills**

Policy chính xác:

```text
greenfield/design-new foundation unit → propose design → Tech Lead approval → bootstrap → implement
greenfield/design-new later unit → approved foundation baseline → skip bootstrap → implement
incremental/preserve-existing → target conformance → no bootstrap → baseline → implement → regression
unknown/invalid combination → result: blocked
```

`code-migration` dùng `using-git-worktrees`, `writing-plans`, `executing-plans`, TDD và command từ profile/detection; không gọi lệnh công nghệ cụ thể. `verify-regression` phân biệt pre-existing baseline failures với regression mới.

- [ ] **Step 5: Chạy GREEN và pressure scenarios**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Skills`

Expected: PASS; scenarios phải block greenfield trước gate, giữ architecture incremental và không coi baseline failure cũ là regression mới.

- [ ] **Step 6: Commit**

```powershell
git add AIToolkit-main/aitoolkit/skills/migration AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: add mode-aware migration execution"
```

### Task 5: Superpowers-native migration orchestrator

**Files:**
- Modify: `AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/commands/migrate.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: profile mode/policy và skills Tasks 3–4.
- Produces: 18-step table, conditional bootstrap/regression và `blocked` handling.

- [ ] **Step 1: Thêm Orchestrators assertions RED**

Kiểm tra 18 step IDs/skill routes unique; `bootstrap-target` gắn greenfield; `verify-regression` gắn incremental; orchestrator chứa `result: blocked`, `mode: unknown`, `status: approved`; không chứa `manifest.yaml`, `state.json`, `.aitoolkit/run`, `--resume`.

- [ ] **Step 2: Chạy RED**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Orchestrators`

Expected: FAIL vì orchestrator hiện chỉ có 10 bước.

- [ ] **Step 3: Viết lại migrate orchestrator**

Giữ giao thức gate hiện tại, đổi bảng bước theo spec §9. Trước mode-dependent step:

```text
- profile mode unknown hoặc mode/policy sai invariant → dừng, hỏi người dùng, không đoán.
- greenfield selected foundation unit → chạy bootstrap; selected later unit → skip bootstrap và resolve approved foundation baseline; regression chỉ chạy nếu profile yêu cầu.
- incremental → skip bootstrap; chạy baseline trước implementation; regression bắt buộc trừ waiver approved.
- artifact result blocked → trình blockers, giữ status draft, dừng.
```

Command vẫn chỉ delegate tới `aitoolkit/migrate`; argument vẫn là feature slug.

- [ ] **Step 4: Chạy GREEN và regression check**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Orchestrators`

Run: `rg -n "Bảng bước" .\aitoolkit\skills\aitoolkit\feature\SKILL.md .\aitoolkit\skills\aitoolkit\bugfix\SKILL.md`

Expected: validator PASS; feature/bugfix vẫn có bảng bước hiện tại và không bị sửa.

- [ ] **Step 5: Commit**

```powershell
git add AIToolkit-main/aitoolkit/skills/aitoolkit/migrate/SKILL.md AIToolkit-main/aitoolkit/commands/migrate.md AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: orchestrate generic migration natively"
```

### Task 6: Migration onboarding orchestrator và project-pack generator

**Files:**
- Create: `AIToolkit-main/aitoolkit/commands/migration-onboarding.md`
- Create: `AIToolkit-main/aitoolkit/skills/aitoolkit/migration-onboarding/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/skills/migration-onboarding/{inspect-project,classify-mode,create-project-pack}/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/codex/skills/aitoolkit/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Consumes: legacy/target/docs paths.
- Produces: `docs/aitoolkit/project.yaml`, `docs/aitoolkit/migration-project/*`, onboarding artifacts; không sửa production source.

- [ ] **Step 1: Dùng writing-skills tạo onboarding pressure scenarios RED**

Scenarios:

1. Target chứa một file placeholder nhưng không có architecture đáng kể.
2. Target có nhiều migrated features và convention ổn định.
3. Toolchain marker có nhiều workspace/command mơ hồ.

Expected RED: chưa có onboarding route; mode/command không có gate chuẩn.

- [ ] **Step 2: Thêm Onboarding assertions RED**

Validator yêu cầu launcher gọi `aitoolkit/migration-onboarding`; orchestrator có 4 bước, mode gate và project-pack Tech Lead gate; skills chứa exact output paths và câu `Onboarding không sinh production code`; Codex router nhận workflow `migration-onboarding`.

- [ ] **Step 3: Chạy RED**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Onboarding`

Expected: FAIL do files thiếu.

- [ ] **Step 4: Viết onboarding skills/orchestrator**

`inspect-project` thu evidence legacy/target/docs/toolchain. `classify-mode` chỉ đề xuất mode/policy và chờ gate. `create-project-pack` tạo profile và các references:

```text
legacy-system.md
target-baseline.md
architecture-rules.md
mapping-rules.md
uiux-rules.md
testing-rules.md
definition-of-done.md
```

Pack index `SKILL.md` chỉ route reference. Mọi unknown quan trọng ghi `blocked`; không tạo scripts mặc định.

- [ ] **Step 5: Chạy GREEN và pressure scenarios**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Onboarding`

Expected: PASS; placeholder target cần human confirmation, existing target được đề xuất incremental, ambiguous commands thành unknown/BLOCKED.

- [ ] **Step 6: Commit**

```powershell
git add AIToolkit-main/aitoolkit/commands/migration-onboarding.md AIToolkit-main/aitoolkit/skills/aitoolkit/migration-onboarding AIToolkit-main/aitoolkit/skills/migration-onboarding AIToolkit-main/aitoolkit/codex/skills/aitoolkit/SKILL.md AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
git commit -m "feat: add native migration onboarding"
```

### Task 7: Extract webOS/QML/Flutter compatibility pack

**Files:**
- Create: `AIToolkit-main/aitoolkit/examples/project-packs/webos-qml-flutter/SKILL.md`
- Create: `AIToolkit-main/aitoolkit/examples/project-packs/webos-qml-flutter/references/{legacy-system,target-baseline,architecture-rules,mapping-rules,uiux-rules,testing-rules,definition-of-done}.md`
- Modify: `AIToolkit-main/aitoolkit/skills/shared/{ai-review,gerrit-automation,ccc-automation}/SKILL.md`
- Retain/deprecate: `AIToolkit-main/aitoolkit/skills/lge-rules/SKILL.md`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Produces: compatibility pack chứa knowledge cũ; shared skill resolve project pack/profile first.

- [ ] **Step 1: Thêm Compatibility assertions RED**

Pack phải chứa QML signal/property/Loader/model-delegate, Luna/native bridge, Flutter conventions và commands. Core scan gồm `skills/migration`, `templates/migration`, `skills/aitoolkit/migrate` phải sạch technology tokens. Shared skill không được yêu cầu trực tiếp `lge-rules`.

- [ ] **Step 2: Chạy RED**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Compatibility`

Expected: FAIL vì pack thiếu và shared skills phụ thuộc `lge-rules`.

- [ ] **Step 3: Tạo pack từ knowledge hiện có**

Mapping reference ghi ít nhất:

```text
QML view → Flutter widget/component
property binding → derived/reactive state
signal → event/callback
model/delegate → target list pattern
Luna/native service → repository/platform bridge
```

Architecture/testing references chứa Clean Architecture, Riverpod, `flutter analyze`, `flutter test` và LGE conventions. Các token này chỉ hợp lệ trong example pack/deprecated legacy skill.

- [ ] **Step 4: Cập nhật shared rule resolution**

Shared skills đọc `project_pack.path` → reference tương ứng. Migration yêu cầu reviewed pack và mandatory rules. Feature/bugfix không có explicit mandatory declaration thì dùng universal/default behavior và degrade gracefully; chỉ explicit mandatory rule mới block. `lge-rules` giữ một release cycle dưới dạng deprecated compatibility shim, không còn là dependency bắt buộc.

- [ ] **Step 5: Chạy GREEN**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Compatibility`

Expected: PASS.

- [ ] **Step 6: Commit**

```powershell
git add AIToolkit-main/aitoolkit/examples/project-packs AIToolkit-main/aitoolkit/skills/shared AIToolkit-main/aitoolkit/skills/lge-rules/SKILL.md AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
git commit -m "refactor: extract webos flutter project pack"
```

### Task 8: Documentation, fixtures và final verification

**Files:**
- Create: `AIToolkit-main/aitoolkit/examples/migration/{greenfield,incremental}/docs/aitoolkit/project.yaml`
- Create: `AIToolkit-main/aitoolkit/docs/MIGRATION-FRAMEWORK.md`
- Modify: `AIToolkit-main/aitoolkit/{README.md,CONTRIBUTING.md}`
- Modify: `AIToolkit-main/aitoolkit/docs/RUN-ON-CODEX.md`
- Modify: `AIToolkit-main/aitoolkit/.claude-plugin/plugin.json`
- Modify: `AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1`

**Interfaces:**
- Produces: user-facing onboarding/migration usage, two mode walkthroughs và release metadata.

- [ ] **Step 1: Thêm Docs assertions RED**

Validator yêu cầu README/docs chứa `/aitoolkit:migration-onboarding`, `/aitoolkit:migrate <feature-slug>`, greenfield/incremental và `docs/aitoolkit/migration-project`; plugin description không nói workflow manifest và keywords không hardcode `flutter`/`webos`; fixtures có đúng mode/policy invariant.

- [ ] **Step 2: Chạy RED**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check Docs`

Expected: FAIL ở docs/metadata/fixtures.

- [ ] **Step 3: Viết docs và fixtures**

Quick start:

```text
1. /aitoolkit:migration-onboarding
2. Review docs/aitoolkit/project.yaml và migration-project/
3. /aitoolkit:migrate <feature-slug>
4. Nếu gián đoạn, gọi lại workflow với cùng slug và đọc artifact approved trong RUN_DIR.
```

Greenfield walkthrough chứng minh design gate trước bootstrap. Incremental walkthrough chứng minh no-bootstrap, target conformance, baseline và regression.

- [ ] **Step 4: Bump plugin minor version và sửa metadata**

Đổi `0.6.0` → `0.7.0`; description nói orchestrator skill/human gate, không nói manifest; keywords giữ `migration`, `agentic`, `workflow`, bỏ stack cụ thể.

- [ ] **Step 5: Chạy full static verification**

Run: `& .\aitoolkit\tests\validate-migration-framework.ps1 -Check All`

Run: `claude plugin validate .\aitoolkit`

Run: `git diff --check`

Expected: validator và plugin validation PASS; diff check không output.

- [ ] **Step 6: Manual walkthrough evidence**

Trong Claude Code/Codex runtime mới, chạy onboarding tới gate đầu và migration fixture tới mode-dependent gate. Ghi ngày, runtime, observed gate/artifact vào `MIGRATION-FRAMEWORK.md`. Nếu runtime không khả dụng, ghi `BLOCKED` cùng lý do; không ghi PASS giả.

- [ ] **Step 7: Acceptance matrix**

Map đủ 12 criteria spec §15 tới file, validator assertion và manual evidence. Nếu thiếu, quay lại task sở hữu và bổ sung trước commit.

- [ ] **Step 8: Commit**

```powershell
git add AIToolkit-main/aitoolkit/examples/migration AIToolkit-main/aitoolkit/docs AIToolkit-main/aitoolkit/README.md AIToolkit-main/aitoolkit/CONTRIBUTING.md AIToolkit-main/aitoolkit/.claude-plugin/plugin.json AIToolkit-main/aitoolkit/tests/validate-migration-framework.ps1
git commit -m "docs: publish native migration framework"
```

## Final Self-Review

- **Spec coverage:** Contracts Task 1; artifacts Task 2; generic front-half Task 3; mode execution Task 4; orchestration Task 5; onboarding Task 6; compatibility extraction Task 7; docs/verification Task 8.
- **Runtime consistency:** Không task nào tạo manifest/state engine; conditions nằm trong orchestrator; artifacts giữ `status` cho gate và `result` cho nghiệp vụ.
- **Backward compatibility:** Feature/bugfix orchestrators không nằm trong file modification list; top-level templates được retain; shared rule resolution có deprecated shim một release cycle.
- **No placeholders:** Mọi task có file, interface, RED command, expected failure, implementation contract, GREEN command và commit.
