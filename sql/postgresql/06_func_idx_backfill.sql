-- =====================================================================
-- 06_func_idx_backfill.sql — 표현식(함수기반) 인덱스 FUNC_EXPRESSION 보강 (PostgreSQL 14+)
-- 실행 위치: 03 적재 후 표현식 인덱스가 있는 경우 (선택적)
-- 선행: 03_initial_load.sql 완료
-- 출처: 표준설계서 §7.3 + 운영가이드 §5
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../06_func_idx_backfill.sql 참조)
--
-- 배경 (Oracle vs PostgreSQL):
--   Oracle은 ALL_IND_EXPRESSIONS.COLUMN_EXPRESSION이 LONG 타입이라
--   SQL 안에서 직접 가공/변환이 불가능 → 운영자 수기 UPDATE 패턴.
--   PostgreSQL은 pg_get_indexdef(indexrelid, k, false) 함수가 표현식을
--   READABLE TEXT로 직접 반환 → 본 스크립트가 SQL-only로 UPDATE까지 자동화.
--
-- 처리 흐름:
--   1) §6.1 표현식 인덱스 컬럼 식별 (pg_index.indkey 에 0 포함)
--   2) §6.2 UPDATE 자동 실행 — pg_get_indexdef 로 표현식 텍스트 적재
--   3) §6.3 HIST 적재 — CHANGE_REASON='FUNC_EXPRESSION_BACKFILL'
--   4) §6.4 결과 검증
-- =====================================================================

-- =====================================================================
-- §6.1 보강 대상 식별 — pg_get_indexdef 로 표현식 텍스트 추출
--   - indkey[i] = 0 인 자리가 표현식 컬럼 (실제 attribute가 아닌 식)
--   - pg_get_indexdef(idx.indexrelid, i+1, false) → 해당 키 위치의 표현식 SQL
-- =====================================================================
SELECT mt.schema_name       AS index_owner,
       mi.index_name,
       (k.idx + 1)::int     AS column_position,
       pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, FALSE) AS column_expression,
       ic.index_id,
       ic.column_pos
  FROM tb_meta_index_column ic
  JOIN tb_meta_index        mi ON mi.index_id = ic.index_id
  JOIN tb_meta_table        mt ON mt.table_id = mi.table_id
  JOIN pg_class             c  ON c.relname = mi.index_name
  JOIN pg_namespace         n  ON n.oid = c.relnamespace
                              AND n.nspname = mt.schema_name
  JOIN pg_index             idx ON idx.indexrelid = c.oid
 CROSS JOIN LATERAL generate_series(0, array_length(idx.indkey::int[], 1) - 1) AS k(idx)
 WHERE ic.func_expression IS NULL
   AND idx.indkey[k.idx] = 0                                  -- 표현식 자리
   AND (k.idx + 1)::int = ic.column_pos                       -- 포지션 매칭
 ORDER BY mt.schema_name, mi.index_name, ic.column_pos;

-- =====================================================================
-- §6.1b INSERT — 03에서 누락된 표현식 컬럼 행 보강 (방어 코드)
--   03_initial_load.sql §7.3.2b에서 정상 적재되었으면 0건 INSERT.
--   03 이전 버전(표현식 INSERT 미포함)에서 실행된 환경에서도 정상 동작.
--   COLUMN_NAME: PG는 SYS_NC 시스템명이 없으므로 표현식 텍스트 저장.
-- =====================================================================
INSERT INTO tb_meta_index_column (index_id, column_pos, column_name, sort_order, func_expression)
SELECT
    mi.index_id,
    (k.idx + 1)::int,
    LEFT(pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, FALSE), 128),
    CASE WHEN (idx.indoption[k.idx] & 1) = 1 THEN 'DESC' ELSE 'ASC' END,
    LEFT(pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, FALSE), 2000)
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
  AND idx.indkey[k.idx] = 0
  AND NOT EXISTS (
        SELECT 1 FROM tb_meta_index_column m
         WHERE m.index_id   = mi.index_id
           AND m.column_pos = (k.idx + 1)::int
      )
