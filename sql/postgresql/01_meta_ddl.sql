-- =====================================================================
-- 01_meta_ddl.sql — 메타 테이블/시퀀스/히스토리 DDL 일괄 생성 (PostgreSQL 14+)
-- 실행 순서: 1 / 3
-- 선행: (없음 — 대상 스키마 계정으로 접속)
-- 후행: 02_common_code.sql
-- 출처: DB_메타정보_관리체계_표준설계.md §6
-- 다이얼렉트: PostgreSQL (Oracle 원본은 ../01_meta_ddl.sql 참조)
-- 매핑: NUMBER → NUMERIC, VARCHAR2 → VARCHAR, CLOB → TEXT,
--       SYSTIMESTAMP → CURRENT_TIMESTAMP, NOCYCLE → NO CYCLE,
--       NOORDER 제거(미지원), TABLESPACE 제거
-- 식별자 정책: UPPERCASE unquoted — PostgreSQL이 자동으로 lowercase 폴딩.
--             (운영가이드.md PostgreSQL 섹션 참조)
-- =====================================================================

-- ---------------------------------------------------------------------
-- §6.1 시퀀스
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_meta_table_id    START WITH 1 INCREMENT BY 1 CACHE 100 NO CYCLE;
CREATE SEQUENCE seq_meta_column_id   START WITH 1 INCREMENT BY 1 CACHE 500 NO CYCLE;
CREATE SEQUENCE seq_meta_index_id    START WITH 1 INCREMENT BY 1 CACHE 100 NO CYCLE;
CREATE SEQUENCE seq_meta_sequence_id START WITH 1 INCREMENT BY 1 CACHE 100 NO CYCLE;

-- ---------------------------------------------------------------------
-- §6.2 TB_META_CODE
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_code (
    code_group    varchar(30)   NOT NULL,
    code_value    varchar(30)   NOT NULL,
    code_name     varchar(200)  NOT NULL,
    description   varchar(2000),
    sort_order    numeric(4),
    use_yn        char(1) DEFAULT 'Y' NOT NULL,
    created_by    varchar(128)  NOT NULL,
    created_at    timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by    varchar(128)  NOT NULL,
    updated_at    timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_meta_code PRIMARY KEY (code_group, code_value),
    CONSTRAINT ck_meta_code_use CHECK (use_yn IN ('Y','N'))
);

-- ---------------------------------------------------------------------
-- §6.3 TB_META_TABLE
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_table (
    table_id             numeric(12)   NOT NULL,
    schema_name          varchar(128)  NOT NULL,
    table_name           varchar(128)  NOT NULL,
    logical_name         varchar(200),
    description          varchar(2000),
    view_yn              char(1) DEFAULT 'N' NOT NULL,
    service_cd           varchar(20)   NOT NULL,
    owner_emp_id         varchar(20)   NOT NULL,
    secondary_emp_id     varchar(20),
    key_table_yn         char(1) DEFAULT 'N' NOT NULL,
    isolation_yn         char(1) DEFAULT 'N' NOT NULL,
    isolation_level_cd   varchar(10),
    pci_yn               char(1) DEFAULT 'N' NOT NULL,
    retention_period_cd  varchar(10)   NOT NULL,
    retention_basis      varchar(500),
    tos_cd               varchar(20),
    status_cd            varchar(10)   DEFAULT 'ACTIVE' NOT NULL,
    remark               varchar(4000),
    created_by           varchar(128)  NOT NULL,
    created_at           timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by           varchar(128)  NOT NULL,
    updated_at           timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_meta_table PRIMARY KEY (table_id),
    CONSTRAINT uk_meta_table UNIQUE (schema_name, table_name),
    CONSTRAINT ck_meta_table_yn CHECK (
        view_yn IN ('Y','N') AND key_table_yn IN ('Y','N')
        AND isolation_yn IN ('Y','N') AND pci_yn IN ('Y','N')
    )
);

CREATE INDEX idx_meta_table_01 ON tb_meta_table (service_cd, status_cd);
CREATE INDEX idx_meta_table_02 ON tb_meta_table (owner_emp_id);
CREATE INDEX idx_meta_table_03 ON tb_meta_table (pci_yn);

