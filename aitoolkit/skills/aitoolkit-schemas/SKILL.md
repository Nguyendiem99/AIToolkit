---
name: aitoolkit-schemas
description: Hợp đồng dữ liệu của AIToolKit — cấu trúc artifact .md, manifest YAML, và state.json. Conductor và mọi step-skill PHẢI đọc skill này để đọc/ghi đúng định dạng.
---

# AIToolKit — Data Contracts

Ba định dạng dưới đây là "seam" giữa các thành phần. KHÔNG thành phần nào được phá vỡ chúng.

## 1. Artifact `.md`

Mỗi bước ghi đúng MỘT file artifact. Front-matter YAML bắt buộc:

```yaml
---
step_id: 01-discovery      # khớp id trong manifest
run_id: run-20260806-01
status: draft              # draft khi vừa sinh; approved sau khi qua gate
produced_at: 2026-08-06
---
```
Thân file theo template của bước (Plan 2 định nghĩa từng template).

## 2. Manifest YAML (`workflows/<name>.manifest.yaml`)

```yaml
workflow: <string>          # tên workflow, vd "migration"
steps:                      # thứ tự trong mảng = thứ tự chạy
  - id: <string>            # duy nhất trong manifest, vd "01-discovery"
    skill: <string>         # đường dẫn skill, vd "migration/discovery"
    isolate: <bool>         # true → conductor bọc subagent; false → chạy inline
    optional: <bool>        # (mặc định false) true → có thể tắt qua --disable
    gate: none | { type: soft|hard, approver: <string>, prompt: <string> }
```
Ràng buộc: `id` duy nhất; `skill` phải tồn tại; `gate.type` chỉ `soft`/`hard`; HARD gate không được tự động vượt.

## 3. state.json (`<project>/.aitoolkit/run-<id>/state.json`)

```json
{
  "run_id": "run-20260806-01",
  "workflow": "migration",
  "project_root": "/abs/path",
  "disabled_steps": ["08-ccc-automation", "09-release"],
  "current_step": "03-technical-design",
  "steps": {
    "01-discovery":       { "status": "approved",      "artifact_path": "01-discovery.md", "gate_status": "approved" },
    "02-feature-mapping": { "status": "approved",      "artifact_path": "02-mapping.md",   "gate_status": "approved" },
    "03-technical-design":{ "status": "awaiting_gate", "artifact_path": "03-tech-design.md","gate_status": "pending" }
  }
}
```
`status` hợp lệ: `pending | running | awaiting_gate | approved | rejected | failed | skipped`.
`gate_status`: `n/a | pending | approved | rejected`.
Trường tuỳ chọn `steps.<id>.feedback` lưu góp ý khi người dùng từ chối gate.
