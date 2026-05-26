-- =====================================================================
-- 03_initial_load.sql — 시스템 카탈로그 → 메타 테이블 적재 + HIST (PostgreSQL 14+)
-- 실행 순서: 3 / 3
-- 선행: 02_common_code.sql
-- 후행: (없음 — 이후 비즈니스 메타 수기 UPDATE)
-- 출처: DB_메타정보_관리체계_표준설계.md §7 (7.1~7.5)
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../03_initial_load.sql 참조)
--
-- 사전 수정 필요:
--   - WHERE t.table_schema IN ('svc1','svc2', ...) 의 스키마 목록을 실제
--     대상 스키마(소문자)로 교체. PG는 unquoted 식별자를 lowercase로
--     저장하므로 카탈로그 값을 그대로 적재한다.
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
-- 식별자 케이스 정책:
--   PG는 unquoted CREATE 시 lowercase 저장. 카탈로그 조회로 받은 값을
--   변환 없이 그대로 적재한다 (소문자/대문자 모두 처리 가능).
--   Oracle 원본은 UPPER() 대문자 정책 — PG에서는 불필요.
-- =====================================================================

-- =====================================================================
-- §7.1 TB_META_TABLE — 테이블/뷰 적재 (VIEW_YN으로 구분)
-- =====================================================================

-- (1) 일반 테이블 (VIEW_YN='N')
INSERT INTO tb_meta_table (
    table_id, schema_name, table_name, logical_name, description,
    view_yn, service_cd, owner_emp_id,
    key_table_yn, isolation_yn, pci_yn,
    retention_period_cd, status_cd,
    created_by, updated_by
)
SELECT
    nextval('seq_meta_table_id'),
    t.table_schema,
    t.table_name,
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
WHERE t.table_schema IN ('svc1','svc2'/* 대상 스키마 목록 (대문자) */)
  AND t.table_type = 'BASE TABLE'
  AND t.table_name NOT LIKE 'tb_meta_%'  -- 자기 자신 제외
  AND NOT EXISTS (                              -- 재실행 중복 방지
        SELECT 1 FROM tb_meta_table m
         WHERE m.schema_name = t.table_schema
           AND m.table_name  = t.table_name
      )
;

-- (2) 뷰 (VIEW_YN='Y')
INSERT INTO tb_meta_table (
    table_id, schema_name, table_name, logical_name, description,
    view_yn, service_cd, owner_emp_id,
    key_table_yn, isolation_yn, pci_yn,
    retention_period_cd, status_cd,
    created_by, updated_by
)
SELECT
    nextval('seq_meta_table_id'),
    v.table_schema,
    v.table_name,
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
WHERE v.table_schema IN ('svc1','svc2'/* 대상 스키마 목록 */)
  AND v.table_name NOT LIKE 'tb_meta_%'
  AND NOT EXISTS (
        SELECT 1 FROM tb_meta_table m
         WHERE m.schema_name = v.table_schema
           AND m.table_name  = v.table_name
      )
;

