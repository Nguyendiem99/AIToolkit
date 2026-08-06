# AIToolKit — Dry-Run Walkthrough (Integration Test sống)

Bài kiểm tra hồi quy thủ công cho lõi engine, dùng manifest `_dryrun` + stub. Chạy trọn để xác nhận conductor đúng hành vi trước khi cắm step-skill thật (Plan 2).

## Chuẩn bị
1. Cài plugin `aitoolkit/` vào Claude Code (symlink `~/.claude/plugins` hoặc marketplace nội bộ), mở phiên mới để `/migrate` được đăng ký.
2. Mở một repo mẫu rỗng làm `<project>`. Artifact sẽ sinh ở `<project>/.aitoolkit/run-<id>/`.

## Manifest `_dryrun` — 5 bước phủ mọi nhánh engine

| id | isolate | optional | gate |
|----|---------|----------|------|
| s1-soft | false | – | soft |
| s2-isolate | true | – | soft |
| s3-optional | false | ✅ | soft |
| s4-hard | false | – | **hard** |
| s5-nogate | false | – | none |

## Kịch bản A — Happy path
Chạy: `/migrate _dryrun`

| Hành động | Kỳ vọng quan sát |
|-----------|------------------|
| Khởi tạo | Tạo `.aitoolkit/run-<id>/` + `state.json` (mọi bước `pending`) |
| s1-soft chạy | Có `run-.../s1-soft.md`, front-matter hợp lệ `status: draft` |
| Tới gate s1 | Conductor DỪNG, hỏi đúng "Duyệt s1?", CHƯA chạy s2 |
| Duyệt s1 | `s1-soft` → `approved`, artifact front-matter → `approved`, chạy tiếp s2 |

## Kịch bản B — Optional / HARD gate / isolate
Chạy: `/migrate _dryrun --disable s3-optional` (duyệt lần lượt tới cuối)

| Hành động | Kỳ vọng quan sát |
|-----------|------------------|
| s2-isolate | Chạy qua **subagent** (dispatching-parallel-agents), vẫn ra `s2-isolate.md` |
| s3-optional | `status: skipped`, KHÔNG có `s3-optional.md`, KHÔNG hỏi gate |
| s4-hard | Cảnh báo "không thể đảo ngược", chỉ đi tiếp khi **xác nhận tường minh** |
| s5-nogate | Chạy, KHÔNG hỏi gate |
| `--disable s1-soft` (thử) | Conductor **báo lỗi** (không cho tắt bước bắt buộc), không chạy |

## Kịch bản C — Resume / Từ chối / Lỗi
| Mini | Hành động | Kỳ vọng |
|------|-----------|---------|
| Resume | Duyệt s1, dừng ở gate s2; phiên mới `/migrate --resume run-<id>` | Tiếp từ s2, `s1-soft` vẫn `approved`, artifact s1 **không đổi** |
| Từ chối | Tại gate s1, từ chối kèm feedback "đổi tiêu đề" | `s1-soft.md` cập nhật (v2), `state.json` có `feedback`, bước sau vẫn `pending` |
| Lỗi | Một bước dùng `_stub/fail-step` | `status: failed` + lý do, state giữ nguyên, `/migrate --resume` chạy tiếp được |

## Kết quả lần chạy gần nhất
- 2026-08-06 — Mô phỏng conductor (logic prompt) trên repo mẫu scratchpad: **A/B/C đều PASS**.
  - A: s1 → awaiting_gate, artifact draft hợp lệ, s2 chưa khởi động.
  - B: s3-optional `skipped` (không artifact); s2-isolate/s4-hard/s5-nogate `approved`.
  - C: resume bỏ qua s1 đã duyệt (mtime không đổi) & tiến s2; từ chối lưu feedback + chạy lại s1→v2; lỗi step ghi `failed` + dừng.
- ⏳ Chưa xác nhận đăng ký lệnh `/migrate` trên Claude Code thật (cần cài plugin — xem "Chuẩn bị").

## Migration front-half (Plan 2a)
Chạy: `/migrate migration` — nửa đầu (01–04) là skill thật, nửa sau (05–10) tạm stub.

| Hành động | Kỳ vọng quan sát |
|-----------|------------------|
| 01 Discovery | `01-discovery.md` theo template discovery; gate "Xác nhận scope migration?" |
| 02 Feature Mapping | `02-mapping.md` (mapping matrix + scope + gap); gate Client |
| 03 Technical Design | `03-tech-design.md` (Clean Arch + Riverpod); gate Tech Lead |
| 04 Code Migration | worktree + branch; `04-migration-report.md`; gate Developer |
| 05→10 | Stub `echo-step` (Plan 2b thay bằng shared/* thật) |

- 2026-08-06 — Mô phỏng: **PASS**. 01→04 sinh artifact đúng tên, `step_id` khớp `migration.manifest.yaml`, đều `approved` sau gate; 05 stub chạy & chờ gate. Nội dung thật của 01–04 cần input dự án legacy thật để đầy đủ.

## Migration full pipeline (Plan 2b — 10 bước thật)
Chạy: `/aitoolkit:migrate migration` — cả 10 bước là skill thật (01–04 migration/*, 05–10 shared/*).

| Bước | Skill | Gate | Output |
|---|---|---|---|
| 05 AI Review | shared/ai-review | soft Reviewer | 05-review-report.md |
| 06 Verification & Testing | shared/verification-testing | soft Dev/QA | 06-verification-report.md |
| 07 Gerrit | shared/gerrit-automation | **HARD** Reviewer | 07-gerrit-report.md |
| 08 CCC | shared/ccc-automation | soft PM/QA · optional | 08-ccc-package.md |
| 09 Release | shared/release | **HARD** PM · optional | 09-release-report.md |
| 10 Knowledge Base | shared/knowledge-base | none | 10-kb-entry.md |

Đường tắt "chỉ Gerrit rồi KB": `/aitoolkit:migrate migration --disable 08-ccc-automation --disable 09-release`
→ pipeline thành `01…07 Gerrit → 10 KB`.

- 2026-08-06 — Wiring verify: **PASS**. Manifest 10 bước trỏ skill thật (không stub); 2 HARD gate (07,09), 2 optional (08,09), 10 không gate — đúng spec §5. Chạy nội dung đầy đủ cần dự án legacy thật + LGE rules đã điền.
