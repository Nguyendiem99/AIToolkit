# Chạy AIToolkit trên Codex (OpenAI Codex CLI)

AIToolkit đóng gói **dạng Claude Code plugin**, nhưng vì **thuần prompt + file `.md`** nên chạy được trên Codex — chỉ nạp bằng cơ chế của Codex, không phải bằng `claude plugin install`.

> **Muốn Codex tự cài giúp?** Dán toàn bộ `codex/CODEX-SETUP-PROMPT.md` cho Codex — nó tự clone, cấu hình, verify bằng cách chạy thử một workflow nhỏ tới gate đầu. Tài liệu dưới đây là bản giải thích cho con người.

## Codex khác Claude Code ở đâu

| Claude Code | Codex | Kết luận cho kit |
|---|---|---|
| `claude plugin install` | Không có | Không "cài plugin"; dùng skills/AGENTS.md |
| Slash command `/aitoolkit:migrate` | **Slash command hardcoded, KHÔNG custom được** | Không có `/aitoolkit:*`; gọi qua `$skill` hoặc câu lệnh thường |
| Skills tự-discovery | **Có hệ skills** `~/.codex/skills/<tên>/SKILL.md`, gọi bằng `$tên` | Định dạng SKILL.md **y hệt** — dùng lại được |
| `AGENTS.md` (không bắt buộc) | **Tự đọc `AGENTS.md`** gốc→CWD, tiêm vào system prompt | Đây là cách bootstrap đáng tin nhất |
| Tool `AskUserQuestion` cho gate | Không có | Orchestrator skill đã lường: hỏi gate bằng **text** |

## Điều kiện tiên quyết trên máy Codex

1. **Superpowers bản Codex** đã cài (các shared skill tham chiếu `superpowers:*`).
2. Bước nặng cần dispatch subagent (dùng `dispatching-parallel-agents`) cần bật multi-agent trong `~/.codex/config.toml`:
   ```toml
   [features]
   multi_agent = true
   ```
   Không bật thì bước đó chạy **inline** (vẫn đúng, chỉ không cách ly context).
3. **Clone kit** về máy và nhớ đường dẫn — gọi là `AITOOLKIT_HOME` (vd `/Users/ban/AIToolkit`).

---

## Cách A — AGENTS.md bootstrap (khuyến nghị, không cần "cài" gì)

Codex tự đọc `AGENTS.md` trong project bạn đang mở. Thêm một khối bootstrap vào `AGENTS.md` ở **gốc project đích** (project bạn muốn chạy pipeline):

1. Mở (hoặc tạo) `AGENTS.md` ở gốc project đích.
2. Dán nội dung `aitoolkit/codex/AGENTS.snippet.md`, **sửa `AITOOLKIT_HOME`** thành đường dẫn clone thật.
3. Mở Codex trong project đó. Giờ chỉ cần nói tự nhiên:
   > "Chạy workflow bugfix." · "Chạy tiếp workflow migration ở docs/aitoolkit/2026-08-06-migration-foo/."

   Codex đọc AGENTS.md → biết đóng vai orchestrator theo `migrate.md`, ghi artifact vào `./docs/aitoolkit/`.

Ưu điểm: không copy skill, không phụ thuộc `$`-invocation; dùng đúng cơ chế native của Codex.

---

## Cách B — Đăng ký skill vào Codex (hiện trong `/skills`, gọi bằng `$tên`)

Để chạy pipeline bạn **chỉ cần** orchestrator `$aitoolkit` — nó tự **đọc file** các step-skill rồi làm theo, không cần chúng đăng ký. Nếu muốn thấy/gọi từng skill trong `/skills` (parity với Claude Code), đăng ký **cả cây** `skills/` vào thư mục skills cá nhân của Codex (`~/.codex/skills/`, được quét đệ quy `**/SKILL.md`):

```bash
mkdir -p ~/.codex/skills
# link mọi skill của kit (mỗi thư mục có SKILL.md) theo tên
find "$AITOOLKIT_HOME/aitoolkit/skills" -name SKILL.md \
  -exec dirname {} \; | while read d; do ln -sf "$d" ~/.codex/skills/"$(basename "$d")"; done
# orchestrator wrapper
ln -sf "$AITOOLKIT_HOME/aitoolkit/codex/skills/aitoolkit" ~/.codex/skills/aitoolkit
# sửa AITOOLKIT_HOME trong ~/.codex/skills/aitoolkit/SKILL.md
```

Dùng `ln -sf` (symlink) để kit cập nhật thì skill tự theo; muốn bản copy tĩnh thì thay bằng `cp -r`. Chạy `/skills` để xác nhận thấy `aitoolkit`, `ai-review`, `verification-testing`, `discovery`, … Rồi:

```
$aitoolkit bugfix
$aitoolkit migration, bỏ qua bước 08 CCC và 09 Release
```

> **Lưu ý namespace:** các step-skill có tên khá chung (`fix`, `design`, `implement`, `reproduce`…). Đăng ký toàn cục nghĩa là chúng nằm chung namespace với skill khác của bạn. Nếu ngại, chỉ cần cài mỗi orchestrator `aitoolkit` — pipeline vẫn chạy đủ.
>
> **Route "chuẩn" (nâng cao):** Codex cũng có hệ plugin/marketplace giống Claude Code (`codex plugin marketplace add` + `codex plugin add`, manifest `plugin.json` + `.agents/plugins/marketplace.json`). Có thể đóng gói AIToolkit thành Codex plugin để cài/gỡ gọn hơn — xem `codex plugin --help`.

---

## Test trên Codex

An toàn, không đụng code thật:

1. Trong project đích, dùng Cách A (hoặc B) chạy thử một workflow nhỏ (vd `bugfix`) tới gate đầu tiên.
2. Kiểm chứng cùng những thứ orchestrator phải làm:
   - soft gate dừng hỏi (bằng text);
   - bước nặng dispatch subagent được (nếu bật `multi_agent`), không thì inline;
   - bước optional bỏ qua được khi nói rõ trong yêu cầu;
   - **HARD gate không tự vượt** — phải xác nhận tường minh;
   - artifact sinh đúng trong `./docs/aitoolkit/<date>-<workflow>-<slug>/`, và chạy tiếp từ một run dở dang được.
3. Ngon thì chuyển `bugfix`/`feature`/`migration`.

## Lưu ý sandbox (Codex App)

Bước Gerrit/nhánh có thể bị sandbox chặn tạo nhánh/push (detached HEAD). Khi đó Codex commit tại chỗ và bạn dùng nút **"Create branch"** / **"Hand off to local"** của App, hoặc chạy Codex CLI local có quyền git. HARD gate (Gerrit upload, Release) vẫn không bao giờ tự vượt.