-- ---------------------------------------------------------------------
-- §6.4 TB_META_COLUMN
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_column (
    column_id              numeric(14)   NOT NULL,
    table_id               numeric(12)   NOT NULL,
    column_name            varchar(128)  NOT NULL,
    column_order           numeric(4)    NOT NULL,
    logical_name           varchar(200),
    description            varchar(2000),
    data_type              varchar(30)   NOT NULL,
    data_length            numeric(6),
    data_precision         numeric(6),
    data_scale             numeric(6),
    nullable_yn            char(1)       NOT NULL,
    default_value          varchar(500),
    pk_yn                  char(1) DEFAULT 'N' NOT NULL,
    uk_yn                  char(1) DEFAULT 'N' NOT NULL,
    fk_yn                  char(1) DEFAULT 'N' NOT NULL,
    pci_yn                 char(1) DEFAULT 'N' NOT NULL,
    pci_category_cd        varchar(20),
    sensitivity_cd         varchar(10)   DEFAULT 'LOW' NOT NULL,
    encryption_yn          char(1) DEFAULT 'N' NOT NULL,
    encryption_alg         varchar(50),
    masking_yn             char(1) DEFAULT 'N' NOT NULL,
    masking_rule_cd        varchar(20),
    retention_period_cd    varchar(10),
    tos_cd                 varchar(20),
    status_cd              varchar(10)   DEFAULT 'ACTIVE' NOT NULL,
    remark                 varchar(4000),
    created_by             varchar(128)  NOT NULL,
    created_at             timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by             varchar(128)  NOT NULL,
    updated_at             timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_meta_column PRIMARY KEY (column_id),
    CONSTRAINT uk_meta_column UNIQUE (table_id, column_name),
    CONSTRAINT fk_meta_column_table FOREIGN KEY (table_id) REFERENCES tb_meta_table(table_id),
    CONSTRAINT ck_meta_column_yn CHECK (
        nullable_yn IN ('Y','N') AND pk_yn IN ('Y','N') AND uk_yn IN ('Y','N')
        AND fk_yn IN ('Y','N') AND pci_yn IN ('Y','N')
        AND encryption_yn IN ('Y','N') AND masking_yn IN ('Y','N')
    )
);

CREATE INDEX idx_meta_column_01 ON tb_meta_column (table_id, column_order);
CREATE INDEX idx_meta_column_02 ON tb_meta_column (pci_yn, pci_category_cd);

-- ---------------------------------------------------------------------
-- §6.5 TB_META_INDEX / TB_META_INDEX_COLUMN
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_index (
    index_id           numeric(12)   NOT NULL,
    table_id           numeric(12)   NOT NULL,
    index_name         varchar(128)  NOT NULL,
    index_type_cd      varchar(20)   NOT NULL,
    tablespace_name    varchar(30),
    ini_trans          numeric(4),
    pct_free           numeric(3),
    purpose_cd         varchar(20)   NOT NULL,
    performance_note   varchar(4000),
    create_ddl         text,
    status_cd          varchar(10) DEFAULT 'ACTIVE' NOT NULL,
    created_by         varchar(128) NOT NULL,
    created_at         timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by         varchar(128) NOT NULL,
    updated_at         timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_meta_index PRIMARY KEY (index_id),
    CONSTRAINT uk_meta_index UNIQUE (table_id, index_name),
    CONSTRAINT fk_meta_index_table FOREIGN KEY (table_id) REFERENCES tb_meta_table(table_id)
);

CREATE TABLE tb_meta_index_column (
    index_id         numeric(12)   NOT NULL,
    column_pos       numeric(3)    NOT NULL,
    column_name      varchar(128)  NOT NULL,
    sort_order       varchar(4)    DEFAULT 'ASC' NOT NULL,
    func_expression  varchar(2000),
    CONSTRAINT pk_meta_index_column PRIMARY KEY (index_id, column_pos),
    CONSTRAINT fk_meta_index_column FOREIGN KEY (index_id) REFERENCES tb_meta_index(index_id),
    CONSTRAINT ck_meta_index_column CHECK (sort_order IN ('ASC','DESC'))
);

-- ---------------------------------------------------------------------
-- §6.6 TB_META_SEQUENCE
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_sequence (
    sequence_id       numeric(12)   NOT NULL,
    schema_name       varchar(128)  NOT NULL,
    sequence_name     varchar(128)  NOT NULL,
    min_value         numeric,
    max_value         numeric,
    increment_by      numeric       NOT NULL,
    start_with        numeric,
    cache_size        numeric,
    cycle_yn          char(1) DEFAULT 'N' NOT NULL,
    order_yn          char(1) DEFAULT 'N' NOT NULL,
    purpose_cd        varchar(20)  NOT NULL,
    used_for_table    varchar(128),
    used_for_column   varchar(128),
    create_ddl        text,
    status_cd         varchar(10) DEFAULT 'ACTIVE' NOT NULL,
    created_by        varchar(128) NOT NULL,
    created_at        timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_by        varchar(128) NOT NULL,
    updated_at        timestamp DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT pk_meta_sequence PRIMARY KEY (sequence_id),
    CONSTRAINT uk_meta_sequence UNIQUE (schema_name, sequence_name),
    CONSTRAINT ck_meta_seq_yn CHECK (cycle_yn IN ('Y','N') AND order_yn IN ('Y','N'))
);

