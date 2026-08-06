---
name: fail-step
description: (Chỉ dùng cho dry-run) Cố tình dừng và báo lỗi để kiểm tra xử lý lỗi & resume của conductor. KHÔNG ghi artifact.
---

# Stub: fail-step

Khi được gọi: KHÔNG ghi artifact. Báo cho conductor: "STEP FAILED: fail-step mô phỏng lỗi." rồi dừng, để conductor đánh dấu `status: failed` và giữ nguyên state.
