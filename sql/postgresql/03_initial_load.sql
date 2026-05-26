-- =====================================================================
-- 03_initial_load.sql — 시스템 카탈로그 → 메타 테이블 적재 + HIST (PostgreSQL 14+)
-- 실행 순서: 3 / 3
-- 선행: 02_common_code.sql
-- 후행: (없음 — 이후 비즈니스 메타 수기 UPDATE)
-- 출처: DB_메타정보_관리체계_표준설계.md §7 (7.1~7.5)
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../03_initial_load.sql 참조)
--
-- 사전 수정 필요:
--   - WHERE UPPER(...) IN ('SVC1','SVC2', ...) 의 스키마 목록을 실제
--     대상 스키마(대문자)로 교체. PG는 unquoted 식별자를 lowercase로
--     저장하므로 카탈로그 비교 시 UPPER() 양변 통일이 안전하다.
--
-- 매핑 (Oracle → PostgreSQL 카탈로그):
--   ALL_TABLES         → information_schema.tables (table_type='BASE TABLE')
--   ALL_VIEWS          → information_schema.views
--   ALL_TAB_COMMENTS   → pg_description joined via pg_class/pg_namespace
--   ALL_TAB_COLUMNS    → information_schema.columns
--   ALL_COL_COMMENTS   → pg_description (objsubid = attribute number)
--   ALL_CONSTRAINTS    → information_schema.table_constraints
--   ALL_CONS_COLUMNS   → information_schema.key_column_usage
--   ALL_INDEXES        → pg_indexes + pg_index
--   ALL_IND_COLUMNS    → pg_index + pg_attribute (UNNEST(indkey))
--   ALL_SEQUENCES      → pg_sequences (PG 10+)
--   ALL_ENCRYPTED_COL  → PG 표준 카탈로그 없음 — ENCRYPTION 정보 미수집('N')
--   NVL                → COALESCE
--   NVL2(x,a,b)        → CASE WHEN x IS NOT NULL THEN a ELSE b END
--   SUBSTR(x,1,n)      → LEFT(x, n)
--   IOT_TYPE 필터      → PG는 IOT 개념 없음 → 필터 제거
--   BIN$% (휴지통)     → PG는 즉시 DROP → 필터 제거
--
-- 식별자 케이스 폴딩:
--   PG는 unquoted CREATE 시 lowercase 저장. 카탈로그 조회로 받은 값은
--   UPPER()로 변환하여 SCHEMA_NAME/TABLE_NAME 컬럼에 적재한다(Oracle
--   원본 데이터와 동일한 대문자 컨벤션 유지).
-- =====================================================================

-- =====================================================================
-- §7.1 TB_META_TABLE — 테이블/뷰 적재 (VIEW_YN으로 구분)
-- =====================================================================

-- (1) 일반 테이블 (VIEW_YN='N')
INSERT INTO TB_META_TABLE (
    TABLE_ID, SCHEMA_NAME, TABLE_NAME, LOGICAL_NAME, DESCRIPTION,
    VIEW_YN, SERVICE_CD, OWNER_EMP_ID,
    KEY_TABLE_YN, ISOLATION_YN, PCI_YN,
    RETENTION_PERIOD_CD, STATUS_CD,
    CREATED_BY, UPDATED_BY
)
SELECT
    nextval('SEQ_META_TABLE_ID'),
    UPPER(t.table_schema),
    UPPER(t.table_name),
    NULL,                                       -- LOGICAL_NAME: 이후 담당자 입력
    LEFT(d.description, 2000),                  -- pg_description (2000자 절단)
    'N',                                        -- VIEW_YN
    'UNASSIGNED',
    'SYSTEM',
    'N','N','N',
    'Y5',
    'ACTIVE',
    USER, USER