-- §7.5.1 TB_META_TABLE_HIST — 'I'/'INITIAL_LOAD' 미존재 행만 적재
INSERT INTO tb_meta_table_hist (
    hist_id, hist_type, hist_at, hist_by, change_reason,
    table_id, schema_name, table_name, logical_name, description,
    view_yn, service_cd, owner_emp_id, secondary_emp_id,
    key_table_yn, isolation_yn, isolation_level_cd,
    pci_yn, retention_period_cd, retention_basis, tos_cd,
    status_cd, remark,
    created_by, created_at, updated_by, updated_at
)
SELECT
    nextval('seq_meta_hist_id'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    t.table_id, t.schema_name, t.table_name, t.logical_name, t.description,
    t.view_yn, t.service_cd, t.owner_emp_id, t.secondary_emp_id,
    t.key_table_yn, t.isolation_yn, t.isolation_level_cd,
    t.pci_yn, t.retention_period_cd, t.retention_basis, t.tos_cd,
    t.status_cd, t.remark,
    t.created_by, t.created_at, t.updated_by, t.updated_at
FROM tb_meta_table t
WHERE NOT EXISTS (
    SELECT 1 FROM tb_meta_table_hist h
     WHERE h.table_id      = t.table_id
       AND h.hist_type     = 'I'
       AND h.change_reason = 'INITIAL_LOAD'
)
;

-- =====================================================================
-- §7.2 TB_META_COLUMN — 컬럼 적재
--   PK/UK/FK 판별은 information_schema.table_constraints (PRIMARY KEY/UNIQUE/FOREIGN KEY)
--   ENCRYPTION 정보는 PG 표준 카탈로그에 없음 — ENCRYPTION_YN='N' 고정
-- =====================================================================
INSERT INTO tb_meta_column (
    column_id, table_id, column_name, column_order,
    logical_name, description,
    data_type, data_length, data_precision, data_scale,
    nullable_yn, default_value,
    pk_yn, uk_yn, fk_yn,
    pci_yn, sensitivity_cd,
    encryption_yn, encryption_alg, masking_yn,
    status_cd, created_by, updated_by
)
SELECT
    nextval('seq_meta_column_id'),
    mt.table_id,
    tc.column_name,
    tc.ordinal_position,
    NULL,
    LEFT(d.description, 2000),                  -- pg_description (컬럼 코멘트)
    tc.data_type,
    COALESCE(tc.character_maximum_length, tc.numeric_precision),  -- DATA_LENGTH (문자형 우선, 그 외 numeric_precision)
    tc.numeric_precision,
    tc.numeric_scale,
    CASE tc.is_nullable WHEN 'YES' THEN 'Y' ELSE 'N' END,
    LEFT(tc.column_default, 500),               -- DEFAULT_VALUE: PG column_default 직접 적재
    CASE WHEN pk.column_name IS NOT NULL THEN 'Y' ELSE 'N' END,
    CASE WHEN uk.column_name IS NOT NULL THEN 'Y' ELSE 'N' END,
    CASE WHEN fk.column_name IS NOT NULL THEN 'Y' ELSE 'N' END,
    'N','LOW',
    'N',                                        -- ENCRYPTION_YN: PG 카탈로그 미수집
    NULL,
    'N',
    'ACTIVE', USER, USER
FROM information_schema.columns tc
JOIN tb_meta_table mt
      ON mt.schema_name = tc.table_schema AND mt.table_name = tc.table_name
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
    SELECT 1 FROM tb_meta_column m
     WHERE m.table_id    = mt.table_id
       AND m.column_name = tc.column_name
)
;

-- DEFAULT_VALUE: Oracle은 DATA_DEFAULT가 LONG 타입이라 SQL-only 적재 불가.
-- PG는 information_schema.columns.column_default가 TEXT이므로 직접 적재한다.

