# Ship Progress

## Latest: PostgreSQL SQL 실행 검증 + 표현식 인덱스 수정

- **Status**: Shipped (commit 29b8f39)
- **Issue**: #36
- **Branch**: feature/issue-36-postgresql-dialect
- **Plan Score**: 9/10
- **Tasks**: 7/7
- **Tests**: Docker PostgreSQL 14.23 — 9/9 SQL 파일 실행 성공, 정합성 검증 통과
- **Fix**: 03_initial_load.sql/06_func_idx_backfill.sql — 표현식 인덱스 컬럼 적재 누락 수정
- **Remaining gaps**:
  - PG `information_schema.columns.data_type`은 SQL-표준 명('CHARACTER VARYING') 반환 → Oracle vocabulary와 불일치. known gotcha로 문서화; follow-up 검토.
- **Date**: 2026-05-26

## Previous: PostgreSQL 다이얼렉트 지원

- **Status**: PR open (manual merge by user)
- **Issue**: #36
- **Branch**: feature/issue-36-postgresql-dialect
- **Plan Score**: 8.5/10
- **Tasks**: 12/12
- **Commits**: 5 (foundation+JS / sql-postgresql / docs / fix / gitignore)
- **Tests**: 프레임워크 없음 — node syntax check 10/10 + Playwright 수동 검증으로 대체
- **Date**: 2026-05-21
