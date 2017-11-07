#!/bin/bash

CONNSTRING=$1
psql -d $CONNSTRING <<EOF
CREATE EXTENSION file_fdw;
CREATE SERVER pglog FOREIGN DATA WRAPPER file_fdw;
CREATE ROLE admin CREATEDB NOLOGIN;
CREATE ROLE robot_zmon;

CREATE EXTENSION pg_cron;

ALTER TABLE cron.job ALTER COLUMN nodename SET DEFAULT '/var/run/postgresql';
ALTER POLICY cron_job_policy ON cron.job USING (username = current_user OR pg_has_role(current_user, 'admin', 'MEMBER') AND pg_has_role(username, 'admin', 'MEMBER') AND NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname = username AND rolsuper));
REVOKE SELECT ON cron.job FROM public;
GRANT SELECT ON cron.job TO admin;
GRANT UPDATE (database) ON cron.job TO admin;

CREATE OR REPLACE FUNCTION cron.schedule(p_schedule text, p_database text, p_command text)
RETURNS bigint
LANGUAGE plpgsql
AS \$function\$
DECLARE
    l_jobid bigint;
BEGIN
    SELECT schedule INTO l_jobid FROM cron.schedule(p_schedule, p_command);
    UPDATE cron.job SET database = p_database WHERE jobid = l_jobid;
    RETURN l_jobid;
END;
\$function\$;
REVOKE EXECUTE ON FUNCTION cron.schedule(text, text) FROM public;
GRANT EXECUTE ON FUNCTION cron.schedule(text, text) TO admin;
REVOKE EXECUTE ON FUNCTION cron.schedule(text, text, text) FROM public;
GRANT EXECUTE ON FUNCTION cron.schedule(text, text, text) TO admin;
REVOKE EXECUTE ON FUNCTION cron.unschedule(bigint) FROM public;
GRANT EXECUTE ON FUNCTION cron.unschedule(bigint) TO admin;
GRANT USAGE ON SCHEMA cron TO admin;

CREATE TABLE postgres_log (
    log_time timestamp(3) with time zone,
    user_name text,
    database_name text,
    process_id integer,
    connection_from text,
    session_id text NOT NULL,
    session_line_num bigint NOT NULL,
    command_tag text,
    session_start_time timestamp with time zone,
    virtual_transaction_id text,
    transaction_id bigint,
    error_severity text,
    sql_state_code text,
    message text,
    detail text,
    hint text,
    internal_query text,
    internal_query_pos integer,
    context text,
    query text,
    query_pos integer,
    location text,
    application_name text,
    CONSTRAINT postgres_log_check CHECK (false) NO INHERIT
);

-- Sunday could be 0 or 7 depending on the format, we just create both
CREATE FOREIGN TABLE postgres_log_0 () INHERITS (postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-0.csv', format 'csv', header 'false');
CREATE FOREIGN TABLE postgres_log_7 () INHERITS (postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-7.csv', format 'csv', header 'false');

CREATE FOREIGN TABLE postgres_log_1 () INHERITS (postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-1.csv', format 'csv', header 'false');
CREATE FOREIGN TABLE postgres_log_2 () INHERITS (postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-2.csv', format 'csv', header 'false');
CREATE FOREIGN TABLE postgres_log_3 () INHERITS (postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-3.csv', format 'csv', header 'false');
CREATE FOREIGN TABLE postgres_log_4 () INHERITS (postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-4.csv', format 'csv', header 'false');
CREATE FOREIGN TABLE postgres_log_5 () INHERITS (postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-5.csv', format 'csv', header 'false');
CREATE FOREIGN TABLE postgres_log_6 () INHERITS (postgres_log) SERVER pglog
    OPTIONS (filename '../pg_log/postgresql-6.csv', format 'csv', header 'false');

GRANT SELECT ON postgres_log TO ADMIN;
GRANT SELECT ON postgres_log_0 TO ADMIN;
GRANT SELECT ON postgres_log_1 TO ADMIN;
GRANT SELECT ON postgres_log_2 TO ADMIN;
GRANT SELECT ON postgres_log_3 TO ADMIN;
GRANT SELECT ON postgres_log_4 TO ADMIN;
GRANT SELECT ON postgres_log_5 TO ADMIN;
GRANT SELECT ON postgres_log_6 TO ADMIN;
GRANT SELECT ON postgres_log_7 TO ADMIN;

CREATE LANGUAGE plpython3u;
\i /_zmon_schema.dump

\i /create_user_functions.sql

\c template1
CREATE EXTENSION pg_stat_statements;
CREATE EXTENSION set_user;
GRANT EXECUTE ON FUNCTION set_user(text) TO admin;

\i /create_user_functions.sql

EOF