-- ---------------------------------------------------------------------
-- §6.7 히스토리 시퀀스 (공통)
-- ---------------------------------------------------------------------
CREATE SEQUENCE seq_meta_hist_id START WITH 1 INCREMENT BY 1 CACHE 1000 NO CYCLE;

-- ---------------------------------------------------------------------
-- §6.7 TB_META_TABLE_HIST
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_table_hist (
    hist_id       numeric(16)    NOT NULL,
    hist_type     char(1)        NOT NULL,
    hist_at       timestamp      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    hist_by       varchar(128)   NOT NULL,
    change_reason varchar(2000)  NOT NULL,
    /* ↓ TB_META_TABLE 원본 컬럼 전체 (모두 nullable) */
    table_id             numeric(12),
    schema_name          varchar(128),
    table_name           varchar(128),
    logical_name         varchar(200),
    description          varchar(2000),
    view_yn              char(1),
    service_cd           varchar(20),
    owner_emp_id         varchar(20),
    secondary_emp_id     varchar(20),
    key_table_yn         char(1),
    isolation_yn         char(1),
    isolation_level_cd   varchar(10),
    pci_yn               char(1),
    retention_period_cd  varchar(10),
    retention_basis      varchar(500),
    tos_cd               varchar(20),
    status_cd            varchar(10),
    remark               varchar(4000),
    created_by           varchar(128),
    created_at           timestamp,
    updated_by           varchar(128),
    updated_at           timestamp,
    CONSTRAINT pk_meta_table_hist PRIMARY KEY (hist_id),
    CONSTRAINT ck_meta_table_hist_type CHECK (hist_type IN ('I','U','D'))
);
CREATE INDEX idx_meta_table_hist_01 ON tb_meta_table_hist (table_id, hist_at);

-- ---------------------------------------------------------------------
-- §6.7 TB_META_COLUMN_HIST (동일 패턴)
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_column_hist (
    hist_id       numeric(16)    NOT NULL,
    hist_type     char(1)        NOT NULL,
    hist_at       timestamp      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    hist_by       varchar(128)   NOT NULL,
    change_reason varchar(2000)  NOT NULL,
    /* ↓ TB_META_COLUMN 원본 컬럼 전체 */
    column_id              numeric(14),
    table_id               numeric(12),
    column_name            varchar(128),
    column_order           numeric(4),
    logical_name           varchar(200),
    description            varchar(2000),
    data_type              varchar(30),
    data_length            numeric(6),
    data_precision         numeric(6),
    data_scale             numeric(6),
    nullable_yn            char(1),
    default_value          varchar(500),
    pk_yn                  char(1),
    uk_yn                  char(1),
    fk_yn                  char(1),
    pci_yn                 char(1),
    pci_category_cd        varchar(20),
    sensitivity_cd         varchar(10),
    encryption_yn          char(1),
    encryption_alg         varchar(50),
    masking_yn             char(1),
    masking_rule_cd        varchar(20),
    retention_period_cd    varchar(10),
    tos_cd                 varchar(20),
    status_cd              varchar(10),
    remark                 varchar(4000),
    created_by             varchar(128),
    created_at             timestamp,
    updated_by             varchar(128),
    updated_at             timestamp,
    CONSTRAINT pk_meta_column_hist PRIMARY KEY (hist_id),
    CONSTRAINT ck_meta_column_hist_type CHECK (hist_type IN ('I','U','D'))
);
CREATE INDEX idx_meta_column_hist_01 ON tb_meta_column_hist (column_id, hist_at);
CREATE INDEX idx_meta_column_hist_02 ON tb_meta_column_hist (table_id, hist_at);

