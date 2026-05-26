-- =====================================================================
-- 02_common_code.sql — 공통코드(TB_META_CODE) 초기 적재
-- 실행 순서: 2 / 3
-- 선행: 01_meta_ddl.sql
-- 후행: 03_initial_load.sql
-- 출처: DB_메타정보_관리체계_표준설계.md §6.9
-- 주의: CD_SERVICE는 UNASSIGNED 더미 1건만 적재하며 실제 서비스 코드는 별도 적재
-- 재실행 안전성: 모든 코드 INSERT는 NOT EXISTS 가드, HIST INSERT는
--                ('I','INITIAL_LOAD') 중복 가드로 누적/충돌을 방지한다.
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../02_common_code.sql 참조)
-- 매핑: FROM DUAL 제거, SEQ_META_HIST_ID.NEXTVAL → nextval('seq_meta_hist_id'),
--       SYSTIMESTAMP → CURRENT_TIMESTAMP
-- =====================================================================

-- CD_RETENTION_PERIOD
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_RETENTION_PERIOD','Y1','1년','1년',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_RETENTION_PERIOD' AND code_value='Y1');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_RETENTION_PERIOD','Y3','3년','3년',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_RETENTION_PERIOD' AND code_value='Y3');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_RETENTION_PERIOD','Y5','5년','5년',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_RETENTION_PERIOD' AND code_value='Y5');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_RETENTION_PERIOD','Y10','10년','10년',4,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_RETENTION_PERIOD' AND code_value='Y10');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_RETENTION_PERIOD','Y30','30년','30년',5,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_RETENTION_PERIOD' AND code_value='Y30');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_RETENTION_PERIOD','PERM','영구','영구',6,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_RETENTION_PERIOD' AND code_value='PERM');

-- CD_PCI_CATEGORY (신용정보법 시행령 분류)
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_PCI_CATEGORY','IDENT','식별정보','식별정보 (신용정보법 시행령 분류)',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_PCI_CATEGORY' AND code_value='IDENT');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_PCI_CATEGORY','TRX','신용거래','신용거래 (신용정보법 시행령 분류)',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_PCI_CATEGORY' AND code_value='TRX');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_PCI_CATEGORY','SCORE','신용도','신용도 (신용정보법 시행령 분류)',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_PCI_CATEGORY' AND code_value='SCORE');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_PCI_CATEGORY','ABILITY','신용능력','신용능력 (신용정보법 시행령 분류)',4,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_PCI_CATEGORY' AND code_value='ABILITY');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_PCI_CATEGORY','PUBLIC','공공정보','공공정보 (신용정보법 시행령 분류)',5,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_PCI_CATEGORY' AND code_value='PUBLIC');

-- CD_SENSITIVITY (TB_META_COLUMN.SENSITIVITY_CD 매핑)
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_SENSITIVITY','HIGH','상','민감도 상',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_SENSITIVITY' AND code_value='HIGH');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_SENSITIVITY','MID','중','민감도 중',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_SENSITIVITY' AND code_value='MID');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_SENSITIVITY','LOW','하','민감도 하 (DEFAULT)',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_SENSITIVITY' AND code_value='LOW');

-- CD_ISOLATION_LEVEL
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_ISOLATION_LEVEL','L1','운영망','운영망',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_ISOLATION_LEVEL' AND code_value='L1');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_ISOLATION_LEVEL','L2','준격리','준격리',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_ISOLATION_LEVEL' AND code_value='L2');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_ISOLATION_LEVEL','L3','완전격리','완전격리',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_ISOLATION_LEVEL' AND code_value='L3');

-- CD_STATUS
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_STATUS','PLANNED','계획','계획',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_STATUS' AND code_value='PLANNED');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_STATUS','ACTIVE','운영중','운영중',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_STATUS' AND code_value='ACTIVE');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_STATUS','DEPRECATED','폐기예정','폐기예정',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_STATUS' AND code_value='DEPRECATED');

