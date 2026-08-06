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
Thân file theo template của bước.

**Quy ước đặt tên file artifact:**
- Bước **đặc thù workflow** (nửa đầu): đặt theo bước, vd `01-discovery.md`, `03-fix.md`.
- Bước **khung dùng chung** (`shared/*`): đặt theo **vai trò**, ổn định qua mọi workflow — `review-report.md`, `verification-report.md`, `gerrit-report.md`, `ccc-package.md`, `release-report.md`, `kb-entry.md`.
- **Thứ tự bước CHỈ nằm ở `manifest.steps` (mảng có thứ tự);** `state.json.steps` là object keyed-by-id, KHÔNG mang thứ tự. Để lấy input của **bước ngay trước**: tìm id đứng liền trước `current_step` trong `manifest.steps`, rồi tra `state.json.steps[<prev_id>].artifact_path`. KHÔNG hardcode tên file của workflow khác.

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

## 4. Project profile (language-agnostic layer)

Các bước `shared/*` KHÔNG được hardcode ngôn ngữ/lệnh (không `flutter test`, `npm test`…). Chúng lấy lệnh test/lint/build của repo qua **profile**, theo thứ tự ưu tiên (degrade gracefully):

1. **Khai báo tường minh** — file tuỳ chọn `<project>/.aitoolkit/project.yaml` (team điền 1 lần). Trường nào có thì dùng nguyên văn:
   ```yaml
   language: dart            # tuỳ chọn, chỉ để ghi chú
   base_branch: origin/main  # tuỳ chọn — mốc diff cho ai-review; thiếu ⇒ fallback HEAD~1
   test_cmd: flutter test
   lint_cmd: flutter analyze
   build_cmd: flutter build apk --debug
   coverage_cmd: flutter test --coverage   # tuỳ chọn
   review_focus:                            # tuỳ chọn, bơm thêm vào ai-review
     - "Riverpod: không giữ ref sau dispose"
   ```

Ngoài ra, **loại thay đổi** (chi phối chiến lược test) lấy theo thứ tự: (a) `manifest` khai `change_type: feature|bugfix|migration`; (b) suy từ tên `workflow` (chứa "migration"→migration, "bug"/"fix"→bugfix, còn lại→feature).
2. **Tự dò** (khi thiếu trường ở bước 1) — nhận diện qua marker file ở gốc repo. Bảng dò chuẩn nằm ở `shared/verification-testing/command-detection.md`; ví dụ: `pubspec.yaml`→dart/flutter, `package.json`→npm/pnpm/yarn, `Cargo.toml`→cargo, `go.mod`→go, `pom.xml`/`build.gradle`→mvn/gradle, `pyproject.toml`→pytest, `*.csproj`→dotnet.
3. **Hỏi qua gate** (khi vừa không khai báo vừa không dò được) — bước ghi rõ trong report "lệnh chưa xác định", nêu phán đoán, để gate người dùng xác nhận; TUYỆT ĐỐI không bịa lệnh rồi tuyên bố đã chạy.

Mọi shared skill đọc profile theo đúng thứ tự này. Lệnh dùng thực tế PHẢI được ghi verbatim vào artifact để truy vết.