-- ---------------------------------------------------------------------
-- §6.7 TB_META_INDEX_HIST (동일 패턴)
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_index_hist (
    hist_id       numeric(16)    NOT NULL,
    hist_type     char(1)        NOT NULL,
    hist_at       timestamp      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    hist_by       varchar(128)   NOT NULL,
    change_reason varchar(2000)  NOT NULL,
    /* ↓ TB_META_INDEX 원본 컬럼 전체 */
    index_id           numeric(12),
    table_id           numeric(12),
    index_name         varchar(128),
    index_type_cd      varchar(20),
    tablespace_name    varchar(30),
    ini_trans          numeric(4),
    pct_free           numeric(3),
    purpose_cd         varchar(20),
    performance_note   varchar(4000),
    create_ddl         text,
    status_cd          varchar(10),
    created_by         varchar(128),
    created_at         timestamp,
    updated_by         varchar(128),
    updated_at         timestamp,
    CONSTRAINT pk_meta_index_hist PRIMARY KEY (hist_id),
    CONSTRAINT ck_meta_index_hist_type CHECK (hist_type IN ('I','U','D'))
);
CREATE INDEX idx_meta_index_hist_01 ON tb_meta_index_hist (index_id, hist_at);

-- ---------------------------------------------------------------------
-- §6.7 TB_META_INDEX_COLUMN_HIST (동일 패턴)
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_index_column_hist (
    hist_id       numeric(16)    NOT NULL,
    hist_type     char(1)        NOT NULL,
    hist_at       timestamp      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    hist_by       varchar(128)   NOT NULL,
    change_reason varchar(2000)  NOT NULL,
    /* ↓ TB_META_INDEX_COLUMN 원본 컬럼 전체 */
    index_id         numeric(12),
    column_pos       numeric(3),
    column_name      varchar(128),
    sort_order       varchar(4),
    func_expression  varchar(2000),
    CONSTRAINT pk_meta_index_column_hist PRIMARY KEY (hist_id),
    CONSTRAINT ck_meta_index_column_hist_type CHECK (hist_type IN ('I','U','D'))
);
CREATE INDEX idx_meta_index_column_hist_01 ON tb_meta_index_column_hist (index_id, hist_at);

-- ---------------------------------------------------------------------
-- §6.7 TB_META_SEQUENCE_HIST (동일 패턴)
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_sequence_hist (
    hist_id       numeric(16)    NOT NULL,
    hist_type     char(1)        NOT NULL,
    hist_at       timestamp      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    hist_by       varchar(128)   NOT NULL,
    change_reason varchar(2000)  NOT NULL,
    /* ↓ TB_META_SEQUENCE 원본 컬럼 전체 */
    sequence_id       numeric(12),
    schema_name       varchar(128),
    sequence_name     varchar(128),
    min_value         numeric,
    max_value         numeric,
    increment_by      numeric,
    start_with        numeric,
    cache_size        numeric,
    cycle_yn          char(1),
    order_yn          char(1),
    purpose_cd        varchar(20),
    used_for_table    varchar(128),
    used_for_column   varchar(128),
    create_ddl        text,
    status_cd         varchar(10),
    created_by        varchar(128),
    created_at        timestamp,
    updated_by        varchar(128),
    updated_at        timestamp,
    CONSTRAINT pk_meta_sequence_hist PRIMARY KEY (hist_id),
    CONSTRAINT ck_meta_sequence_hist_type CHECK (hist_type IN ('I','U','D'))
);
CREATE INDEX idx_meta_sequence_hist_01 ON tb_meta_sequence_hist (sequence_id, hist_at);

-- ---------------------------------------------------------------------
-- §6.7 TB_META_CODE_HIST (동일 패턴)
-- ---------------------------------------------------------------------
CREATE TABLE tb_meta_code_hist (
    hist_id       numeric(16)    NOT NULL,
    hist_type     char(1)        NOT NULL,
    hist_at       timestamp      DEFAULT CURRENT_TIMESTAMP NOT NULL,
    hist_by       varchar(128)   NOT NULL,
    change_reason varchar(2000)  NOT NULL,
    /* ↓ TB_META_CODE 원본 컬럼 전체 */
    code_group    varchar(30),
    code_value    varchar(30),
    code_name     varchar(200),
    description   varchar(2000),
    sort_order    numeric(4),
    use_yn        char(1),
    created_by    varchar(128),
    created_at    timestamp,
    updated_by    varchar(128),
    updated_at    timestamp,
    CONSTRAINT pk_meta_code_hist PRIMARY KEY (hist_id),
    CONSTRAINT ck_meta_code_hist_type CHECK (hist_type IN ('I','U','D'))
);
CREATE INDEX idx_meta_code_hist_01 ON tb_meta_code_hist (code_group, code_value, hist_at);

COMMIT;
