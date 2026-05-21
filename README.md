# DB 메타 쿼리 생성기

사내 표준 DB 메타정보 관리체계 기반의 DDL · META DML · HIST SQL 자동 생성기.
브라우저 단독으로 동작하는 정적 웹앱으로, **폐쇄망 환경 실행**을 전제로 한다.

**대상 DBMS: Oracle 19c · PostgreSQL 14+** — 상단 토글로 전환.

## 실행

인터넷 없이 `index.html`을 브라우저로 열면 된다. 빌드·서버·의존성 설치 불필요.

- 파일 탐색기에서 `index.html` 더블클릭 (`file://` 프로토콜)
- 또는 사내 웹서버(IIS/Apache/nginx) 문서루트에 폴더 통째로 배포

## DB 다이얼렉트 전환

상단 토글 `DB: [Oracle] [PostgreSQL]` 로 출력 다이얼렉트를 선택한다. 마지막 선택은 `localStorage` 에 저장되어 재로딩 시 복원된다. 다이얼렉트별 출력 차이:

| 항목 | Oracle | PostgreSQL |
|---|---|---|
| 데이터 타입 | `NUMBER(p,s)`, `VARCHAR2(n)`, `CLOB`, `BLOB`, `RAW(n)`, `BINARY_DOUBLE` | `NUMERIC(p,s)`, `VARCHAR(n)`, `TEXT`, `BYTEA`, `BYTEA`, `DOUBLE PRECISION` |
| 타임스탬프 | `SYSTIMESTAMP` | `CURRENT_TIMESTAMP` |
| `DATE` 매핑 | `DATE` (날짜+시각) | **`TIMESTAMP`** (시맨틱 보존 — PG `DATE`는 일자만) |
| NULL 함수 | `NVL`, `NVL2` | `COALESCE`, `CASE` |
| 시퀀스 NEXTVAL | `SEQ_X.NEXTVAL` | `nextval('SEQ_X')` |
| 시퀀스 옵션 | `NOCYCLE` / `NOORDER` | `NO CYCLE` (PG는 ORDER 절 없음) |
| 인덱스 BITMAP | 지원 | 미지원 → B-tree로 fallback (경고 주석 출력) |
| 스토리지 절 | `TABLESPACE`, `INITRANS`, `PCTFREE` | 모두 생략 |
| ALTER MODIFY | `ALTER TABLE ... MODIFY (col TYPE ...)` | `ALTER COLUMN col TYPE ...`, `SET/DROP DEFAULT`, `SET/DROP NOT NULL` 분리 |
| 식별자 케이스 | UPPERCASE | UPPERCASE 입력 → PG가 자동 lowercase 폴딩 (운영 동작 동일) |

## 기능

| 탭 | 대상 | 생성물 |
|----|------|--------|
| 테이블 신규 생성 | `TB_META_TABLE` 외 | `CREATE TABLE` · META `INSERT` · HIST |
| 컬럼 추가·변경·삭제 | 컬럼 메타 | `ALTER TABLE` · META DML · HIST |
| 인덱스 생성·삭제 | `TB_META_INDEX` · `TB_META_INDEX_COLUMN` | `CREATE/DROP INDEX` · META DML · HIST |
| 시퀀스 생성·변경·삭제 | `TB_META_SEQUENCE` | `CREATE/ALTER/DROP SEQUENCE` · META DML · HIST |

### 단축키
- `⌘↵` / `Ctrl+↵` — SQL 생성
- `Alt+1 ~ Alt+4` — 탭 전환

## 디렉토리 구조

