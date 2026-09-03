---
name: lge-rules
description: Use when a legacy AIToolKit workflow still references the transitional LGE rule placeholder during its deprecation window.
---

# LGE Rules — Deprecated Compatibility Shim

**Deprecated:** retained for one release cycle as a compatibility shim. New and shared workflows read `docs/aitoolkit/project.yaml` and its `project_pack.path`; migrate approved content to the project pack references before this shim is removed.

Legacy consumers may continue reading the sections below during the transition. Shared skills do not depend on this file. A remaining placeholder is not an approved rule and must not be invented.

Mỗi mục dưới đây: thay dòng `«LGE team điền: ...»` bằng rule thật. Khi còn nguyên mốc, coi như mục đó KHÔNG áp rule bổ sung nào (degrade gracefully).

## code-convention
«LGE team điền: naming, folder, style Dart/Flutter theo chuẩn LGE»

## performance
«LGE team điền: yêu cầu hiệu năng (rebuild, memory, startup...)»

## security
«LGE team điền: yêu cầu bảo mật (data, Luna Service, permission...)»

## null-safety
«LGE team điền: quy tắc null-safety bắt buộc»

## gerrit-commit
«LGE team điền: format commit message, Change-Id, quy ước review»

## ccc-checklist
«LGE team điền: hạng mục CCC bắt buộc + evidence cần thu thập»
