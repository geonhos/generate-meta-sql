-- =====================================================================
-- 02a_cd_tos_template.sql — 사내 CD_TOS 코드그룹 적재 템플릿
-- 실행 순서: 2.5 / 3 (02 직후, 03 이전 — 사내 약관 사용 시 필수)
-- 선행: 02_common_code.sql
-- 후행: 03_initial_load.sql
-- 출처: 표준설계서 §5 (CD_TOS는 "사내 이용약관 체계에 맞게 적재"로 위임)
-- 사전 수정 필요: 아래 INSERT 행을 사내 실제 약관 코드로 교체
-- 정책: SQL DDL/DML만 사용. 02_common_code.sql과 동일한 NOT EXISTS 가드 +
--       TB_META_CODE_HIST 동시 적재 패턴 준수.
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../02a_cd_tos_template.sql 참조)
-- 매핑: FROM DUAL 제거, SEQ_META_HIST_ID.NEXTVAL → nextval('seq_meta_hist_id'),
--       SYSTIMESTAMP → CURRENT_TIMESTAMP
-- =====================================================================

-- ---------------------------------------------------------------------
-- CD_TOS 코드 적재 (예시 — 실제 약관 체계로 교체)
-- ---------------------------------------------------------------------
INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_TOS','TOS001','일반회원약관','일반 회원 가입 약관',1,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_TOS' AND code_value='TOS001');

INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_TOS','TOS002','마케팅수신약관','마케팅 정보 수신 동의 약관',2,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_TOS' AND code_value='TOS002');

INSERT INTO tb_meta_code(code_group, code_value, code_name, description, sort_order, created_by, updated_by)
SELECT 'CD_TOS','TOS003','3자정보제공약관','제3자 정보 제공 동의 약관',3,'INITIAL_LOAD','INITIAL_LOAD'
WHERE NOT EXISTS (SELECT 1 FROM tb_meta_code WHERE code_group='CD_TOS' AND code_value='TOS003');

-- ↑ 사내 실제 약관 코드만큼 INSERT 블록을 추가/교체할 것

-- ---------------------------------------------------------------------
-- TB_META_CODE_HIST 동시 적재 ('I'/'INITIAL_LOAD' 중복 가드)
-- ---------------------------------------------------------------------
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
WHERE c.code_group = 'CD_TOS'
  AND NOT EXISTS (
    SELECT 1 FROM tb_meta_code_hist h
     WHERE h.code_group    = c.code_group
       AND h.code_value    = c.code_value
       AND h.hist_type     = 'I'
       AND h.change_reason = 'INITIAL_LOAD'
);

COMMIT;

-- 검증 (선택): 본↔HIST 행수 일치 확인
-- SELECT (SELECT COUNT(*) FROM TB_META_CODE      WHERE CODE_GROUP='CD_TOS') AS code_cnt,
--        (SELECT COUNT(*) FROM TB_META_CODE_HIST WHERE CODE_GROUP='CD_TOS' AND HIST_TYPE='I') AS hist_cnt;