-- CD_INDEX_TYPE
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_TYPE','NORMAL','NORMAL','일반 인덱스',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_TYPE' AND code_value='NORMAL');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_TYPE','UNIQUE','UNIQUE','고유 인덱스',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_TYPE' AND code_value='UNIQUE');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_TYPE','BITMAP','BITMAP','비트맵 인덱스',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_TYPE' AND code_value='BITMAP');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_TYPE','FUNCTION','FUNCTION','함수기반 인덱스',4,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_TYPE' AND code_value='FUNCTION');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_TYPE','REVERSE','REVERSE','리버스키 인덱스',5,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_TYPE' AND code_value='REVERSE');

-- CD_INDEX_PURPOSE
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_PURPOSE','PK','PK','기본키',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_PURPOSE' AND code_value='PK');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_PURPOSE','FK','FK','외래키',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_PURPOSE' AND code_value='FK');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_PURPOSE','SEARCH','SEARCH','조회',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_PURPOSE' AND code_value='SEARCH');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_PURPOSE','JOIN','JOIN','조인',4,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_PURPOSE' AND code_value='JOIN');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_PURPOSE','TUNING','TUNING','튜닝',5,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_PURPOSE' AND code_value='TUNING');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_INDEX_PURPOSE','SORT','SORT','정렬',6,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_INDEX_PURPOSE' AND code_value='SORT');

-- CD_SEQUENCE_PURPOSE
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_SEQUENCE_PURPOSE','PK','PK','기본키 채번',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_SEQUENCE_PURPOSE' AND code_value='PK');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_SEQUENCE_PURPOSE','BIZ_KEY','BIZ_KEY','업무키 채번',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_SEQUENCE_PURPOSE' AND code_value='BIZ_KEY');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_SEQUENCE_PURPOSE','TEMP','TEMP','임시 채번',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_SEQUENCE_PURPOSE' AND code_value='TEMP');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_SEQUENCE_PURPOSE','ETC','ETC','기타',4,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_SEQUENCE_PURPOSE' AND code_value='ETC');

-- CD_MASKING_RULE
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_MASKING_RULE','NAME','이름','이름',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_MASKING_RULE' AND code_value='NAME');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_MASKING_RULE','RRN','주민번호','주민번호',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_MASKING_RULE' AND code_value='RRN');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_MASKING_RULE','PHONE','전화번호','전화번호',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_MASKING_RULE' AND code_value='PHONE');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_MASKING_RULE','CARD','카드번호','카드번호',4,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_MASKING_RULE' AND code_value='CARD');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_MASKING_RULE','EMAIL','이메일','이메일',5,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_MASKING_RULE' AND code_value='EMAIL');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_MASKING_RULE','ADDR','주소','주소',6,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_MASKING_RULE' AND code_value='ADDR');
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_MASKING_RULE','FULL','전체마스킹','전체마스킹',7,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_MASKING_RULE' AND code_value='FULL');

-- CD_SERVICE: §7.1 호환을 위한 UNASSIGNED 더미 1건만 적재
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_SERVICE','UNASSIGNED','미지정','초기 적재용 미지정 서비스(담당자 매핑 후 교체)',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_SERVICE' AND code_value='UNASSIGNED');

-- TB_META_CODE_HIST 동시 적재: ('I','INITIAL_LOAD') 미존재 행만
INSERT INTO tb_meta_code_hist (
    hist_id, hist_type, hist_at, hist_by, change_reason,
    code_group, code_value, code_name, description,
    sort_order, use_yn,
    created_by, created_at, updated_by, updated_at
)
SELECT
    nextval('seq_meta_hist_id'), 'I', CURRENT_TIMESTAMP, USER, 'INITIAL_LOAD',
    c.code_group, c.code_value, c.code_name, c.description,
    c.sort_order, c.use_yn,
    c.created_by, c.created_at, c.updated_by, c.updated_at
FROM tb_meta_code c
WHERE NOT EXISTS (
    SELECT 1 FROM tb_meta_code_hist h
     WHERE h.code_group    = c.code_group
       AND h.code_value    = c.code_value
       AND h.hist_type     = 'I'
       AND h.change_reason = 'INITIAL_LOAD'
)
;

COMMIT;
