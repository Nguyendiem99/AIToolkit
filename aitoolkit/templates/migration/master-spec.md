---
artifact_type: migration-master-spec
master_spec_id: SPEC-<SCOPE>-<NNN>
revision: <positive integer>
status: <artifact lifecycle value>
result: <artifact result value>
approval_source: <approval source>
requested_scope_kind: <value from migration-scope-orchestration.md>
requested_scope_id: <stable scope ID>
produced_at: <yyyy-mm-dd>
supersedes: not-applicable
---

<!-- artifact_language: vi -->

# Master spec migration

## Problem and Intended Outcome

Mô tả vấn đề cần giải quyết và kết quả hoàn chỉnh mà requested scope phải đạt.

| Requirement ID | Statement | Source | Acceptance |
|---|---|---|---|
| REQ-### | <yêu cầu ổn định> | <tham chiếu nguồn> | <tiêu chí chấp nhận đo được> |

## Requested Scope Boundary

| Kind | ID | Statement | Source | Resolution Evidence |
|---|---|---|---|---|
| <scope kind> | <stable scope ID> | <kết quả người dùng yêu cầu> | user | <tham chiếu evidence ổn định> |

## Actors and Journeys

Mô tả actor và journey chịu ảnh hưởng, bao gồm điểm bắt đầu, kết quả và ngoại lệ.

## Behaviors, States and Failure Paths

Mô tả behavior quan sát được, state chuyển tiếp và failure path phải xử lý.

## Constraints and Project Rules

Nêu constraint, project rule, policy và boundary không được vi phạm.

## Architecture and Conformance Applicability

Xác định concern áp dụng, exemplar cần đọc và conformance evidence cần có trước mutation.

## Measurable Success Criteria

| Success Criterion ID | Requirement IDs | Measurable Outcome |
|---|---|---|
| SC-### | REQ-### | <kết quả đo được> |

## Explicitly Out-of-Scope Items

- <hạng mục được duyệt là ngoài scope>

## Assumptions and Unknowns

| ID | Assumption or Unknown | Impact | Disposition |
|---|---|---|---|
| UNK-### | <giả định hoặc điểm chưa rõ> | <scope/architecture/acceptance impact> | <resolved/blocked/accepted> |

## Trace/Evidence Index

| Trace ID | Type | Reference | Notes |
|---|---|---|
| TRACE-### | <requirement/discovery/design> | <tham chiếu evidence> | <ghi chú truy vết> |

## Approval Record

| Approval Source | Approval Reference | Status | Approved At |
|---|---|---|---|
| <approval source> | <approval reference> | pending | <yyyy-mm-dd> |

## Revision History

| Artifact ID | Revision | Supersedes | Change Summary | Affected Work Items | Approval Reference |
|---|---|---|---|---|---|
| SPEC-<SCOPE>-<NNN> | <positive integer> | not-applicable | <tóm tắt thay đổi được duyệt> | none | pending |