;

-- §6.1c HIST — §6.1b에서 신규 INSERT된 행에 대한 INITIAL_LOAD 이력 적재
INSERT INTO tb_meta_index_column_hist (
    hist_id, hist_type, hist_at, hist_by, change_reason,
    index_id, column_pos, column_name, sort_order, func_expression
)
SELECT
    nextval('seq_meta_hist_id'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    ic.index_id, ic.column_pos, ic.column_name, ic.sort_order, ic.func_expression
FROM tb_meta_index_column ic
WHERE ic.func_expression IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM tb_meta_index_column_hist h
       WHERE h.index_id      = ic.index_id
         AND h.column_pos    = ic.column_pos
         AND h.hist_type     = 'I'
         AND h.change_reason = 'INITIAL_LOAD'
  )
;

-- =====================================================================
-- §6.2 UPDATE — 표현식 자동 적재 (PG는 LONG 제약 없으므로 SQL 한 번으로 처리)
-- =====================================================================
UPDATE tb_meta_index_column ic
   SET func_expression = LEFT(sub.expr, 2000)
  FROM (
    SELECT ic2.index_id, ic2.column_pos,
           pg_get_indexdef(idx.indexrelid, ic2.column_pos::int, FALSE) AS expr
      FROM tb_meta_index_column ic2
      JOIN tb_meta_index  mi ON mi.index_id = ic2.index_id
      JOIN tb_meta_table  mt ON mt.table_id = mi.table_id
      JOIN pg_class       c  ON c.relname = mi.index_name
      JOIN pg_namespace   n  ON n.oid = c.relnamespace
                            AND n.nspname = mt.schema_name
      JOIN pg_index       idx ON idx.indexrelid = c.oid
     WHERE ic2.func_expression IS NULL
       AND idx.indkey[ic2.column_pos - 1] = 0
  ) sub
 WHERE ic.index_id   = sub.index_id
   AND ic.column_pos = sub.column_pos
;

-- =====================================================================
-- §6.3 HIST 적재 — CHANGE_REASON='FUNC_EXPRESSION_BACKFILL' 중복 가드
-- =====================================================================
INSERT INTO tb_meta_index_column_hist (
    hist_id, hist_type, hist_at, hist_by, change_reason,
    index_id, column_pos, column_name, sort_order, func_expression
)
SELECT nextval('seq_meta_hist_id'), 'U', CURRENT_TIMESTAMP, USER, 'FUNC_EXPRESSION_BACKFILL',
       ic.index_id, ic.column_pos, ic.column_name, ic.sort_order, ic.func_expression
  FROM tb_meta_index_column ic
 WHERE ic.func_expression IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM tb_meta_index_column_hist h
        WHERE h.index_id      = ic.index_id
          AND h.column_pos    = ic.column_pos
          AND h.hist_type     = 'U'
          AND h.change_reason = 'FUNC_EXPRESSION_BACKFILL'
   )
;

COMMIT;

-- =====================================================================
-- §6.4 결과 검증
-- =====================================================================
SELECT 'PENDING' AS phase, COUNT(*) AS cnt
  FROM tb_meta_index_column ic
  JOIN tb_meta_index  mi ON mi.index_id = ic.index_id
  JOIN tb_meta_table  mt ON mt.table_id = mi.table_id
  JOIN pg_class       c  ON c.relname = mi.index_name
  JOIN pg_namespace   n  ON n.oid = c.relnamespace
                        AND n.nspname = mt.schema_name
  JOIN pg_index       idx ON idx.indexrelid = c.oid
 WHERE ic.func_expression IS NULL
   AND idx.indkey[ic.column_pos - 1] = 0
UNION ALL
SELECT 'BACKFILLED', COUNT(*)
  FROM tb_meta_index_column
 WHERE func_expression IS NOT NULL
UNION ALL
SELECT 'HIST_BACKFILL', COUNT(*)
  FROM tb_meta_index_column_hist
 WHERE hist_type='U' AND change_reason='FUNC_EXPRESSION_BACKFILL'
;