FROM information_schema.tables t
LEFT JOIN pg_namespace   n  ON n.nspname = t.table_schema
LEFT JOIN pg_class       cl ON cl.relname = t.table_name AND cl.relnamespace = n.oid
LEFT JOIN pg_description d  ON d.objoid = cl.oid AND d.objsubid = 0
WHERE UPPER(t.table_schema) IN ('SVC1','SVC2'/* 대상 스키마 목록 (대문자) */)
  AND t.table_type = 'BASE TABLE'
  AND UPPER(t.table_name) NOT LIKE 'TB_META_%'  -- 자기 자신 제외
  AND NOT EXISTS (                              -- 재실행 중복 방지
        SELECT 1 FROM TB_META_TABLE m
         WHERE m.SCHEMA_NAME = UPPER(t.table_schema)
           AND m.TABLE_NAME  = UPPER(t.table_name)
      )
;

-- (2) 뷰 (VIEW_YN='Y')
INSERT INTO TB_META_TABLE (
    TABLE_ID, SCHEMA_NAME, TABLE_NAME, LOGICAL_NAME, DESCRIPTION,
    VIEW_YN, SERVICE_CD, OWNER_EMP_ID,
    KEY_TABLE_YN, ISOLATION_YN, PCI_YN,
    RETENTION_PERIOD_CD, STATUS_CD,
    CREATED_BY, UPDATED_BY
)
SELECT
    nextval('SEQ_META_TABLE_ID'),
    UPPER(v.table_schema),
    UPPER(v.table_name),
    NULL,
    LEFT(d.description, 2000),
    'Y',                                        -- VIEW_YN
    'UNASSIGNED',
    'SYSTEM',
    'N','N','N',
    'Y5',
    'ACTIVE',
    USER, USER
FROM information_schema.views v
LEFT JOIN pg_namespace   n  ON n.nspname = v.table_schema
LEFT JOIN pg_class       cl ON cl.relname = v.table_name AND cl.relnamespace = n.oid
LEFT JOIN pg_description d  ON d.objoid = cl.oid AND d.objsubid = 0
WHERE UPPER(v.table_schema) IN ('SVC1','SVC2'/* 대상 스키마 목록 */)
  AND UPPER(v.table_name) NOT LIKE 'TB_META_%'
  AND NOT EXISTS (
        SELECT 1 FROM TB_META_TABLE m
         WHERE m.SCHEMA_NAME = UPPER(v.table_schema)
           AND m.TABLE_NAME  = UPPER(v.table_name)
      )
;

