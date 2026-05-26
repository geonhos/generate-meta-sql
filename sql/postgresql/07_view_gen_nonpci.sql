-- =====================================================================
-- 07_view_gen_nonpci.sql — 비-PCI 컬럼만 노출하는 VIEW DDL 자동 생성 (PostgreSQL 14+)
-- 실행 위치: 03 적재 또는 운영 메타 갱신 이후 임의 시점
-- 선행: 01/02/03 적재 완료 (TB_META_TABLE, TB_META_COLUMN ACTIVE 상태)
-- 출처: DB_메타정보_관리체계_표준설계.md §4.1/§4.2 (VIEW_YN, PCI_YN)
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../07_view_gen_nonpci.sql 참조)
-- 매핑: LISTAGG(c, ',') WITHIN GROUP (ORDER BY o) → STRING_AGG(c, ',' ORDER BY o)
--       LENGTHB → octet_length
-- 정책:
--   - 대상: TB_META_TABLE.VIEW_YN='Y' AND STATUS_CD='ACTIVE'
--   - 노출 컬럼: TB_META_COLUMN.PCI_YN='N' AND STATUS_CD='ACTIVE'
-- =====================================================================

-- ---------------------------------------------------------------------
-- (1) 본 쿼리 — 비-PCI VIEW DDL 생성
--   VIEW 이름 규칙: VW_<원본명>
--   PostgreSQL: text 컬럼은 1GB까지 가능하므로 LISTAGG 4000자 제약 없음.
--   다만 식별자 자체는 NAMEDATALEN(기본 64byte) 한도 있음 — (3) 점검.
-- ---------------------------------------------------------------------
SELECT 'CREATE OR REPLACE VIEW ' || mt.schema_name || '.VW_' || mt.table_name || ' AS SELECT '
       || string_agg(mc.column_name, ', ' ORDER BY mc.column_order)
       || ' FROM ' || mt.schema_name || '.' || mt.table_name || ';' AS ddl
FROM tb_meta_table  mt
JOIN tb_meta_column mc ON mc.table_id = mt.table_id
WHERE mt.view_yn   = 'Y'
  AND mt.status_cd = 'ACTIVE'
  AND mc.status_cd = 'ACTIVE'
  AND mc.pci_yn    = 'N'
GROUP BY mt.schema_name, mt.table_name
ORDER BY mt.schema_name, mt.table_name
;

-- ---------------------------------------------------------------------
-- (2) 점검 — 비-PCI 컬럼이 0개라 생성에서 제외된 VIEW
-- ---------------------------------------------------------------------
SELECT mt.schema_name, mt.table_name,
       COUNT(*)                                         AS total_col,
       SUM(CASE WHEN mc.pci_yn = 'N' THEN 1 ELSE 0 END) AS non_pci_col,
       SUM(CASE WHEN mc.pci_yn = 'Y' THEN 1 ELSE 0 END) AS pci_col
FROM tb_meta_table  mt
JOIN tb_meta_column mc ON mc.table_id = mt.table_id
WHERE mt.view_yn   = 'Y'
  AND mt.status_cd = 'ACTIVE'
  AND mc.status_cd = 'ACTIVE'
GROUP BY mt.schema_name, mt.table_name
HAVING SUM(CASE WHEN mc.pci_yn = 'N' THEN 1 ELSE 0 END) = 0
ORDER BY mt.schema_name, mt.table_name
;

-- ---------------------------------------------------------------------
-- (3) 점검 — 'VW_' prefix 추가 시 PostgreSQL 식별자 한도(NAMEDATALEN=64byte) 초과 후보
--   (운영 DB의 NAMEDATALEN을 늘려 컴파일했다면 별도 조정 필요)
-- ---------------------------------------------------------------------
SELECT mt.schema_name, mt.table_name,
       octet_length(mt.table_name) + 3 AS gen_name_bytes
FROM tb_meta_table mt
WHERE mt.view_yn   = 'Y'
  AND mt.status_cd = 'ACTIVE'
  AND octet_length(mt.table_name) + 3 > 64
ORDER BY gen_name_bytes DESC
;