-- §7.5.2 TB_META_COLUMN_HIST
INSERT INTO tb_meta_column_hist (
    hist_id, hist_type, hist_at, hist_by, change_reason,
    column_id, table_id, column_name, column_order,
    logical_name, description,
    data_type, data_length, data_precision, data_scale,
    nullable_yn, default_value,
    pk_yn, uk_yn, fk_yn,
    pci_yn, pci_category_cd, sensitivity_cd,
    encryption_yn, encryption_alg, masking_yn, masking_rule_cd,
    retention_period_cd, tos_cd, status_cd, remark,
    created_by, created_at, updated_by, updated_at
)
SELECT
    nextval('seq_meta_hist_id'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    c.column_id, c.table_id, c.column_name, c.column_order,
    c.logical_name, c.description,
    c.data_type, c.data_length, c.data_precision, c.data_scale,
    c.nullable_yn, c.default_value,
    c.pk_yn, c.uk_yn, c.fk_yn,
    c.pci_yn, c.pci_category_cd, c.sensitivity_cd,
    c.encryption_yn, c.encryption_alg, c.masking_yn, c.masking_rule_cd,
    c.retention_period_cd, c.tos_cd, c.status_cd, c.remark,
    c.created_by, c.created_at, c.updated_by, c.updated_at
FROM tb_meta_column c
WHERE NOT EXISTS (
    SELECT 1 FROM tb_meta_column_hist h
     WHERE h.column_id     = c.column_id
       AND h.hist_type     = 'I'
       AND h.change_reason = 'INITIAL_LOAD'
)
;

-- =====================================================================
-- §7.3 인덱스 적재
-- =====================================================================

-- §7.3.1 TB_META_INDEX — 헤더
--   INDEX_TYPE_CD: UNIQUE 우선, 그 외 NORMAL (PG에는 BITMAP/REVERSE 없음; FUNCTION은 expression index로 검출)
--   PURPOSE_CD: PK 제약(pg_index.indisprimary) 매칭 시 'PK', 그 외 'SEARCH'
INSERT INTO tb_meta_index (
    index_id, table_id, index_name, index_type_cd,
    tablespace_name, purpose_cd, status_cd,
    created_by, updated_by
)
SELECT
    nextval('seq_meta_index_id'),
    mt.table_id,
    c.relname,
    CASE
      -- 표현식(함수기반) 인덱스: indkey에 0 이 있으면 표현식 컬럼 포함
      WHEN 0 = ANY(idx.indkey::int[])      THEN 'FUNCTION'
      WHEN idx.indisunique                 THEN 'UNIQUE'
      ELSE 'NORMAL'
    END,
    ts.spcname,                          -- TABLESPACE_NAME (PG 카탈로그에서 추출, 보통 NULL)
    CASE WHEN idx.indisprimary THEN 'PK' ELSE 'SEARCH' END,
    'ACTIVE', USER, USER
FROM pg_index idx
JOIN pg_class      c   ON c.oid = idx.indexrelid
JOIN pg_class      ct  ON ct.oid = idx.indrelid
JOIN pg_namespace  n   ON n.oid = ct.relnamespace
LEFT JOIN pg_tablespace ts ON ts.oid = c.reltablespace
JOIN tb_meta_table mt
      ON mt.schema_name = n.nspname AND mt.table_name = ct.relname
WHERE n.nspname IN ('svc1','svc2'/* 대상 스키마 목록 */)
  AND NOT EXISTS (
        SELECT 1 FROM tb_meta_index m
         WHERE m.table_id   = mt.table_id
           AND m.index_name = c.relname
      )
;

-- §7.5.3 TB_META_INDEX_HIST
INSERT INTO tb_meta_index_hist (
    hist_id, hist_type, hist_at, hist_by, change_reason,
    index_id, table_id, index_name, index_type_cd,
    tablespace_name, ini_trans, pct_free,
    purpose_cd, performance_note, create_ddl,
    status_cd,
    created_by, created_at, updated_by, updated_at
)
SELECT
    nextval('seq_meta_hist_id'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    x.index_id, x.table_id, x.index_name, x.index_type_cd,
    x.tablespace_name, x.ini_trans, x.pct_free,
    x.purpose_cd, x.performance_note, x.create_ddl,
    x.status_cd,
    x.created_by, x.created_at, x.updated_by, x.updated_at
FROM tb_meta_index x
WHERE NOT EXISTS (
    SELECT 1 FROM tb_meta_index_hist h
     WHERE h.index_id      = x.index_id
       AND h.hist_type     = 'I'
       AND h.change_reason = 'INITIAL_LOAD'
)
;

-- §7.3.2 TB_META_INDEX_COLUMN — 컬럼
--   pg_index.indkey (smallint[]) 와 attribute 번호로 컬럼 정렬 순서 산출
--   indoption 의 bit 0 (DESC=1) 로 SORT_ORDER 판별 (PG 14 기준)
INSERT INTO tb_meta_index_column (index_id, column_pos, column_name, sort_order)
SELECT
    mi.index_id,
    (k.idx + 1)::int                            AS column_pos,
    a.attname                            AS column_name,
    CASE WHEN (idx.indoption[k.idx] & 1) = 1 THEN 'DESC' ELSE 'ASC' END AS sort_order
FROM pg_index idx
JOIN pg_class      c   ON c.oid = idx.indexrelid
JOIN pg_class      ct  ON ct.oid = idx.indrelid
JOIN pg_namespace  n   ON n.oid = ct.relnamespace
JOIN tb_meta_table mt
      ON mt.schema_name = n.nspname AND mt.table_name = ct.relname
JOIN tb_meta_index mi
      ON mi.table_id = mt.table_id AND mi.index_name = c.relname
CROSS JOIN LATERAL generate_series(0, array_length(idx.indkey::int[], 1) - 1) AS k(idx)
LEFT JOIN pg_attribute a
      ON a.attrelid = ct.oid AND a.attnum = idx.indkey[k.idx]
WHERE n.nspname IN ('svc1','svc2'/* 대상 스키마 목록 */)
  AND a.attname IS NOT NULL                     -- 표현식 컬럼(attnum=0)은 제외 (FUNC_EXPRESSION으로 별도 채울 항목)
  AND NOT EXISTS (
        SELECT 1 FROM tb_meta_index_column m
         WHERE m.index_id   = mi.index_id
           AND m.column_pos = (k.idx + 1)::int
      )
;

-- §7.3.2b 표현식(함수기반) 인덱스 컬럼 — pg_get_indexdef로 표현식 직접 적재
--   Oracle은 ALL_IND_COLUMNS에 SYS_NC 시스템 컬럼명으로 잡히나,
--   PG는 pg_attribute에 표현식 자리가 없으므로 별도 INSERT.
--   COLUMN_NAME: PG는 SYS_NC 시스템명이 없으므로 표현식 텍스트 저장
--                (Oracle SYS_NC와 구조적 차이 — 다이얼렉트 간 COLUMN_NAME
--                 직접 비교 불가, func_expression으로 비교할 것)
--   FUNC_EXPRESSION: 원본 표현식 텍스트 (2000자 절단)
INSERT INTO tb_meta_index_column (index_id, column_pos, column_name, sort_order, func_expression)
SELECT
    mi.index_id,
    (k.idx + 1)::int                                                            AS column_pos,
    LEFT(pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, FALSE), 128)   AS column_name,
    CASE WHEN (idx.indoption[k.idx] & 1) = 1 THEN 'DESC' ELSE 'ASC' END        AS sort_order,
    LEFT(pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, FALSE), 2000)         AS func_expression