-- §7.5.1 TB_META_TABLE_HIST — 'I'/'INITIAL_LOAD' 미존재 행만 적재
INSERT INTO TB_META_TABLE_HIST (
    HIST_ID, HIST_TYPE, HIST_AT, HIST_BY, CHANGE_REASON,
    TABLE_ID, SCHEMA_NAME, TABLE_NAME, LOGICAL_NAME, DESCRIPTION,
    VIEW_YN, SERVICE_CD, OWNER_EMP_ID, SECONDARY_EMP_ID,
    KEY_TABLE_YN, ISOLATION_YN, ISOLATION_LEVEL_CD,
    PCI_YN, RETENTION_PERIOD_CD, RETENTION_BASIS, TOS_CD,
    STATUS_CD, REMARK,
    CREATED_BY, CREATED_AT, UPDATED_BY, UPDATED_AT
)
SELECT
    nextval('SEQ_META_HIST_ID'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    t.TABLE_ID, t.SCHEMA_NAME, t.TABLE_NAME, t.LOGICAL_NAME, t.DESCRIPTION,
    t.VIEW_YN, t.SERVICE_CD, t.OWNER_EMP_ID, t.SECONDARY_EMP_ID,
    t.KEY_TABLE_YN, t.ISOLATION_YN, t.ISOLATION_LEVEL_CD,
    t.PCI_YN, t.RETENTION_PERIOD_CD, t.RETENTION_BASIS, t.TOS_CD,
    t.STATUS_CD, t.REMARK,
    t.CREATED_BY, t.CREATED_AT, t.UPDATED_BY, t.UPDATED_AT
FROM TB_META_TABLE t
WHERE NOT EXISTS (
    SELECT 1 FROM TB_META_TABLE_HIST h
     WHERE h.TABLE_ID      = t.TABLE_ID
       AND h.HIST_TYPE     = 'I'
       AND h.CHANGE_REASON = 'INITIAL_LOAD'
)
;

-- =====================================================================
-- §7.2 TB_META_COLUMN — 컬럼 적재
--   PK/UK/FK 판별은 information_schema.table_constraints (PRIMARY KEY/UNIQUE/FOREIGN KEY)
--   ENCRYPTION 정보는 PG 표준 카탈로그에 없음 — ENCRYPTION_YN='N' 고정
-- =====================================================================
INSERT INTO TB_META_COLUMN (
    COLUMN_ID, TABLE_ID, COLUMN_NAME, COLUMN_ORDER,
    LOGICAL_NAME, DESCRIPTION,
    DATA_TYPE, DATA_LENGTH, DATA_PRECISION, DATA_SCALE,
    NULLABLE_YN, DEFAULT_VALUE,
    PK_YN, UK_YN, FK_YN,
    PCI_YN, SENSITIVITY_CD,
    ENCRYPTION_YN, ENCRYPTION_ALG, MASKING_YN,
    STATUS_CD, CREATED_BY, UPDATED_BY
)
SELECT
    nextval('SEQ_META_COLUMN_ID'),
    mt.TABLE_ID,
    UPPER(tc.column_name),
    tc.ordinal_position,
    NULL,
    LEFT(d.description, 2000),                  -- pg_description (컬럼 코멘트)
    UPPER(tc.data_type),
    COALESCE(tc.character_maximum_length, tc.numeric_precision),  -- DATA_LENGTH (문자형 우선, 그 외 numeric_precision)
    tc.numeric_precision,
    tc.numeric_scale,
    CASE tc.is_nullable WHEN 'YES' THEN 'Y' ELSE 'N' END,
    NULL,                                       -- DEFAULT_VALUE: 표준 SQL-only 스크립트에서는 미적재
    CASE WHEN pk.column_name IS NOT NULL THEN 'Y' ELSE 'N' END,
    CASE WHEN uk.column_name IS NOT NULL THEN 'Y' ELSE 'N' END,
    CASE WHEN fk.column_name IS NOT NULL THEN 'Y' ELSE 'N' END,
    'N','LOW',
    'N',                                        -- ENCRYPTION_YN: PG 카탈로그 미수집
    NULL,
    'N',
    'ACTIVE', USER, USER
FROM information_schema.columns tc
JOIN TB_META_TABLE mt
      ON mt.SCHEMA_NAME = UPPER(tc.table_schema) AND mt.TABLE_NAME = UPPER(tc.table_name)
LEFT JOIN pg_namespace   ns ON ns.nspname = tc.table_schema
LEFT JOIN pg_class       cl ON cl.relname = tc.table_name AND cl.relnamespace = ns.oid
LEFT JOIN pg_attribute   a  ON a.attrelid = cl.oid AND a.attname = tc.column_name AND a.attnum > 0
LEFT JOIN pg_description d  ON d.objoid = cl.oid AND d.objsubid = a.attnum
LEFT JOIN (
    SELECT DISTINCT tcons.table_schema, tcons.table_name, kcu.column_name
      FROM information_schema.table_constraints tcons
      JOIN information_schema.key_column_usage kcu
        ON tcons.constraint_schema = kcu.constraint_schema
       AND tcons.constraint_name   = kcu.constraint_name
       AND tcons.table_schema      = kcu.table_schema
       AND tcons.table_name        = kcu.table_name
     WHERE tcons.constraint_type = 'PRIMARY KEY'
) pk ON pk.table_schema = tc.table_schema AND pk.table_name = tc.table_name AND pk.column_name = tc.column_name
LEFT JOIN (
    SELECT DISTINCT tcons.table_schema, tcons.table_name, kcu.column_name
      FROM information_schema.table_constraints tcons
      JOIN information_schema.key_column_usage kcu
        ON tcons.constraint_schema = kcu.constraint_schema
       AND tcons.constraint_name   = kcu.constraint_name
       AND tcons.table_schema      = kcu.table_schema
       AND tcons.table_name        = kcu.table_name
     WHERE tcons.constraint_type = 'UNIQUE'
) uk ON uk.table_schema = tc.table_schema AND uk.table_name = tc.table_name AND uk.column_name = tc.column_name
LEFT JOIN (
    SELECT DISTINCT tcons.table_schema, tcons.table_name, kcu.column_name
      FROM information_schema.table_constraints tcons
      JOIN information_schema.key_column_usage kcu
        ON tcons.constraint_schema = kcu.constraint_schema
       AND tcons.constraint_name   = kcu.constraint_name
       AND tcons.table_schema      = kcu.table_schema
       AND tcons.table_name        = kcu.table_name
     WHERE tcons.constraint_type = 'FOREIGN KEY'
) fk ON fk.table_schema = tc.table_schema AND fk.table_name = tc.table_name AND fk.column_name = tc.column_name
WHERE NOT EXISTS (
    SELECT 1 FROM TB_META_COLUMN m
     WHERE m.TABLE_ID    = mt.TABLE_ID
       AND m.COLUMN_NAME = UPPER(tc.column_name)
)
;

-- DEFAULT_VALUE는 PG에서 information_schema.columns.column_default로 조회 가능하지만,
-- Oracle SQL-only 표준 스크립트와 일관성을 위해 초기 적재에서는 NULL로 둔다.

-- §7.5.2 TB_META_COLUMN_HIST
INSERT INTO TB_META_COLUMN_HIST (
    HIST_ID, HIST_TYPE, HIST_AT, HIST_BY, CHANGE_REASON,
    COLUMN_ID, TABLE_ID, COLUMN_NAME, COLUMN_ORDER,
    LOGICAL_NAME, DESCRIPTION,
    DATA_TYPE, DATA_LENGTH, DATA_PRECISION, DATA_SCALE,
    NULLABLE_YN, DEFAULT_VALUE,
    PK_YN, UK_YN, FK_YN,
    PCI_YN, PCI_CATEGORY_CD, SENSITIVITY_CD,
    ENCRYPTION_YN, ENCRYPTION_ALG, MASKING_YN, MASKING_RULE_CD,
    RETENTION_PERIOD_CD, TOS_CD, STATUS_CD, REMARK,
    CREATED_BY, CREATED_AT, UPDATED_BY, UPDATED_AT
)
SELECT
    nextval('SEQ_META_HIST_ID'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    c.COLUMN_ID, c.TABLE_ID, c.COLUMN_NAME, c.COLUMN_ORDER,
    c.LOGICAL_NAME, c.DESCRIPTION,
    c.DATA_TYPE, c.DATA_LENGTH, c.DATA_PRECISION, c.DATA_SCALE,
    c.NULLABLE_YN, c.DEFAULT_VALUE,
    c.PK_YN, c.UK_YN, c.FK_YN,
    c.PCI_YN, c.PCI_CATEGORY_CD, c.SENSITIVITY_CD,
    c.ENCRYPTION_YN, c.ENCRYPTION_ALG, c.MASKING_YN, c.MASKING_RULE_CD,
    c.RETENTION_PERIOD_CD, c.TOS_CD, c.STATUS_CD, c.REMARK,
    c.CREATED_BY, c.CREATED_AT, c.UPDATED_BY, c.UPDATED_AT
FROM TB_META_COLUMN c
WHERE NOT EXISTS (
    SELECT 1 FROM TB_META_COLUMN_HIST h
     WHERE h.COLUMN_ID     = c.COLUMN_ID
       AND h.HIST_TYPE     = 'I'
       AND h.CHANGE_REASON = 'INITIAL_LOAD'
)
;

-- =====================================================================
-- §7.3 인덱스 적재
-- =====================================================================

-- §7.3.1 TB_META_INDEX — 헤더
--   INDEX_TYPE_CD: UNIQUE 우선, 그 외 NORMAL (PG에는 BITMAP/REVERSE 없음; FUNCTION은 expression index로 검출)
--   PURPOSE_CD: PK 제약(pg_index.indisprimary) 매칭 시 'PK', 그 외 'SEARCH'
INSERT INTO TB_META_INDEX (
    INDEX_ID, TABLE_ID, INDEX_NAME, INDEX_TYPE_CD,
    TABLESPACE_NAME, PURPOSE_CD, STATUS_CD,
    CREATED_BY, UPDATED_BY
)
SELECT
    nextval('SEQ_META_INDEX_ID'),
    mt.TABLE_ID,
    UPPER(c.relname),
    CASE
      -- 표현식(함수기반) 인덱스: indkey에 0 이 있으면 표현식 컬럼 포함
      WHEN 0 = ANY(idx.indkey::int[])      THEN 'FUNCTION'
      WHEN idx.indisunique                 THEN 'UNIQUE'
      ELSE 'NORMAL'
    END,
    UPPER(ts.spcname),                          -- TABLESPACE_NAME (PG 카탈로그에서 추출, 보통 NULL)
    CASE WHEN idx.indisprimary THEN 'PK' ELSE 'SEARCH' END,
    'ACTIVE', USER, USER
FROM pg_index idx
JOIN pg_class      c   ON c.oid = idx.indexrelid
JOIN pg_class      ct  ON ct.oid = idx.indrelid
JOIN pg_namespace  n   ON n.oid = ct.relnamespace
LEFT JOIN pg_tablespace ts ON ts.oid = c.reltablespace
JOIN TB_META_TABLE mt
      ON mt.SCHEMA_NAME = UPPER(n.nspname) AND mt.TABLE_NAME = UPPER(ct.relname)
WHERE UPPER(n.nspname) IN ('SVC1','SVC2'/* 대상 스키마 목록 */)
  AND NOT EXISTS (
        SELECT 1 FROM TB_META_INDEX m
         WHERE m.TABLE_ID   = mt.TABLE_ID
           AND m.INDEX_NAME = UPPER(c.relname)
      )
;

-- §7.5.3 TB_META_INDEX_HIST
INSERT INTO TB_META_INDEX_HIST (
    HIST_ID, HIST_TYPE, HIST_AT, HIST_BY, CHANGE_REASON,
    INDEX_ID, TABLE_ID, INDEX_NAME, INDEX_TYPE_CD,
    TABLESPACE_NAME, INI_TRANS, PCT_FREE,
    PURPOSE_CD, PERFORMANCE_NOTE, CREATE_DDL,
    STATUS_CD,
    CREATED_BY, CREATED_AT, UPDATED_BY, UPDATED_AT
)
SELECT
    nextval('SEQ_META_HIST_ID'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    x.INDEX_ID, x.TABLE_ID, x.INDEX_NAME, x.INDEX_TYPE_CD,
    x.TABLESPACE_NAME, x.INI_TRANS, x.PCT_FREE,
    x.PURPOSE_CD, x.PERFORMANCE_NOTE, x.CREATE_DDL,
    x.STATUS_CD,
    x.CREATED_BY, x.CREATED_AT, x.UPDATED_BY, x.UPDATED_AT
FROM TB_META_INDEX x
WHERE NOT EXISTS (
    SELECT 1 FROM TB_META_INDEX_HIST h
     WHERE h.INDEX_ID      = x.INDEX_ID
       AND h.HIST_TYPE     = 'I'
       AND h.CHANGE_REASON = 'INITIAL_LOAD'
)
;

-- §7.3.2 TB_META_INDEX_COLUMN — 컬럼
--   pg_index.indkey (smallint[]) 와 attribute 번호로 컬럼 정렬 순서 산출
--   indoption 의 bit 0 (DESC=1) 로 SORT_ORDER 판별 (PG 14 기준)
INSERT INTO TB_META_INDEX_COLUMN (INDEX_ID, COLUMN_POS, COLUMN_NAME, SORT_ORDER)
SELECT
    mi.INDEX_ID,
    (k.idx + 1)::int                            AS COLUMN_POS,
    UPPER(a.attname)                            AS COLUMN_NAME,
    CASE WHEN (idx.indoption[k.idx] & 1) = 1 THEN 'DESC' ELSE 'ASC' END AS SORT_ORDER
FROM pg_index idx
JOIN pg_class      c   ON c.oid = idx.indexrelid
JOIN pg_class      ct  ON ct.oid = idx.indrelid
JOIN pg_namespace  n   ON n.oid = ct.relnamespace
JOIN TB_META_TABLE mt
      ON mt.SCHEMA_NAME = UPPER(n.nspname) AND mt.TABLE_NAME = UPPER(ct.relname)
JOIN TB_META_INDEX mi
      ON mi.TABLE_ID = mt.TABLE_ID AND mi.INDEX_NAME = UPPER(c.relname)
CROSS JOIN LATERAL generate_series(0, array_length(idx.indkey::int[], 1) - 1) AS k(idx)
LEFT JOIN pg_attribute a
      ON a.attrelid = ct.oid AND a.attnum = idx.indkey[k.idx]
WHERE UPPER(n.nspname) IN ('SVC1','SVC2'/* 대상 스키마 목록 */)
  AND a.attname IS NOT NULL                     -- 표현식 컬럼(attnum=0)은 제외 (FUNC_EXPRESSION으로 별도 채울 항목)
  AND NOT EXISTS (
        SELECT 1 FROM TB_META_INDEX_COLUMN m
         WHERE m.INDEX_ID   = mi.INDEX_ID
           AND m.COLUMN_POS = (k.idx + 1)::int
      )
;

-- §7.3.2b 표현식(함수기반) 인덱스 컬럼 — pg_get_indexdef로 표현식 직접 적재
--   Oracle은 ALL_IND_COLUMNS에 SYS_NC 시스템 컬럼명으로 잡히나,
--   PG는 pg_attribute에 표현식 자리가 없으므로 별도 INSERT.
--   COLUMN_NAME: PG는 SYS_NC 시스템명이 없으므로 표현식 텍스트 대문자 저장
--                (Oracle SYS_NC와 구조적 차이 — 다이얼렉트 간 COLUMN_NAME
--                 직접 비교 불가, FUNC_EXPRESSION으로 비교할 것)
--   FUNC_EXPRESSION: 원본 표현식 텍스트 (2000자 절단)
INSERT INTO TB_META_INDEX_COLUMN (INDEX_ID, COLUMN_POS, COLUMN_NAME, SORT_ORDER, FUNC_EXPRESSION)
SELECT
    mi.INDEX_ID,
    (k.idx + 1)::int                                                            AS COLUMN_POS,
    LEFT(UPPER(pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, false)), 128)   AS COLUMN_NAME,
    CASE WHEN (idx.indoption[k.idx] & 1) = 1 THEN 'DESC' ELSE 'ASC' END        AS SORT_ORDER,
    LEFT(pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, false), 2000)         AS FUNC_EXPRESSION
FROM pg_index idx
JOIN pg_class      c   ON c.oid = idx.indexrelid
JOIN pg_class      ct  ON ct.oid = idx.indrelid
JOIN pg_namespace  n   ON n.oid = ct.relnamespace
JOIN TB_META_TABLE mt
      ON mt.SCHEMA_NAME = UPPER(n.nspname) AND mt.TABLE_NAME = UPPER(ct.relname)
JOIN TB_META_INDEX mi
      ON mi.TABLE_ID = mt.TABLE_ID AND mi.INDEX_NAME = UPPER(c.relname)
CROSS JOIN LATERAL generate_series(0, array_length(idx.indkey::int[], 1) - 1) AS k(idx)
WHERE UPPER(n.nspname) IN ('SVC1','SVC2'/* 대상 스키마 목록 */)
  AND idx.indkey[k.idx] = 0                         -- 표현식 자리만
  AND NOT EXISTS (
        SELECT 1 FROM TB_META_INDEX_COLUMN m
         WHERE m.INDEX_ID   = mi.INDEX_ID
           AND m.COLUMN_POS = (k.idx + 1)::int
      )
;

-- §7.5.4 TB_META_INDEX_COLUMN_HIST
INSERT INTO TB_META_INDEX_COLUMN_HIST (
    HIST_ID, HIST_TYPE, HIST_AT, HIST_BY, CHANGE_REASON,
    INDEX_ID, COLUMN_POS, COLUMN_NAME, SORT_ORDER, FUNC_EXPRESSION
)
SELECT
    nextval('SEQ_META_HIST_ID'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    ic.INDEX_ID, ic.COLUMN_POS, ic.COLUMN_NAME, ic.SORT_ORDER, ic.FUNC_EXPRESSION
FROM TB_META_INDEX_COLUMN ic
WHERE NOT EXISTS (
    SELECT 1 FROM TB_META_INDEX_COLUMN_HIST h
     WHERE h.INDEX_ID      = ic.INDEX_ID
       AND h.COLUMN_POS    = ic.COLUMN_POS
       AND h.HIST_TYPE     = 'I'
       AND h.CHANGE_REASON = 'INITIAL_LOAD'
)
;

-- =====================================================================
-- §7.4 TB_META_SEQUENCE — 시퀀스 적재
--   pg_sequences 뷰 (PG 10+) — start_value, increment_by, max_value, min_value,
--                              cache_size, cycle, last_value
--   START_WITH 는 last_value 로 근사 (Oracle LAST_NUMBER와 동일 의미)
--   ORDER_FLAG 는 PG에 없음 → 항상 'N'
-- =====================================================================
INSERT INTO TB_META_SEQUENCE (
    SEQUENCE_ID, SCHEMA_NAME, SEQUENCE_NAME,
    MIN_VALUE, MAX_VALUE, INCREMENT_BY, START_WITH, CACHE_SIZE,
    CYCLE_YN, ORDER_YN, PURPOSE_CD, STATUS_CD,
    CREATED_BY, UPDATED_BY
)
SELECT
    nextval('SEQ_META_SEQUENCE_ID'),
    UPPER(s.schemaname), UPPER(s.sequencename),
    s.min_value, s.max_value, s.increment_by, COALESCE(s.last_value, s.start_value), s.cache_size,
    CASE WHEN s.cycle THEN 'Y' ELSE 'N' END,
    'N',                                        -- ORDER_FLAG 미지원
    'ETC',                                      -- 용도는 담당자 업데이트
    'ACTIVE', USER, USER
FROM pg_sequences s
WHERE UPPER(s.schemaname) IN ('SVC1','SVC2'/* 대상 스키마 목록 */)
  AND UPPER(s.sequencename) NOT LIKE 'SEQ_META_%'  -- 메타 시퀀스 자기 자신 제외
  AND NOT EXISTS (
        SELECT 1 FROM TB_META_SEQUENCE m
         WHERE m.SCHEMA_NAME   = UPPER(s.schemaname)
           AND m.SEQUENCE_NAME = UPPER(s.sequencename)
      )
;

-- §7.5.5 TB_META_SEQUENCE_HIST
INSERT INTO TB_META_SEQUENCE_HIST (
    HIST_ID, HIST_TYPE, HIST_AT, HIST_BY, CHANGE_REASON,
    SEQUENCE_ID, SCHEMA_NAME, SEQUENCE_NAME,
    MIN_VALUE, MAX_VALUE, INCREMENT_BY, START_WITH, CACHE_SIZE,
    CYCLE_YN, ORDER_YN, PURPOSE_CD,
    USED_FOR_TABLE, USED_FOR_COLUMN, CREATE_DDL, STATUS_CD,
    CREATED_BY, CREATED_AT, UPDATED_BY, UPDATED_AT
)
SELECT
    nextval('SEQ_META_HIST_ID'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    q.SEQUENCE_ID, q.SCHEMA_NAME, q.SEQUENCE_NAME,
    q.MIN_VALUE, q.MAX_VALUE, q.INCREMENT_BY, q.START_WITH, q.CACHE_SIZE,
    q.CYCLE_YN, q.ORDER_YN, q.PURPOSE_CD,
    q.USED_FOR_TABLE, q.USED_FOR_COLUMN, q.CREATE_DDL, q.STATUS_CD,
    q.CREATED_BY, q.CREATED_AT, q.UPDATED_BY, q.UPDATED_AT
FROM TB_META_SEQUENCE q
WHERE NOT EXISTS (
    SELECT 1 FROM TB_META_SEQUENCE_HIST h
     WHERE h.SEQUENCE_ID   = q.SEQUENCE_ID
       AND h.HIST_TYPE     = 'I'
       AND h.CHANGE_REASON = 'INITIAL_LOAD'
)
;

COMMIT;
