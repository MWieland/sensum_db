----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------
-- Name: SENSUM multi-temporal database support
-- Version: 0.92
-- Date: 16.01.15
-- Author: M. Wieland
-- DBMS: PostgreSQL9.2 / PostGIS2.0
-- Description: Adds the multi-temporal support to the basic SENSUM data model.
--		1. Adds trigger functions to log database transactions for selected tables or views
--		   (reference: http://wiki.postgresql.org/wiki/Audit_trigger_91plus)
--		2. Adds gethistory functions for transaction time and valid time
----------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------

------------------------------------------------
-- Create trigger function to log transactions--
------------------------------------------------
CREATE OR REPLACE FUNCTION history.if_modified() 
RETURNS TRIGGER AS 
$body$
DECLARE
    history_row history.logged_actions;
    include_values BOOLEAN;
    log_diffs BOOLEAN;
    h_old hstore;
    h_new hstore;
    excluded_cols text[] = ARRAY[]::text[];
BEGIN
    history_row = ROW(
        NEXTVAL('history.logged_actions_gid_seq'),    -- gid
        TG_TABLE_SCHEMA::text,                        -- schema_name
        TG_TABLE_NAME::text,                          -- table_name
        TG_RELID,                                     -- relation OID for much quicker searches
        txid_current(),                               -- transaction_id
        session_user::text,                           -- transaction_user
        current_timestamp,                            -- transaction_time
        current_query(),                              -- top-level query or queries (if multistatement) from client
        substring(TG_OP,1,1),                         -- transaction_type
        NULL, NULL, NULL                             -- old_record, new_record, changed_fields
        );
 
    IF NOT TG_ARGV[0]::BOOLEAN IS DISTINCT FROM 'f'::BOOLEAN THEN
        history_row.transaction_query = NULL;
    END IF;
 
    IF TG_ARGV[1] IS NOT NULL THEN
        excluded_cols = TG_ARGV[1]::text[];
    END IF;
 
    IF (TG_OP = 'UPDATE' AND TG_LEVEL = 'ROW') THEN
	history_row.old_record = hstore(OLD.*);
        history_row.new_record = hstore(NEW.*);
        history_row.changed_fields = (hstore(NEW.*) - history_row.old_record) - excluded_cols;
        IF history_row.changed_fields = hstore('') THEN
        -- All changed fields are ignored. Skip this update.
            RETURN NULL;
        END IF;
    ELSIF (TG_OP = 'DELETE' AND TG_LEVEL = 'ROW') THEN
	history_row.old_record = hstore(OLD.*);
    ELSIF (TG_OP = 'INSERT' AND TG_LEVEL = 'ROW') THEN
	history_row.new_record = hstore(NEW.*);
    ELSE
        RAISE EXCEPTION '[history.if_modified_func] - Trigger func added as trigger for unhandled case: %, %',TG_OP, TG_LEVEL;
        RETURN NULL;
    END IF;
    INSERT INTO history.logged_actions VALUES (history_row.*);
    RETURN NULL;
END;
$body$
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public;

COMMENT ON FUNCTION history.if_modified() IS $body$
Track changes TO a TABLE or a VIEW at the row level.
Optional parameters TO TRIGGER IN CREATE TRIGGER call:
param 0: BOOLEAN, whether TO log the query text. DEFAULT 't'.
param 1: text[], COLUMNS TO IGNORE IN updates. DEFAULT [].

         Note: Updates TO ignored cols are included in new_record.
         Updates WITH only ignored cols changed are NOT inserted
         INTO the history log.
         There IS no parameter TO disable logging of VALUES. ADD this TRIGGER AS
         a 'FOR EACH STATEMENT' rather than 'FOR EACH ROW' TRIGGER IF you do NOT
         want TO log row VALUES.
$body$;

-------------------------------------------------------------------------------------------
-- Create trigger function to update inserts in logged transactions when a view is logged--
-------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION history.if_modified_view()
RETURNS TRIGGER AS 
$BODY$
DECLARE
    tbl regclass;
BEGIN
    IF NEW.transaction_type = 'I' THEN
	FOR tbl IN
	    --get table name
	    SELECT schema_name::text || '.' || table_name::text FROM history.logged_actions WHERE gid=(SELECT max(gid) FROM history.logged_actions)
	LOOP
	    EXECUTE '
	    UPDATE history.logged_actions SET 
		new_record = (SELECT hstore('|| tbl ||'.*) FROM '|| tbl ||' WHERE gid=(SELECT max(gid) FROM '|| tbl ||' ))
		WHERE gid=(SELECT max(gid) FROM history.logged_actions);
	    ';
	END LOOP;
    END IF;
    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql;
COMMENT ON FUNCTION history.if_modified_view() IS $body$
This function updates the gid of a view in the logged actions table for the INSERT statement.
$body$;

---------------------------------------------------------------------------------
-- Create function to activate transaction logging for a specific table or view--
---------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION history.history_table(target_table regclass, history_view BOOLEAN, history_query_text BOOLEAN, ignored_cols text[]) 
RETURNS void AS 
$body$
DECLARE
  _q_txt text;
  _ignored_cols_snip text = '';
BEGIN
    IF history_view THEN
	    --create trigger on view (use instead of trigger) - note: in case of multiple triggers on the same table/view the execution order is alphabetical
	    IF array_length(ignored_cols,1) > 0 THEN
		_ignored_cols_snip = ', ' || quote_literal(ignored_cols);
	    END IF;
	    
	    EXECUTE 'DROP TRIGGER IF EXISTS zhistory_trigger_row ON ' || target_table::text;
	    _q_txt = 'CREATE TRIGGER zhistory_trigger_row INSTEAD OF INSERT OR UPDATE ON ' ||
		     target_table::text ||
		     ' FOR EACH ROW EXECUTE PROCEDURE history.if_modified(' || 
			quote_literal(history_query_text) || _ignored_cols_snip || ');';
	    RAISE NOTICE '%',_q_txt;
	    EXECUTE _q_txt;
	    --workaround to update all columns after insert on view (instead of trigger on view does not capture all inserts like gid)
	    EXECUTE 'DROP TRIGGER IF EXISTS zhistory_trigger_row_modified ON history.logged_actions';
	    _q_txt = 'CREATE TRIGGER zhistory_trigger_row_modified AFTER INSERT ON history.logged_actions 
			FOR EACH ROW EXECUTE PROCEDURE history.if_modified_view();';
	    RAISE NOTICE '%',_q_txt;
	    EXECUTE _q_txt;
    ELSE
	    --create trigger on table (use after trigger)
	    IF array_length(ignored_cols,1) > 0 THEN
		_ignored_cols_snip = ', ' || quote_literal(ignored_cols);
	    END IF;

	    EXECUTE 'DROP TRIGGER IF EXISTS history_trigger_row ON ' || target_table::text;
            _q_txt = 'CREATE TRIGGER history_trigger_row AFTER INSERT OR UPDATE OR DELETE ON ' || 
                     target_table::text || 
                     ' FOR EACH ROW EXECUTE PROCEDURE history.if_modified(' ||
                     quote_literal(history_query_text) || _ignored_cols_snip || ');';
            RAISE NOTICE '%',_q_txt;
            EXECUTE _q_txt;
    END IF;
END;
$body$
LANGUAGE 'plpgsql';
 
COMMENT ON FUNCTION history.history_table(regclass, BOOLEAN, BOOLEAN, text[]) IS $body$
ADD transaction logging support TO a TABLE.

Arguments:
   target_table:       TABLE name, schema qualified IF NOT ON search_path
   history_view:       Activate trigger for view (true) or for table (false)
   history_query_text: Record the text of the client query that triggered the history event?
   ignored_cols:       COLUMNS TO exclude FROM UPDATE diffs, IGNORE updates that CHANGE only ignored cols.
$body$;

---------------------------------------------------------------------------------
-- Provide a wrapper because Pg does not allow variadic calls with 0 parameters--
---------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION history.history_table(target_table regclass, history_view BOOLEAN, history_query_text BOOLEAN) 
RETURNS void AS 
$body$
SELECT history.history_table($1, $2, $3, ARRAY[]::text[]);
$body$ 
LANGUAGE SQL;

------------------------------------------------------------------------------------------------------------------------------------------
-- Provide a convenience call wrapper for the simplest case (row-level logging on table with no excluded cols and query logging enabled)--
------------------------------------------------------------------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION history.history_table(target_table regclass) 
RETURNS void AS 
$$
SELECT history.history_table($1, BOOLEAN 'f', BOOLEAN 't');
$$ 
LANGUAGE 'sql';
 
COMMENT ON FUNCTION history.history_table(regclass) IS $body$
ADD auditing support TO the given TABLE. Row-level changes will be logged WITH FULL query text. No cols are ignored.
$body$;

------------------------------------------------------
-- Add transaction time query function (getHistory) --
------------------------------------------------------
CREATE OR REPLACE FUNCTION history.ttime_gethistory(tbl character varying)
RETURNS SETOF RECORD AS
$BODY$
BEGIN
    RETURN QUERY EXECUTE '
	--query1: query new_record column to get the UPDATE and INSERT records
	(SELECT (populate_record(null::' ||tbl|| ', b.new_record)).*, b.transaction_time, b.transaction_type FROM history.logged_actions AS b 
		WHERE b.table_name = split_part('''||tbl||''', ''.'', 2) 
		AND b.transaction_type=''U''
		OR b.table_name = split_part('''||tbl||''', ''.'', 2) 
		AND b.transaction_type=''I''
	ORDER BY b.transaction_time DESC)	

	UNION ALL

	--query2: query old_record column to get the DELETE records
	(SELECT (populate_record(null::' ||tbl|| ', b.old_record)).*, b.transaction_time, b.transaction_type FROM history.logged_actions AS b 
		WHERE b.table_name = split_part('''||tbl||''', ''.'', 2) 
		AND b.transaction_type=''D''
	ORDER BY b.transaction_time DESC);
	';
END;
$BODY$
LANGUAGE plpgsql;
COMMENT ON FUNCTION history.ttime_gethistory(tbl character varying) IS $body$
This function searches history.logged_actions to get all transactions of object primitives. Results table structure needs to be defined manually. Returns set of records.
Arguments:
   tbl:		schema.table character varying
$body$;

--Convenience call wrapper that gets dynamic column structure of results and writes them to view
CREATE OR REPLACE FUNCTION history.ttime_gethistory(tbl_in character varying, tbl_out character varying)
RETURNS void AS 
$BODY$
DECLARE 
  tbl_struct text;
BEGIN
tbl_struct := string_agg(column_name || ' ' || udt_name, ',') FROM information_schema.columns WHERE table_name = split_part(tbl_in, '.', 2);
EXECUTE '
	CREATE OR REPLACE VIEW '|| tbl_out ||' AS
		SELECT ROW_NUMBER() OVER (ORDER BY transaction_timestamp ASC) AS rowid, * 
		FROM history.ttime_gethistory('''|| tbl_in ||''') 
			main ('|| tbl_struct ||', transaction_timestamp timestamptz, transaction_type text);
	';
END;
$BODY$  
LANGUAGE plpgsql;
COMMENT ON FUNCTION history.ttime_gethistory(tbl_in character varying, tbl_out character varying) IS $body$
This function searches history.logged_actions to get all transactions of object primitives. Results table structure is defined dynamically from input table/view. Returns view.
Arguments:
   tbl_in:		schema.table character varying
   tbl_out:		schema.table character varying
$body$;

------------------------------------------------
-- Add valid time query function (getHistory) --
------------------------------------------------
CREATE OR REPLACE FUNCTION history.vtime_gethistory(tbl character varying, col_value character varying, col_vtime character varying)
RETURNS SETOF RECORD AS
$BODY$
BEGIN
    RETURN QUERY EXECUTE '
	--query1: query new_record column to get the INSERT records
	(SELECT DISTINCT ON (b.new_record->''gid'') (populate_record(null::' ||tbl|| ', b.new_record)).*, b.transaction_time, b.transaction_type FROM history.logged_actions AS b 
		WHERE b.table_name = split_part('''||tbl||''', ''.'', 2) 
		AND (populate_record(null::' ||tbl|| ', b.new_record)).'||col_value||'=''BUILT'' 
	ORDER BY b.new_record->''gid'', b.transaction_time DESC)

	UNION ALL

	--query2: query new_record column to get the UPDATE records
	(SELECT DISTINCT ON (b.new_record->''gid'', b.new_record->'''||col_vtime||''') (populate_record(null::' ||tbl|| ', b.new_record)).*, b.transaction_time, b.transaction_type FROM history.logged_actions AS b 
		WHERE b.table_name = split_part('''||tbl||''', ''.'', 2) 
		AND (populate_record(null::' ||tbl|| ', b.new_record)).'||col_value||'=''MODIF''
	ORDER BY b.new_record->''gid'', b.new_record->'''||col_vtime||''', b.transaction_time DESC)

	UNION ALL
	
	--query3: query old_record column to get the DELETE records
	(SELECT DISTINCT ON (b.old_record->''gid'') (populate_record(null::' ||tbl|| ', b.old_record)).*, b.transaction_time, b.transaction_type FROM history.logged_actions AS b 
		WHERE b.table_name = split_part('''||tbl||''', ''.'', 2) 
		AND (populate_record(null::' ||tbl|| ', b.old_record)).'||col_value||'=''DESTR'' 
	ORDER BY b.old_record->''gid'', b.transaction_time DESC)
	';
END;
$BODY$
LANGUAGE plpgsql;
COMMENT ON FUNCTION history.vtime_gethistory(tbl character varying, col_value character varying, col_vtime character varying) IS $body$
This function searches history.logged_actions to get all real world changes with the corresponding latest version for each object primitive at each valid time.
Results table structure needs to be defined manually. Returns set of records.

Arguments:
   tbl:			table/view that holds the valid time columns character varying
   col_value:		column that holds the qualifier values (BUILT, MODIF, DESTR) character varying
   col_vtime:		column that holds the actual valid time character varying
$body$;

--Convenience call wrapper that gets dynamic column structure of results and writes them to view
CREATE OR REPLACE FUNCTION history.vtime_gethistory(tbl_in character varying, tbl_out character varying, col_value character varying, col_vtime character varying)
RETURNS void AS 
$BODY$
DECLARE 
  tbl_struct text;
BEGIN
tbl_struct := string_agg(column_name || ' ' || udt_name, ',') FROM information_schema.columns WHERE table_name = split_part(tbl_in, '.', 2);
EXECUTE '
	CREATE OR REPLACE VIEW '|| tbl_out ||' AS
		SELECT ROW_NUMBER() OVER (ORDER BY transaction_timestamp ASC) AS rowid, * 
		FROM history.vtime_gethistory('''|| tbl_in ||''', '''|| col_value ||''', '''|| col_vtime ||''') 
			main ('|| tbl_struct ||', transaction_timestamp timestamptz, transaction_type text);
	';
END;
$BODY$  
LANGUAGE plpgsql;
COMMENT ON FUNCTION history.vtime_gethistory(tbl_in character varying, tbl_out character varying, col_value character varying, col_vtime character varying) IS $body$
This function searches history.logged_actions to get all real world changes with the corresponding latest version for each object primitive at each valid time.
Results table structure is defined dynamically from input table/view. Returns view.
Arguments:
   tbl_in:		schema.table character varying
   tbl_out:		schema.table character varying
   col_value:		column that holds the qualifier values (BUILT, MODIF, DESTR) character varying
   col_vtime:		column that holds the actual valid time character varying
$body$;
