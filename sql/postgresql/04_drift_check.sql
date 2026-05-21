-- =====================================================================
-- 04_drift_check.sql — 메타 ↔ 실제 DB Drift 감지 쿼리 (PostgreSQL 14+)
-- 실행 위치: 초기 적재(03) 완료 후, 일 1회 배치 권장
-- 선행: 01/02/03 적재 완료
-- 출처: DB_메타정보_관리체계_표준설계.md §8 (8.1~8.3)
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../04_drift_check.sql 참조)
--
-- 사전 수정 필요:
--   - WHERE UPPER(...) IN ('SVC1','SVC2', ...) 의 스키마 목록을 실제
--     대상 스키마(대문자)로 교체.
--
-- 매핑: ALL_TABLES → information_schema.tables (BASE TABLE),
--       ALL_VIEWS → information_schema.views,
--       ALL_TAB_COLUMNS → information_schema.columns,
--       NVL → COALESCE, NVL2 → CASE.
--       IOT/BIN$/NESTED/TEMPORARY 필터는 PG에 해당 개념 없으므로 제거.
-- =====================================================================

-- =====================================================================
-- §8.1 메타에 없지만 실제 DB에는 있는 객체 (Drift: META 누락)
-- =====================================================================
SELECT UPPER(t.table_schema) AS schema_name,
       UPPER(t.table_name)   AS table_name,
       'N' AS VIEW_YN
FROM information_schema.tables t
LEFT JOIN TB_META_TABLE mt
       ON mt.SCHEMA_NAME = UPPER(t.table_schema)
      AND mt.TABLE_NAME  = UPPER(t.table_name)
WHERE UPPER(t.table_schema) IN ('SVC1','SVC2'/* 대상 스키마 목록 */)
  AND t.table_type = 'BASE TABLE'
  AND mt.TABLE_ID IS NULL
  AND UPPER(t.table_name) NOT LIKE 'TB_META_%'
UNION ALL
SELECT UPPER(v.table_schema),
       UPPER(v.table_name),
       'Y'
FROM information_schema.views v
LEFT JOIN TB_META_TABLE mt
       ON mt.SCHEMA_NAME = UPPER(v.table_schema)
      AND mt.TABLE_NAME  = UPPER(v.table_name)
WHERE UPPER(v.table_schema) IN ('SVC1','SVC2'/* 대상 스키마 목록 */)
  AND mt.TABLE_ID IS NULL
  AND UPPER(v.table_name) NOT LIKE 'TB_META_%'
;

-- =====================================================================
-- §8.2 메타에는 ACTIVE인데 실제 DB에는 없는 객체 (Drift: 실제 누락)
-- =====================================================================
SELECT mt.SCHEMA_NAME, mt.TABLE_NAME, mt.VIEW_YN
FROM TB_META_TABLE mt
LEFT JOIN information_schema.tables t
       ON mt.VIEW_YN = 'N'
      AND UPPER(t.table_schema) = mt.SCHEMA_NAME
      AND UPPER(t.table_name)   = mt.TABLE_NAME
      AND t.table_type = 'BASE TABLE'
LEFT JOIN information_schema.views v
       ON mt.VIEW_YN = 'Y'
      AND UPPER(v.table_schema) = mt.SCHEMA_NAME
      AND UPPER(v.table_name)   = mt.TABLE_NAME
WHERE mt.STATUS_CD = 'ACTIVE'
  AND t.table_name IS NULL
  AND v.table_name IS NULL
;

-- =====================================================================
-- §8.3 컬럼 정의 불일치 (양방향)
--   PG는 numeric(p,s)의 정밀도/스케일을 information_schema.columns의
--   numeric_precision/numeric_scale 로 반환, 문자형은 character_maximum_length
--   로 반환. NULLABLE은 is_nullable ('YES'/'NO').
-- =====================================================================
-- (a) 메타에 있는 컬럼 vs 실제: 정의 불일치 또는 실제 누락
SELECT mt.SCHEMA_NAME, mt.TABLE_NAME, mc.COLUMN_NAME,
       mc.DATA_TYPE                                          AS meta_type,
       UPPER(tc.data_type)                                   AS real_type,
       mc.DATA_LENGTH                                        AS meta_len,
       COALESCE(tc.character_maximum_length, tc.numeric_precision) AS real_len,
       mc.DATA_PRECISION                                     AS meta_prec,
       tc.numeric_precision                                  AS real_prec,
       mc.DATA_SCALE                                         AS meta_scale,
       tc.numeric_scale                                      AS real_scale,
       mc.NULLABLE_YN                                        AS meta_null,
       CASE tc.is_nullable WHEN 'YES' THEN 'Y' ELSE 'N' END  AS real_null,
       CASE WHEN tc.column_name IS NULL THEN 'MISSING_IN_DB' ELSE 'MISMATCH' END AS diff_kind
FROM TB_META_COLUMN mc
JOIN TB_META_TABLE  mt ON mt.TABLE_ID = mc.TABLE_ID
LEFT JOIN information_schema.columns tc
       ON UPPER(tc.table_schema) = mt.SCHEMA_NAME
      AND UPPER(tc.table_name)   = mt.TABLE_NAME
      AND UPPER(tc.column_name)  = mc.COLUMN_NAME
WHERE mt.STATUS_CD = 'ACTIVE'
  AND mc.STATUS_CD = 'ACTIVE'
  AND (
        tc.column_name IS NULL
     OR mc.DATA_TYPE   <> UPPER(tc.data_type)
     OR COALESCE(mc.DATA_LENGTH, 0)    <> COALESCE(tc.character_maximum_length, tc.numeric_precision, 0)
     OR COALESCE(mc.DATA_PRECISION,-1) <> COALESCE(tc.numeric_precision,-1)
     OR COALESCE(mc.DATA_SCALE,-1)     <> COALESCE(tc.numeric_scale,-1)
     OR mc.NULLABLE_YN <> CASE tc.is_nullable WHEN 'YES' THEN 'Y' ELSE 'N' END
  )
UNION ALL
-- (b) 실제에는 있는데 메타에 없음
SELECT UPPER(tc.table_schema), UPPER(tc.table_name), UPPER(tc.column_name),
       NULL, UPPER(tc.data_type),
       NULL, COALESCE(tc.character_maximum_length, tc.numeric_precision),
       NULL, tc.numeric_precision,
       NULL, tc.numeric_scale,
       NULL, CASE tc.is_nullable WHEN 'YES' THEN 'Y' ELSE 'N' END,
       'MISSING_IN_META'
FROM information_schema.columns tc
JOIN TB_META_TABLE  mt
  ON mt.SCHEMA_NAME = UPPER(tc.table_schema) AND mt.TABLE_NAME = UPPER(tc.table_name)
LEFT JOIN TB_META_COLUMN mc
       ON mc.TABLE_ID    = mt.TABLE_ID
      AND mc.COLUMN_NAME = UPPER(tc.column_name)
WHERE mt.STATUS_CD = 'ACTIVE'
  AND mc.COLUMN_ID IS NULL
;

-- 참고: Oracle의 CHAR 시맨틱(CHAR_USED='C')은 PG에 해당 개념이 없으므로 비교 대상 아님.
