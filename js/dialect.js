/* =========================================================
 * Dialect — Oracle / PostgreSQL 전략 객체
 *   생성기는 다이얼렉트별 SQL 단편(type DDL, 시퀀스 NEXTVAL,
 *   타임스탬프 함수 등)을 본 모듈을 통해서만 받는다.
 *   활성 다이얼렉트는 App 측에서 Dialect.set('POSTGRESQL'|'ORACLE')로 전환.
 *
 *   load order: codes.js → dialect.js → utils.js → ... → app.js
 * ========================================================= */

const Dialect = (() => {
  let _active = 'ORACLE';

  // 식별자는 사용자 선택(현행 유지)에 따라 두 다이얼렉트 모두 UPPERCASE unquoted.
  // PG는 자동으로 lowercase 폴딩하지만, 같은 케이스로 조회하면 동일하게 폴딩되어
  // 매칭되므로 운영상 무리 없음. (catalog 직접 조회 SQL은 sql/postgresql/* 측에서 별도 처리)

  const Oracle = {
    name: 'ORACLE',
    label: 'Oracle',

    sysTimestamp() { return 'SYSTIMESTAMP'; },

    nextval(seqName) { return `${seqName}.NEXTVAL`; },

    nvl(expr, fallback) { return `NVL(${expr}, ${fallback})`; },

    typeDDL(type, length, precision, scale, lengthSemantics) {
      const t = (type || '').toUpperCase();
      if (t === 'VARCHAR2' || t === 'CHAR') {
        const sem = (lengthSemantics || '').toUpperCase();
        const semSuffix = (sem === 'CHAR' || sem === 'BYTE') ? ` ${sem}` : '';
        return `${t}(${length || 1}${semSuffix})`;
      }
      if (t === 'RAW') return `RAW(${length || 1})`;
      if (t === 'NUMBER') {
        if (precision && scale !== null && scale !== undefined && scale !== '')
          return `NUMBER(${precision},${scale})`;
        if (precision) return `NUMBER(${precision})`;
        return 'NUMBER';
      }
      return t; // DATE / TIMESTAMP / CLOB / BLOB / FLOAT / BINARY_DOUBLE
    },

    tableStorageClause({ tablespace }) {
      return tablespace ? `\nTABLESPACE ${tablespace.toUpperCase()}` : '';
    },

    indexStorageClause({ tablespace, iniTrans, pctFree }) {
      let s = '';
      if (tablespace) s += `\nTABLESPACE ${tablespace.toUpperCase()}`;
      if (iniTrans)   s += `\nINITRANS ${iniTrans}`;
      if (pctFree)    s += `\nPCTFREE ${pctFree}`;
      return s;
    },

    indexCreateKeyword(typeCd) {
      if (typeCd === 'UNIQUE') return 'CREATE UNIQUE INDEX';
      if (typeCd === 'BITMAP') return 'CREATE BITMAP INDEX';
      return 'CREATE INDEX';
    },

    indexFallbackNotice(_typeCd) { return ''; },

    sequenceCreateDDL({ schema, seq, startWith, incrementBy, minValue, maxValue, cycle, cache, order }) {
      let ddl = `CREATE SEQUENCE ${schema}.${seq}`;
      if (startWith)   ddl += `\n  START WITH ${startWith}`;
      if (incrementBy) ddl += `\n  INCREMENT BY ${incrementBy}`;
      if (minValue)    ddl += `\n  MINVALUE ${minValue}`;
      if (maxValue)    ddl += `\n  MAXVALUE ${maxValue}`;
      ddl += `\n  ${cycle ? 'CYCLE' : 'NOCYCLE'}`;
      if (cache)       ddl += `\n  CACHE ${cache}`;
      ddl += `\n  ${order ? 'ORDER' : 'NOORDER'};\n`;
      return ddl;
    },

    sequenceAlterDDL({ schema, seq, incrementBy, minValue, maxValue, cycle, cache, order }) {
      let ddl = `ALTER SEQUENCE ${schema}.${seq}`;
      if (incrementBy) ddl += `\n  INCREMENT BY ${incrementBy}`;
      if (minValue)    ddl += `\n  MINVALUE ${minValue}`;
      if (maxValue)    ddl += `\n  MAXVALUE ${maxValue}`;
      ddl += `\n  ${cycle ? 'CYCLE' : 'NOCYCLE'}`;
      if (cache)       ddl += `\n  CACHE ${cache}`;
      ddl += `\n  ${order ? 'ORDER' : 'NOORDER'};\n`;
      return ddl;
    },

    addColumnDDL({ schema, tbl, col, typeDDLFrag, defaultValue, nullable }) {
      let ddl = `ALTER TABLE ${schema}.${tbl} ADD (${col} ${typeDDLFrag}`;
      if (defaultValue) ddl += ` DEFAULT ${defaultValue}`;
      ddl += nullable ? '' : ' NOT NULL';
      ddl += ');\n';
      return ddl;
    },

    modifyColumnDDL({ schema, tbl, col, typeDDLFrag, defaultValue, nullable }) {
      let ddl = `ALTER TABLE ${schema}.${tbl} MODIFY (${col}`;
      if (typeDDLFrag) ddl += ` ${typeDDLFrag}`;
      if (defaultValue) ddl += ` DEFAULT ${defaultValue}`;
      ddl += nullable ? ' NULL' : ' NOT NULL';
      ddl += ');\n';
      return ddl;
    },
  };

  const Postgresql = {
    name: 'POSTGRESQL',
    label: 'PostgreSQL',

    sysTimestamp() { return 'CURRENT_TIMESTAMP'; },

    // PG nextval: 텍스트→regclass 캐스트 시 unquoted 식별자와 동일하게 lowercase 폴딩.
    // 'SEQ_META_HIST_ID' → seq_meta_hist_id 로 조회되어, CREATE SEQUENCE 시 폴딩된 이름과 매칭.
    nextval(seqName) { return `nextval('${seqName}')`; },

    nvl(expr, fallback) { return `COALESCE(${expr}, ${fallback})`; },

    typeDDL(type, length, precision, scale, _lengthSemantics) {
      const t = (type || '').toUpperCase();
      if (t === 'VARCHAR2')       return `VARCHAR(${length || 1})`;
      if (t === 'CHAR')           return `CHAR(${length || 1})`;
      if (t === 'NUMBER') {
        if (precision && scale !== null && scale !== undefined && scale !== '')
          return `NUMERIC(${precision},${scale})`;
        if (precision) return `NUMERIC(${precision})`;
        return 'NUMERIC';
      }
      if (t === 'DATE')           return 'TIMESTAMP';        // Oracle DATE=날짜+시각 → PG TIMESTAMP 로 매핑(시맨틱 보존)
      if (t === 'TIMESTAMP')      return 'TIMESTAMP';
      if (t === 'CLOB')           return 'TEXT';
      if (t === 'BLOB')           return 'BYTEA';
      if (t === 'RAW')            return 'BYTEA';
      if (t === 'FLOAT')          return 'REAL';
      if (t === 'BINARY_DOUBLE')  return 'DOUBLE PRECISION';
      return t;
    },

    tableStorageClause(_) { return ''; },   // PG는 TABLESPACE 미사용

    indexStorageClause(_) { return ''; },   // PG는 INITRANS/PCTFREE/TABLESPACE 미사용

    indexCreateKeyword(typeCd) {
      // BITMAP은 PG에 등가 없음 → 일반 B-tree 로 fallback (호출측에서 indexFallbackNotice 출력)
      if (typeCd === 'UNIQUE') return 'CREATE UNIQUE INDEX';
      return 'CREATE INDEX';
    },

    indexFallbackNotice(typeCd) {
      if (typeCd === 'BITMAP')
        return `-- [경고] BITMAP 인덱스는 PostgreSQL에 등가 없음 — 일반 B-tree 인덱스로 출력합니다.\n`;
      return '';
    },

    sequenceCreateDDL({ schema, seq, startWith, incrementBy, minValue, maxValue, cycle, cache, order: _order }) {
      // PG는 ORDER/NOORDER 절 없음 → order 무시
      let ddl = `CREATE SEQUENCE ${schema}.${seq}`;
      if (startWith)   ddl += `\n  START WITH ${startWith}`;
      if (incrementBy) ddl += `\n  INCREMENT BY ${incrementBy}`;
      if (minValue)    ddl += `\n  MINVALUE ${minValue}`;
      if (maxValue)    ddl += `\n  MAXVALUE ${maxValue}`;
      ddl += `\n  ${cycle ? 'CYCLE' : 'NO CYCLE'}`;
      if (cache)       ddl += `\n  CACHE ${cache}`;
      ddl += `;\n`;
      return ddl;
    },

    sequenceAlterDDL({ schema, seq, incrementBy, minValue, maxValue, cycle, cache, order: _order }) {
      let ddl = `ALTER SEQUENCE ${schema}.${seq}`;
      if (incrementBy) ddl += `\n  INCREMENT BY ${incrementBy}`;
      if (minValue)    ddl += `\n  MINVALUE ${minValue}`;
      if (maxValue)    ddl += `\n  MAXVALUE ${maxValue}`;
      ddl += `\n  ${cycle ? 'CYCLE' : 'NO CYCLE'}`;
      if (cache)       ddl += `\n  CACHE ${cache}`;
      ddl += `;\n`;
      return ddl;
    },

    addColumnDDL({ schema, tbl, col, typeDDLFrag, defaultValue, nullable }) {
      let ddl = `ALTER TABLE ${schema}.${tbl} ADD COLUMN ${col} ${typeDDLFrag}`;
      if (defaultValue) ddl += ` DEFAULT ${defaultValue}`;
      ddl += nullable ? '' : ' NOT NULL';
      ddl += ';\n';
      return ddl;
    },

    modifyColumnDDL({ schema, tbl, col, typeDDLFrag, defaultValue, nullable }) {
      // PG MODIFY는 여러 ALTER 문으로 분리 — 타입/디폴트/NOT NULL 각각 별도.
      const stmts = [];
      if (typeDDLFrag) stmts.push(`ALTER TABLE ${schema}.${tbl} ALTER COLUMN ${col} TYPE ${typeDDLFrag};`);
      if (defaultValue) stmts.push(`ALTER TABLE ${schema}.${tbl} ALTER COLUMN ${col} SET DEFAULT ${defaultValue};`);
      stmts.push(nullable
        ? `ALTER TABLE ${schema}.${tbl} ALTER COLUMN ${col} DROP NOT NULL;`
        : `ALTER TABLE ${schema}.${tbl} ALTER COLUMN ${col} SET NOT NULL;`);
      return stmts.join('\n') + '\n';
    },
  };

  return {
    ORACLE: Oracle,
    POSTGRESQL: Postgresql,
    current()    { return _active === 'POSTGRESQL' ? Postgresql : Oracle; },
    set(name)    { _active = (name === 'POSTGRESQL') ? 'POSTGRESQL' : 'ORACLE'; },
    activeName() { return _active; },
  };
})();
