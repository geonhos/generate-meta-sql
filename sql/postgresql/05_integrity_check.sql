-- =====================================================================
-- 05_integrity_check.sql — 메타 적재 후 정합성/운영 점검 쿼리 모음 (PostgreSQL 14+)
-- 실행 위치: 02·03 적재 직후 검증 + 일상 운영 점검 (수시)
-- 선행: 01/02/03 완료 (CD_TOS 사용 시 02a 포함)
-- 정책: SELECT만 — 데이터 변경 없음.
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../05_integrity_check.sql 참조)
-- 매핑: FROM DUAL 제거(PG는 SELECT FROM 없이도 가능),
--       v$session/v$lock/dba_objects → pg_stat_activity + pg_locks + pg_class
-- =====================================================================

-- =====================================================================
-- §5.1 코드 적재 검증
-- =====================================================================
SELECT CODE_GROUP, COUNT(*) AS cnt
  FROM TB_META_CODE
 GROUP BY CODE_GROUP
 ORDER BY CODE_GROUP;

-- =====================================================================
-- §5.2 본 ↔ HIST 행수 일치 검증
-- =====================================================================
SELECT 'TABLE'    AS src,
       (SELECT COUNT(*) FROM TB_META_TABLE)             AS main,
       (SELECT COUNT(*) FROM TB_META_TABLE_HIST
         WHERE HIST_TYPE='I' AND CHANGE_REASON='INITIAL_LOAD') AS hist
UNION ALL
SELECT 'COLUMN',
       (SELECT COUNT(*) FROM TB_META_COLUMN),
       (SELECT COUNT(*) FROM TB_META_COLUMN_HIST
         WHERE HIST_TYPE='I' AND CHANGE_REASON='INITIAL_LOAD')
UNION ALL
SELECT 'INDEX',
       (SELECT COUNT(*) FROM TB_META_INDEX),
       (SELECT COUNT(*) FROM TB_META_INDEX_HIST
         WHERE HIST_TYPE='I' AND CHANGE_REASON='INITIAL_LOAD')
UNION ALL
SELECT 'INDEX_COL',
       (SELECT COUNT(*) FROM TB_META_INDEX_COLUMN),
       (SELECT COUNT(*) FROM TB_META_INDEX_COLUMN_HIST
         WHERE HIST_TYPE='I' AND CHANGE_REASON='INITIAL_LOAD')
UNION ALL
SELECT 'SEQUENCE',
       (SELECT COUNT(*) FROM TB_META_SEQUENCE),
       (SELECT COUNT(*) FROM TB_META_SEQUENCE_HIST
         WHERE HIST_TYPE='I' AND CHANGE_REASON='INITIAL_LOAD')
UNION ALL
SELECT 'CODE',
       (SELECT COUNT(*) FROM TB_META_CODE),
       (SELECT COUNT(*) FROM TB_META_CODE_HIST
         WHERE HIST_TYPE='I' AND CHANGE_REASON='INITIAL_LOAD')
;

-- =====================================================================
-- §5.3 코드값 무결성 검증 (참조 정합성)
-- =====================================================================
SELECT t.TABLE_ID, t.SCHEMA_NAME, t.TABLE_NAME,
       '잘못된 SERVICE_CD: '||t.SERVICE_CD AS issue
  FROM TB_META_TABLE t
 WHERE NOT EXISTS (
       SELECT 1 FROM TB_META_CODE c
        WHERE c.CODE_GROUP='CD_SERVICE' AND c.CODE_VALUE = t.SERVICE_CD
   )
UNION ALL
SELECT t.TABLE_ID, t.SCHEMA_NAME, t.TABLE_NAME,
       '잘못된 RETENTION_PERIOD_CD: '||t.RETENTION_PERIOD_CD
  FROM TB_META_TABLE t
 WHERE NOT EXISTS (
       SELECT 1 FROM TB_META_CODE c
        WHERE c.CODE_GROUP='CD_RETENTION_PERIOD' AND c.CODE_VALUE = t.RETENTION_PERIOD_CD
   )
