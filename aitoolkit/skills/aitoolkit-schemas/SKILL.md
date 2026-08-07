---
name: aitoolkit-schemas
description: Hợp đồng dữ liệu của AIToolKit — cấu trúc artifact .md (front-matter) và project profile. Orchestrator và mọi step-skill PHẢI đọc skill này để đọc/ghi đúng định dạng.
---

# AIToolKit — Data Contracts

Các định dạng dưới đây là "seam" giữa các thành phần. KHÔNG thành phần nào được phá vỡ chúng.

## 1. Artifact `.md`

Mỗi bước ghi đúng MỘT file artifact. Front-matter YAML bắt buộc:

```yaml
---
step_id: 01-discovery      # id bước (khớp Bảng bước của orchestrator)
status: draft              # draft khi vừa sinh; approved sau khi qua gate
produced_at: 2026-08-06
---
```
Thân file theo template của bước.

**Đặt tên & input:**
- Bước đặc thù workflow (nửa đầu): tên theo bước, vd `01-discovery.md`, `03-fix.md`.
- Bước khung dùng chung (`shared/*`): tên theo vai trò, ổn định qua mọi workflow — `review-report.md`, `verification-report.md`, `gerrit-report.md`, `ccc-package.md`, `release-report.md`, `kb-entry.md`.
- Mọi artifact ghi vào **RUN_DIR** do orchestrator truyền (`<project>/docs/aitoolkit/<date>-<workflow>-<slug>/`).
- **Input bước trước = đường dẫn artifact orchestrator truyền vào**, KHÔNG tra state lưu riêng, KHÔNG hardcode tên file workflow khác.

## 2. Project profile (language-agnostic layer)

Các bước `shared/*` KHÔNG được hardcode ngôn ngữ/lệnh (không `flutter test`, `npm test`…). Chúng lấy lệnh test/lint/build của repo qua **profile**, theo thứ tự ưu tiên (degrade gracefully):

1. **Khai báo tường minh** — file tuỳ chọn `<project>/docs/aitoolkit/project.yaml` (team điền 1 lần). Trường nào có thì dùng nguyên văn:
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
