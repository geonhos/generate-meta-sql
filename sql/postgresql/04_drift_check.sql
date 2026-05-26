-- =====================================================================
-- 04_drift_check.sql — 메타 ↔ 실제 DB Drift 감지 쿼리 (PostgreSQL 14+)
-- 실행 위치: 초기 적재(03) 완료 후, 일 1회 배치 권장
-- 선행: 01/02/03 적재 완료
-- 출처: DB_메타정보_관리체계_표준설계.md §8 (8.1~8.3)
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../04_drift_check.sql 참조)
--
-- 사전 수정 필요:
--   - WHERE t.table_schema IN ('svc1','svc2', ...) 의 스키마 목록을 실제
--     대상 스키마(소문자)로 교체.
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
SELECT t.table_schema AS schema_name,
       t.table_name   AS table_name,
       'N' AS view_yn
FROM information_schema.tables t
LEFT JOIN tb_meta_table mt
       ON mt.schema_name = t.table_schema
      AND mt.table_name  = t.table_name
WHERE t.table_schema IN ('svc1','svc2'/* 대상 스키마 목록 */)
  AND t.table_type = 'BASE TABLE'
  AND mt.table_id IS NULL
  AND t.table_name NOT LIKE 'tb_meta_%'
UNION ALL
SELECT v.table_schema,
       v.table_name,
       'Y'
FROM information_schema.views v
LEFT JOIN tb_meta_table mt
       ON mt.schema_name = v.table_schema
      AND mt.table_name  = v.table_name
WHERE v.table_schema IN ('svc1','svc2'/* 대상 스키마 목록 */)
  AND mt.table_id IS NULL
  AND v.table_name NOT LIKE 'tb_meta_%'
;

-- =====================================================================
-- §8.2 메타에는 ACTIVE인데 실제 DB에는 없는 객체 (Drift: 실제 누락)
-- =====================================================================
SELECT mt.schema_name, mt.table_name, mt.view_yn
FROM tb_meta_table mt
LEFT JOIN information_schema.tables t
       ON mt.view_yn = 'N'
      AND t.table_schema = mt.schema_name
      AND t.table_name   = mt.table_name
      AND t.table_type = 'BASE TABLE'
LEFT JOIN information_schema.views v
       ON mt.view_yn = 'Y'
      AND v.table_schema = mt.schema_name
      AND v.table_name   = mt.table_name
WHERE mt.status_cd = 'ACTIVE'
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
SELECT mt.schema_name, mt.table_name, mc.column_name,
       mc.data_type                                          AS meta_type,
       tc.data_type                                   AS real_type,
       mc.data_length                                        AS meta_len,
       COALESCE(tc.character_maximum_length, tc.numeric_precision) AS real_len,
       mc.data_precision                                     AS meta_prec,
       tc.numeric_precision                                  AS real_prec,
       mc.data_scale                                         AS meta_scale,
       tc.numeric_scale                                      AS real_scale,
       mc.nullable_yn                                        AS meta_null,
       CASE tc.is_nullable WHEN 'YES' THEN 'Y' ELSE 'N' END  AS real_null,
       CASE WHEN tc.column_name IS NULL THEN 'MISSING_IN_DB' ELSE 'MISMATCH' END AS diff_kind
FROM tb_meta_column mc
JOIN tb_meta_table  mt ON mt.table_id = mc.table_id
LEFT JOIN information_schema.columns tc
       ON tc.table_schema = mt.schema_name
      AND tc.table_name   = mt.table_name
      AND tc.column_name  = mc.column_name
WHERE mt.status_cd = 'ACTIVE'
  AND mc.status_cd = 'ACTIVE'
  AND (
        tc.column_name IS NULL
     OR mc.data_type   <> tc.data_type
     OR COALESCE(mc.data_length, 0)    <> COALESCE(tc.character_maximum_length, tc.numeric_precision, 0)
     OR COALESCE(mc.data_precision,-1) <> COALESCE(tc.numeric_precision,-1)
     OR COALESCE(mc.data_scale,-1)     <> COALESCE(tc.numeric_scale,-1)
     OR mc.nullable_yn <> CASE tc.is_nullable WHEN 'YES' THEN 'Y' ELSE 'N' END
  )
UNION ALL
-- (b) 실제에는 있는데 메타에 없음
SELECT tc.table_schema, tc.table_name, tc.column_name,
       NULL, tc.data_type,
       NULL, COALESCE(tc.character_maximum_length, tc.numeric_precision),
       NULL, tc.numeric_precision,
       NULL, tc.numeric_scale,
       NULL, CASE tc.is_nullable WHEN 'YES' THEN 'Y' ELSE 'N' END,
       'MISSING_IN_META'
FROM information_schema.columns tc
JOIN tb_meta_table  mt
  ON mt.schema_name = tc.table_schema AND mt.table_name = tc.table_name
LEFT JOIN tb_meta_column mc
       ON mc.table_id    = mt.table_id
      AND mc.column_name = tc.column_name
WHERE mt.status_cd = 'ACTIVE'
  AND mc.column_id IS NULL
;

-- 참고: Oracle의 CHAR 시맨틱(CHAR_USED='C')은 PG에 해당 개념이 없으므로 비교 대상 아님.
