-- =====================================================================
-- 99_rollback.sql — 메타 스키마 전체 폐기 (긴급 롤백) — PostgreSQL 14+
-- ⚠️ ⚠️ ⚠️ 신중 실행 — 모든 메타 데이터/이력 영구 삭제 ⚠️ ⚠️ ⚠️
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../99_rollback.sql 참조)
-- 매핑: PURGE 키워드 제거(PG는 휴지통 없음).
--       모든 DROP 은 즉시 적용. (Oracle처럼 휴지통에서 복구 불가)
--
-- 사전 점검:
--   1) 본 작업이 의도된 것인지 운영 책임자 승인 확인
--   2) 필요 시 백업 (CREATE TABLE BAK_TB_META_xxx_<DATE> AS SELECT * FROM ...)
--   3) 메타 테이블을 참조하는 외부 시스템/리포트가 있는지 확인
-- 정책: SQL DDL만 사용.
-- =====================================================================

-- ---------------------------------------------------------------------
-- §99.1 FK 제약 제거 (DROP TABLE 순서 의존 해소)
-- ---------------------------------------------------------------------
ALTER TABLE tb_meta_index_column DROP CONSTRAINT fk_meta_index_column;
ALTER TABLE tb_meta_index        DROP CONSTRAINT fk_meta_index_table;
ALTER TABLE tb_meta_column       DROP CONSTRAINT fk_meta_column_table;

-- ---------------------------------------------------------------------
-- §99.2 HIST 테이블 폐기
-- ---------------------------------------------------------------------
DROP TABLE tb_meta_index_column_hist;
DROP TABLE tb_meta_index_hist;
DROP TABLE tb_meta_column_hist;
DROP TABLE tb_meta_table_hist;
DROP TABLE tb_meta_sequence_hist;
DROP TABLE tb_meta_code_hist;

-- ---------------------------------------------------------------------
-- §99.3 본 테이블 폐기
-- ---------------------------------------------------------------------
DROP TABLE tb_meta_index_column;
DROP TABLE tb_meta_index;
DROP TABLE tb_meta_column;
DROP TABLE tb_meta_sequence;
DROP TABLE tb_meta_table;
DROP TABLE tb_meta_code;

-- ---------------------------------------------------------------------
-- §99.4 시퀀스 폐기
-- ---------------------------------------------------------------------
DROP SEQUENCE seq_meta_hist_id;
DROP SEQUENCE seq_meta_sequence_id;
DROP SEQUENCE seq_meta_index_id;
DROP SEQUENCE seq_meta_column_id;
DROP SEQUENCE seq_meta_table_id;

-- ---------------------------------------------------------------------
-- §99.5 검증 (실행 후 - 결과 0건이어야 함)
-- ---------------------------------------------------------------------
-- SELECT table_name FROM information_schema.tables
--  WHERE UPPER(table_name) LIKE 'tb_meta_%';
-- SELECT sequencename FROM pg_sequences
--  WHERE UPPER(sequencename) LIKE 'seq_meta_%';