FROM pg_index idx
JOIN pg_class      c   ON c.oid = idx.indexrelid
JOIN pg_class      ct  ON ct.oid = idx.indrelid
JOIN pg_namespace  n   ON n.oid = ct.relnamespace
JOIN tb_meta_table mt
      ON mt.schema_name = n.nspname AND mt.table_name = ct.relname
JOIN tb_meta_index mi
      ON mi.table_id = mt.table_id AND mi.index_name = c.relname
CROSS JOIN LATERAL generate_series(0, array_length(idx.indkey::int[], 1) - 1) AS k(idx)
WHERE n.nspname IN ('svc1','svc2'/* 대상 스키마 목록 */)
  AND idx.indkey[k.idx] = 0                         -- 표현식 자리만
  AND NOT EXISTS (
        SELECT 1 FROM tb_meta_index_column m
         WHERE m.index_id   = mi.index_id
           AND m.column_pos = (k.idx + 1)::int
      )
;

-- §7.5.4 TB_META_INDEX_COLUMN_HIST
INSERT INTO tb_meta_index_column_hist (
    hist_id, hist_type, hist_at, hist_by, change_reason,
    index_id, column_pos, column_name, sort_order, func_expression
)
SELECT
    nextval('seq_meta_hist_id'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    ic.index_id, ic.column_pos, ic.column_name, ic.sort_order, ic.func_expression
FROM tb_meta_index_column ic
WHERE NOT EXISTS (
    SELECT 1 FROM tb_meta_index_column_hist h
     WHERE h.index_id      = ic.index_id
       AND h.column_pos    = ic.column_pos
       AND h.hist_type     = 'I'
       AND h.change_reason = 'INITIAL_LOAD'
)
;

-- =====================================================================
-- §7.4 TB_META_SEQUENCE — 시퀀스 적재
--   pg_sequences 뷰 (PG 10+) — start_value, increment_by, max_value, min_value,
--                              cache_size, cycle, last_value
--   START_WITH 는 last_value 로 근사 (Oracle LAST_NUMBER와 동일 의미)
--   ORDER_FLAG 는 PG에 없음 → 항상 'N'
-- =====================================================================
INSERT INTO tb_meta_sequence (
    sequence_id, schema_name, sequence_name,
    min_value, max_value, increment_by, start_with, cache_size,
    cycle_yn, order_yn, purpose_cd, status_cd,
    created_by, updated_by
)
SELECT
    nextval('seq_meta_sequence_id'),
    s.schemaname, s.sequencename,
    s.min_value, s.max_value, s.increment_by, COALESCE(s.last_value, s.start_value), s.cache_size,
    CASE WHEN s.cycle THEN 'Y' ELSE 'N' END,
    'N',                                        -- ORDER_FLAG 미지원
    'ETC',                                      -- 용도는 담당자 업데이트
    'ACTIVE', USER, USER
FROM pg_sequences s
WHERE s.schemaname IN ('svc1','svc2'/* 대상 스키마 목록 */)
  AND s.sequencename NOT LIKE 'seq_meta_%'  -- 메타 시퀀스 자기 자신 제외
  AND NOT EXISTS (
        SELECT 1 FROM tb_meta_sequence m
         WHERE m.schema_name   = s.schemaname
           AND m.sequence_name = s.sequencename
      )
;

-- §7.5.5 TB_META_SEQUENCE_HIST
INSERT INTO tb_meta_sequence_hist (
    hist_id, hist_type, hist_at, hist_by, change_reason,
    sequence_id, schema_name, sequence_name,
    min_value, max_value, increment_by, start_with, cache_size,
    cycle_yn, order_yn, purpose_cd,
    used_for_table, used_for_column, create_ddl, status_cd,
    created_by, created_at, updated_by, updated_at
)
SELECT
    nextval('seq_meta_hist_id'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    q.sequence_id, q.schema_name, q.sequence_name,
    q.min_value, q.max_value, q.increment_by, q.start_with, q.cache_size,
    q.cycle_yn, q.order_yn, q.purpose_cd,
    q.used_for_table, q.used_for_column, q.create_ddl, q.status_cd,
    q.created_by, q.created_at, q.updated_by, q.updated_at
FROM tb_meta_sequence q
WHERE NOT EXISTS (
    SELECT 1 FROM tb_meta_sequence_hist h
     WHERE h.sequence_id   = q.sequence_id
       AND h.hist_type     = 'I'
       AND h.change_reason = 'INITIAL_LOAD'
)
;

COMMIT;
