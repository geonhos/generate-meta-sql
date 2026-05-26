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
SELECT mt.SCHEMA_NAME       AS index_owner,
       mi.INDEX_NAME,
       (k.idx + 1)::int     AS column_position,
       pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, false) AS column_expression,
       ic.INDEX_ID,
       ic.COLUMN_POS
  FROM TB_META_INDEX_COLUMN ic
  JOIN TB_META_INDEX        mi ON mi.INDEX_ID = ic.INDEX_ID
  JOIN TB_META_TABLE        mt ON mt.TABLE_ID = mi.TABLE_ID
  JOIN pg_class             c  ON UPPER(c.relname) = mi.INDEX_NAME
  JOIN pg_namespace         n  ON n.oid = c.relnamespace
                              AND UPPER(n.nspname) = mt.SCHEMA_NAME
  JOIN pg_index             idx ON idx.indexrelid = c.oid
 CROSS JOIN LATERAL generate_series(0, array_length(idx.indkey::int[], 1) - 1) AS k(idx)
 WHERE ic.FUNC_EXPRESSION IS NULL
   AND idx.indkey[k.idx] = 0                                  -- 표현식 자리
   AND (k.idx + 1)::int = ic.COLUMN_POS                       -- 포지션 매칭
 ORDER BY mt.SCHEMA_NAME, mi.INDEX_NAME, ic.COLUMN_POS;

-- =====================================================================
-- §6.1b INSERT — 03에서 누락된 표현식 컬럼 행 보강 (방어 코드)
--   03_initial_load.sql §7.3.2b에서 정상 적재되었으면 0건 INSERT.
--   03 이전 버전(표현식 INSERT 미포함)에서 실행된 환경에서도 정상 동작.
--   COLUMN_NAME: PG는 SYS_NC 시스템명이 없으므로 표현식 텍스트 대문자 저장.
-- =====================================================================
INSERT INTO TB_META_INDEX_COLUMN (INDEX_ID, COLUMN_POS, COLUMN_NAME, SORT_ORDER, FUNC_EXPRESSION)
SELECT
    mi.INDEX_ID,
    (k.idx + 1)::int,
    LEFT(UPPER(pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, false)), 128),
    CASE WHEN (idx.indoption[k.idx] & 1) = 1 THEN 'DESC' ELSE 'ASC' END,
    LEFT(pg_get_indexdef(idx.indexrelid, (k.idx + 1)::int, false), 2000)
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
  AND idx.indkey[k.idx] = 0
  AND NOT EXISTS (
        SELECT 1 FROM TB_META_INDEX_COLUMN m
         WHERE m.INDEX_ID   = mi.INDEX_ID
           AND m.COLUMN_POS = (k.idx + 1)::int
      )
;

