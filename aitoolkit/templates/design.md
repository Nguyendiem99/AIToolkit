---
step_id: 02-design
run_id: <run-id>
status: draft
produced_at: <yyyy-mm-dd>
---

# Design — <tên tính năng>

## Kiến trúc (Clean Architecture + Riverpod)
- Presentation:
- Domain (usecase/entity):
- Data (repository/provider):

## Folder structure
```
lib/features/<feature>/{presentation,domain,data}
```

## Sequence
<luồng chính từ UI → provider → usecase → repository>

## Data flow
<state management với Riverpod: provider nào giữ state gì>

## Tác động lên phần hiện có
| Thành phần bị ảnh hưởng | Thay đổi |
|---|---|