```
generate-meta-sql/
├── index.html                           앱 진입점 (외부 CDN 의존 0)
├── css/
│   └── styles.css                       스타일 (OS 시스템 폰트 fallback)
├── js/
│   ├── codes.js                         공통 코드 상수 (표준설계서 5장)
│   ├── utils.js                         공통 유틸
│   ├── ui.js                            섹션 토글·서브탭·밸리데이션
│   ├── sqlview.js                       SQL 프리뷰 렌더러
│   ├── table.js                         탭 1: 테이블
│   ├── column.js                        탭 2: 컬럼
│   ├── indexMgr.js                      탭 3: 인덱스
│   ├── sequence.js                      탭 4: 시퀀스
│   └── app.js                           라우터·단축키·트윅 (반드시 마지막 로드)
├── sql/                                  ★ 모든 실행 SQL (단일 진실 공급원)
│   ├── 01_meta_ddl.sql                   [Oracle] [순서 1, 필수]   DDL 일괄
│   ├── 02_common_code.sql                [Oracle] [순서 2, 필수]   공통코드 적재
│   ├── 02a_cd_tos_template.sql           [Oracle] [순서 2.5, 선택] 사내 약관 코드
│   ├── 03_initial_load.sql               [Oracle] [순서 3, 필수]   카탈로그 → 메타 적재
│   ├── 04_drift_check.sql                [Oracle] [수시] Drift 감지
│   ├── 05_integrity_check.sql            [Oracle] [수시] 정합성 점검
│   ├── 06_func_idx_backfill.sql          [Oracle] [선택] 함수기반 인덱스 사후 보강
│   ├── 07_view_gen_nonpci.sql            [Oracle] [선택] 비-PCI VIEW DDL 자동 생성
│   ├── 99_rollback.sql                   [Oracle] [긴급] 전체 롤백
│   └── postgresql/                       ★ PostgreSQL 대응본 (Oracle 파일과 1:1 대응)
│       ├── 01_meta_ddl.sql               [PG] DDL 일괄 (NUMERIC/VARCHAR/TEXT/BYTEA, NO CYCLE)
│       ├── 02_common_code.sql            [PG] 공통코드 적재 (FROM DUAL 제거)
│       ├── 02a_cd_tos_template.sql       [PG] 사내 약관 코드
│       ├── 03_initial_load.sql           [PG] information_schema/pg_* 카탈로그 적재
│       ├── 04_drift_check.sql            [PG] Drift 감지
│       ├── 05_integrity_check.sql        [PG] 정합성 점검 + pg_stat_activity 잠금 진단
│       ├── 06_func_idx_backfill.sql      [PG] 표현식 인덱스 자동 보강 (pg_get_indexdef)
│       ├── 07_view_gen_nonpci.sql        [PG] STRING_AGG, NAMEDATALEN 점검
│       └── 99_rollback.sql               [PG] 전체 폐기 (PURGE 키워드 없음)
├── DB_메타정보_관리체계_표준설계.md      메타 표준 설계서 (명세 · 표 · 설계의도)
├── SQL_검증리포트.md                     사내 반입 전 SQL 검증 리포트
└── 운영가이드.md                         사내 운영 가이드 (실행 순서 · 트러블슈팅)
```

## 사내 반입 후 SQL 실행 순서 (필수)

1. [`sql/01_meta_ddl.sql`](sql/01_meta_ddl.sql) — DDL 생성
2. [`sql/02_common_code.sql`](sql/02_common_code.sql) — 공통코드 적재
3. (선택) [`sql/02a_cd_tos_template.sql`](sql/02a_cd_tos_template.sql) — 사내 약관 코드
4. [`sql/03_initial_load.sql`](sql/03_initial_load.sql) — 카탈로그 → 메타 적재 (실행 전 SVC 스키마 치환 필수)

상세 절차·검증·트러블슈팅: [운영가이드.md](운영가이드.md) 참조.

## 기술 스택

- 순수 HTML / CSS / Vanilla JS (프레임워크 없음)
- 외부 런타임 의존성 **없음** — 폐쇄망에서 그대로 실행
- 폰트: OS 시스템 폰트 fallback (`-apple-system`, `BlinkMacSystemFont`, `Consolas`, `Monaco` 등)

## 표준 설계서

`DB_메타정보_관리체계_표준설계.md` — 본 앱이 구현하는 메타 테이블 구조 · 공통 코드 · 생성 규칙의 표준.
코드 상수(`js/codes.js`)는 이 문서의 5장과 동기화되어야 한다.