-- §6.1c HIST — §6.1b에서 신규 INSERT된 행에 대한 INITIAL_LOAD 이력 적재
INSERT INTO TB_META_INDEX_COLUMN_HIST (
    HIST_ID, HIST_TYPE, HIST_AT, HIST_BY, CHANGE_REASON,
    INDEX_ID, COLUMN_POS, COLUMN_NAME, SORT_ORDER, FUNC_EXPRESSION
)
SELECT
    nextval('SEQ_META_HIST_ID'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    ic.INDEX_ID, ic.COLUMN_POS, ic.COLUMN_NAME, ic.SORT_ORDER, ic.FUNC_EXPRESSION
FROM TB_META_INDEX_COLUMN ic
WHERE ic.FUNC_EXPRESSION IS NOT NULL
  AND NOT EXISTS (
      SELECT 1 FROM TB_META_INDEX_COLUMN_HIST h
       WHERE h.INDEX_ID      = ic.INDEX_ID
         AND h.COLUMN_POS    = ic.COLUMN_POS
         AND h.HIST_TYPE     = 'I'
         AND h.CHANGE_REASON = 'INITIAL_LOAD'
  )
;

-- =====================================================================
-- §6.2 UPDATE — 표현식 자동 적재 (PG는 LONG 제약 없으므로 SQL 한 번으로 처리)
-- =====================================================================
UPDATE TB_META_INDEX_COLUMN ic
   SET FUNC_EXPRESSION = LEFT(sub.expr, 2000)
  FROM (
    SELECT ic2.INDEX_ID, ic2.COLUMN_POS,
           pg_get_indexdef(idx.indexrelid, ic2.COLUMN_POS::int, false) AS expr
      FROM TB_META_INDEX_COLUMN ic2
      JOIN TB_META_INDEX  mi ON mi.INDEX_ID = ic2.INDEX_ID
      JOIN TB_META_TABLE  mt ON mt.TABLE_ID = mi.TABLE_ID
      JOIN pg_class       c  ON UPPER(c.relname) = mi.INDEX_NAME
      JOIN pg_namespace   n  ON n.oid = c.relnamespace
                            AND UPPER(n.nspname) = mt.SCHEMA_NAME
      JOIN pg_index       idx ON idx.indexrelid = c.oid
     WHERE ic2.FUNC_EXPRESSION IS NULL
       AND idx.indkey[ic2.COLUMN_POS - 1] = 0
  ) sub
 WHERE ic.INDEX_ID   = sub.INDEX_ID
   AND ic.COLUMN_POS = sub.COLUMN_POS
;

-- =====================================================================
-- §6.3 HIST 적재 — CHANGE_REASON='FUNC_EXPRESSION_BACKFILL' 중복 가드
-- =====================================================================
INSERT INTO TB_META_INDEX_COLUMN_HIST (
    HIST_ID, HIST_TYPE, HIST_AT, HIST_BY, CHANGE_REASON,
    INDEX_ID, COLUMN_POS, COLUMN_NAME, SORT_ORDER, FUNC_EXPRESSION
)
SELECT nextval('SEQ_META_HIST_ID'), 'U', CURRENT_TIMESTAMP, USER, 'FUNC_EXPRESSION_BACKFILL',
       ic.INDEX_ID, ic.COLUMN_POS, ic.COLUMN_NAME, ic.SORT_ORDER, ic.FUNC_EXPRESSION
  FROM TB_META_INDEX_COLUMN ic
 WHERE ic.FUNC_EXPRESSION IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM TB_META_INDEX_COLUMN_HIST h
        WHERE h.INDEX_ID      = ic.INDEX_ID
          AND h.COLUMN_POS    = ic.COLUMN_POS
          AND h.HIST_TYPE     = 'U'
          AND h.CHANGE_REASON = 'FUNC_EXPRESSION_BACKFILL'
   )
;

COMMIT;

-- =====================================================================
-- §6.4 결과 검증
-- =====================================================================
SELECT 'PENDING' AS phase, COUNT(*) AS cnt
  FROM TB_META_INDEX_COLUMN ic
  JOIN TB_META_INDEX  mi ON mi.INDEX_ID = ic.INDEX_ID
  JOIN TB_META_TABLE  mt ON mt.TABLE_ID = mi.TABLE_ID
  JOIN pg_class       c  ON UPPER(c.relname) = mi.INDEX_NAME
  JOIN pg_namespace   n  ON n.oid = c.relnamespace
                        AND UPPER(n.nspname) = mt.SCHEMA_NAME
  JOIN pg_index       idx ON idx.indexrelid = c.oid
 WHERE ic.FUNC_EXPRESSION IS NULL
   AND idx.indkey[ic.COLUMN_POS - 1] = 0
UNION ALL
SELECT 'BACKFILLED', COUNT(*)
  FROM TB_META_INDEX_COLUMN
 WHERE FUNC_EXPRESSION IS NOT NULL
UNION ALL
SELECT 'HIST_BACKFILL', COUNT(*)
  FROM TB_META_INDEX_COLUMN_HIST
 WHERE HIST_TYPE='U' AND CHANGE_REASON='FUNC_EXPRESSION_BACKFILL'
;
