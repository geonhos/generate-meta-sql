# Ship Progress

## Latest: PostgreSQL 다이얼렉트 지원

- **Status**: PR open (manual merge by user)
- **Issue**: #36
- **Branch**: feature/issue-36-postgresql-dialect
- **Plan Score**: 8.5/10
- **Tasks**: 12/12
- **Commits**: 5 (foundation+JS / sql-postgresql / docs / fix / gitignore)
- **Tests**: 프레임워크 없음 — node syntax check 10/10 + Playwright 수동 검증으로 대체
- **Verification gaps (PR body 명시)**:
  - sql/postgresql/* 9개 파일이 실 PostgreSQL 인스턴스에서 실행되지 않음 — 리뷰어 검증 필요
  - PG `information_schema.columns.data_type`은 SQL-표준 명('CHARACTER VARYING') 반환 → Oracle vocabulary와 불일치. 본 PR에서는 known gotcha로 문서화만; follow-up 검토.
- **Date**: 2026-05-21