UNION ALL
SELECT t.TABLE_ID, t.SCHEMA_NAME, t.TABLE_NAME,
       '잘못된 STATUS_CD: '||t.STATUS_CD
  FROM TB_META_TABLE t
 WHERE NOT EXISTS (
       SELECT 1 FROM TB_META_CODE c
        WHERE c.CODE_GROUP='CD_STATUS' AND c.CODE_VALUE = t.STATUS_CD
   )
;

-- =====================================================================
-- §5.4 SENSITIVITY_CD 검증
-- =====================================================================
SELECT c.COLUMN_ID, c.TABLE_ID, c.COLUMN_NAME, c.SENSITIVITY_CD
  FROM TB_META_COLUMN c
 WHERE NOT EXISTS (
       SELECT 1 FROM TB_META_CODE m
        WHERE m.CODE_GROUP='CD_SENSITIVITY' AND m.CODE_VALUE = c.SENSITIVITY_CD
   )
;

-- =====================================================================
-- §5.5 컬럼 코드값 무결성 검증
-- =====================================================================
SELECT c.COLUMN_ID, c.COLUMN_NAME,
       '잘못된 STATUS_CD: '||c.STATUS_CD AS issue
  FROM TB_META_COLUMN c
 WHERE NOT EXISTS (
       SELECT 1 FROM TB_META_CODE m
        WHERE m.CODE_GROUP='CD_STATUS' AND m.CODE_VALUE = c.STATUS_CD
   )
UNION ALL
SELECT c.COLUMN_ID, c.COLUMN_NAME,
       '잘못된 PCI_CATEGORY_CD: '||c.PCI_CATEGORY_CD
  FROM TB_META_COLUMN c
 WHERE c.PCI_CATEGORY_CD IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM TB_META_CODE m
        WHERE m.CODE_GROUP='CD_PCI_CATEGORY' AND m.CODE_VALUE = c.PCI_CATEGORY_CD
   )
UNION ALL
SELECT c.COLUMN_ID, c.COLUMN_NAME,
       '잘못된 MASKING_RULE_CD: '||c.MASKING_RULE_CD
  FROM TB_META_COLUMN c
 WHERE c.MASKING_RULE_CD IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM TB_META_CODE m
        WHERE m.CODE_GROUP='CD_MASKING_RULE' AND m.CODE_VALUE = c.MASKING_RULE_CD
   )
;

-- =====================================================================
-- §5.6 인덱스/시퀀스 코드값 무결성
-- =====================================================================
SELECT i.INDEX_ID, i.INDEX_NAME,
       '잘못된 INDEX_TYPE_CD: '||i.INDEX_TYPE_CD AS issue
  FROM TB_META_INDEX i
 WHERE NOT EXISTS (
       SELECT 1 FROM TB_META_CODE m
        WHERE m.CODE_GROUP='CD_INDEX_TYPE' AND m.CODE_VALUE = i.INDEX_TYPE_CD
   )
UNION ALL
SELECT i.INDEX_ID, i.INDEX_NAME,
       '잘못된 PURPOSE_CD: '||i.PURPOSE_CD
  FROM TB_META_INDEX i
 WHERE NOT EXISTS (
       SELECT 1 FROM TB_META_CODE m
        WHERE m.CODE_GROUP='CD_INDEX_PURPOSE' AND m.CODE_VALUE = i.PURPOSE_CD
   )
UNION ALL
SELECT s.SEQUENCE_ID, s.SEQUENCE_NAME,
       '잘못된 PURPOSE_CD: '||s.PURPOSE_CD
  FROM TB_META_SEQUENCE s
 WHERE NOT EXISTS (
       SELECT 1 FROM TB_META_CODE m
        WHERE m.CODE_GROUP='CD_SEQUENCE_PURPOSE' AND m.CODE_VALUE = s.PURPOSE_CD
   )
;

-- =====================================================================
-- §5.7 동시 실행 / Lock 충돌 진단 (운영 중 트러블슈팅)
--   PG: pg_stat_activity + pg_locks + pg_class
-- =====================================================================
SELECT a.pid,
       a.usename                AS username,
       a.state,
       l.locktype               AS lock_type,
       l.mode                   AS lock_mode,
       c.relname                AS object_name
  FROM pg_stat_activity a
  JOIN pg_locks         l ON a.pid = l.pid
  JOIN pg_class         c ON l.relation = c.oid
 WHERE UPPER(c.relname) LIKE 'TB_META_%'
;
