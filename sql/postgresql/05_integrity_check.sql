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
SELECT code_group, COUNT(*) AS cnt
  FROM tb_meta_code
 GROUP BY code_group
 ORDER BY code_group;

-- =====================================================================
-- §5.2 본 ↔ HIST 행수 일치 검증
-- =====================================================================
SELECT 'TABLE'    AS src,
       (SELECT COUNT(*) FROM tb_meta_table)             AS main,
       (SELECT COUNT(*) FROM tb_meta_table_hist
         WHERE hist_type='I' AND change_reason='INITIAL_LOAD') AS hist
UNION ALL
SELECT 'COLUMN',
       (SELECT COUNT(*) FROM tb_meta_column),
       (SELECT COUNT(*) FROM tb_meta_column_hist
         WHERE hist_type='I' AND change_reason='INITIAL_LOAD')
UNION ALL
SELECT 'INDEX',
       (SELECT COUNT(*) FROM tb_meta_index),
       (SELECT COUNT(*) FROM tb_meta_index_hist
         WHERE hist_type='I' AND change_reason='INITIAL_LOAD')
UNION ALL
SELECT 'INDEX_COL',
       (SELECT COUNT(*) FROM tb_meta_index_column),
       (SELECT COUNT(*) FROM tb_meta_index_column_hist
         WHERE hist_type='I' AND change_reason='INITIAL_LOAD')
UNION ALL
SELECT 'SEQUENCE',
       (SELECT COUNT(*) FROM tb_meta_sequence),
       (SELECT COUNT(*) FROM tb_meta_sequence_hist
         WHERE hist_type='I' AND change_reason='INITIAL_LOAD')
UNION ALL
SELECT 'CODE',
       (SELECT COUNT(*) FROM tb_meta_code),
       (SELECT COUNT(*) FROM tb_meta_code_hist
         WHERE hist_type='I' AND change_reason='INITIAL_LOAD')
;

-- =====================================================================
-- §5.3 코드값 무결성 검증 (참조 정합성)
-- =====================================================================
SELECT t.table_id, t.schema_name, t.table_name,
       '잘못된 SERVICE_CD: '||t.service_cd AS issue
  FROM tb_meta_table t
 WHERE NOT EXISTS (
       SELECT 1 FROM tb_meta_code c
        WHERE c.code_group='CD_SERVICE' AND c.code_value = t.service_cd
   )
UNION ALL
SELECT t.table_id, t.schema_name, t.table_name,
       '잘못된 RETENTION_PERIOD_CD: '||t.retention_period_cd
  FROM tb_meta_table t
 WHERE NOT EXISTS (
       SELECT 1 FROM tb_meta_code c
        WHERE c.code_group='CD_RETENTION_PERIOD' AND c.code_value = t.retention_period_cd
   )
UNION ALL
SELECT t.table_id, t.schema_name, t.table_name,
       '잘못된 STATUS_CD: '||t.status_cd
  FROM tb_meta_table t
 WHERE NOT EXISTS (
       SELECT 1 FROM tb_meta_code c
        WHERE c.code_group='CD_STATUS' AND c.code_value = t.status_cd
   )
;

-- =====================================================================
-- §5.4 SENSITIVITY_CD 검증
-- =====================================================================
SELECT c.column_id, c.table_id, c.column_name, c.sensitivity_cd
  FROM tb_meta_column c
 WHERE NOT EXISTS (
       SELECT 1 FROM tb_meta_code m
        WHERE m.code_group='CD_SENSITIVITY' AND m.code_value = c.sensitivity_cd
   )
;

-- =====================================================================
-- §5.5 컬럼 코드값 무결성 검증
-- =====================================================================
SELECT c.column_id, c.column_name,
       '잘못된 STATUS_CD: '||c.status_cd AS issue
  FROM tb_meta_column c
 WHERE NOT EXISTS (
       SELECT 1 FROM tb_meta_code m
        WHERE m.code_group='CD_STATUS' AND m.code_value = c.status_cd
   )
UNION ALL
SELECT c.column_id, c.column_name,
       '잘못된 PCI_CATEGORY_CD: '||c.pci_category_cd
  FROM tb_meta_column c
 WHERE c.pci_category_cd IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM tb_meta_code m
        WHERE m.code_group='CD_PCI_CATEGORY' AND m.code_value = c.pci_category_cd
   )
UNION ALL
SELECT c.column_id, c.column_name,
       '잘못된 MASKING_RULE_CD: '||c.masking_rule_cd
  FROM tb_meta_column c
 WHERE c.masking_rule_cd IS NOT NULL
   AND NOT EXISTS (
       SELECT 1 FROM tb_meta_code m
        WHERE m.code_group='CD_MASKING_RULE' AND m.code_value = c.masking_rule_cd
   )
;

-- =====================================================================
-- §5.6 인덱스/시퀀스 코드값 무결성
-- =====================================================================
SELECT i.index_id, i.index_name,
       '잘못된 INDEX_TYPE_CD: '||i.index_type_cd AS issue
  FROM tb_meta_index i
 WHERE NOT EXISTS (
       SELECT 1 FROM tb_meta_code m
        WHERE m.code_group='CD_INDEX_TYPE' AND m.code_value = i.index_type_cd
   )
UNION ALL
SELECT i.index_id, i.index_name,
       '잘못된 PURPOSE_CD: '||i.purpose_cd
  FROM tb_meta_index i
 WHERE NOT EXISTS (
       SELECT 1 FROM tb_meta_code m
        WHERE m.code_group='CD_INDEX_PURPOSE' AND m.code_value = i.purpose_cd
   )
UNION ALL
SELECT s.sequence_id, s.sequence_name,
       '잘못된 PURPOSE_CD: '||s.purpose_cd
  FROM tb_meta_sequence s
 WHERE NOT EXISTS (
       SELECT 1 FROM tb_meta_code m
        WHERE m.code_group='CD_SEQUENCE_PURPOSE' AND m.code_value = s.purpose_cd
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
 WHERE c.relname LIKE 'tb_meta_%'
;
