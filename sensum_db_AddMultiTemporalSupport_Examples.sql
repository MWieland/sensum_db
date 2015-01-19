------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- Name: SENSUM multi-temporal support examples
-- Version: 0.9.2
-- Date: 16.01.15
-- Author: M. Wieland
-- DBMS: PostgreSQL9.2 / PostGIS2.0
-- Description: Some examples to 
--			- activate/deactivate logging of transactions
--			- properly insert, update and delete entries with temporal component
--			- transaction and valid time history
--			- temporal queries
--			- spatio-temporal queries
--			- other queries
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------
-- Example for activation/deactivation of logging transactions on a table --
----------------------------------------------------------------------------
-- selective transaction logs: history.history_table(target_table regclass, history_view boolean, history_query_text boolean, excluded_cols text[]) 
SELECT history.history_table('object_res1.main');	--short call to activate table log with query text activated and no excluded cols
SELECT history.history_table('object_res1.main', 'false', 'true');	--same as above but as full call
SELECT history.history_table('object_res1.main', 'false', 'false', '{res2_id, res3_id}'::text[]);	--activate table log with no query text activated and excluded cols specified
SELECT history.history_table('object_res1.ve_resolution1', 'true', 'false', '{source, res2_id, res3_id}'::text[]);	--activate logs for a view

--deactivate transaction logs on table
DROP TRIGGER IF EXISTS history_trigger_row ON object_res1.main;

--deactivate transaction logs on view
DROP TRIGGER IF EXISTS zhistory_trigger_row ON object_res1.ve_resolution1;
DROP TRIGGER IF EXISTS zhistory_trigger_row_modified ON history.logged_actions;


----------------------------------------------------------------------------------------
-- Example statements to properly INSERT, UPDATE or DELETE objects for different cases--
----------------------------------------------------------------------------------------
--INSERT an object cause of a real world construction: 1. mark the object change type as 'BUILT'; 2. set the date of construction; 3. insert it
insert into object_res1.ve_resolution1 (description, yr_built_vt, yr_built_vt1) values ('insert', 'BUILT', '01-01-2000');

--UPDATE an object cause of a real world modification: 1. mark the object change type as 'MODIF'; 2. set the date of modification; 3. update it
update object_res1.ve_resolution1 set description='modified', yr_built_vt='MODIF', yr_built_vt1='01-01-2002' where gid=1;

--DELETE an object cause of a real world destruction: 1. mark the object change type as 'DESTR'; 2. set the date of destruction; 3. delete it
update object_res1.ve_resolution1 set description='deleted', yr_built_vt='DESTR', yr_built_vt1='01-01-2014' where gid=1;
delete from object_res1.ve_resolution1 where gid=1;

--UPDATE an object cause of a correction or cause more information gets available (no real world change): update it without marking the object change type
update object_res1.ve_resolution1 set description='modified_corrected' where gid=1;


---------------------------------------------------------------------------------
-- Example for "get transaction time history" ttime_gethistory(tbl_in, tbl_out)--
---------------------------------------------------------------------------------
-- This gives the transaction time history of a table/view and writes it to a view (all the logged changes)
SELECT * FROM history.ttime_gethistory('object_res1.ve_resolution1', 'history.ttime_history');

-- Same as above, but output as records. 
-- Note: structure of results has to be defined manually (=structure of input table + transaction_timestamp timestamptz, transaction_type text). 
-- Note: this allows also to filter the results using WHERE statement.
SELECT * FROM history.ttime_gethistory('object_res1.ve_resolution1') 
	main (gid int4,survey_gid int4,description varchar,source text,res2_id int4,res3_id int4,the_geom geometry,object_id int4,mat_type varchar,mat_tech varchar,mat_prop varchar,llrs varchar,llrs_duct varchar,height varchar,yr_built varchar,occupy varchar,occupy_dt varchar,position varchar,plan_shape varchar,str_irreg varchar,str_irreg_dt varchar,str_irreg_type varchar,nonstrcexw varchar,roof_shape varchar,roofcovmat varchar,roofsysmat varchar,roofsystyp varchar,roof_conn varchar,floor_mat varchar,floor_type varchar,floor_conn varchar,foundn_sys varchar,build_type varchar,build_subtype varchar,vuln varchar,vuln_1 numeric,vuln_2 numeric,height_1 numeric,height_2 numeric,object_id1 int4,mat_type_bp int4,mat_tech_bp int4,mat_prop_bp int4,llrs_bp int4,llrs_duct_bp int4,height_bp int4,yr_built_bp int4,occupy_bp int4,occupy_dt_bp int4,position_bp int4,plan_shape_bp int4,str_irreg_bp int4,str_irreg_dt_bp int4,str_irreg_type_bp int4,nonstrcexw_bp int4,roof_shape_bp int4,roofcovmat_bp int4,roofsysmat_bp int4,roofsystyp_bp int4,roof_conn_bp int4,floor_mat_bp int4,floor_type_bp int4,floor_conn_bp int4,foundn_sys_bp int4,build_type_bp int4,build_subtype_bp int4,vuln_bp int4,yr_built_vt varchar,yr_built_vt1 timestamptz,  
	      transaction_timestamp timestamptz, 
	      transaction_type text) WHERE gid=1 ORDER BY transaction_timestamp;

-- Custom view
CREATE OR REPLACE VIEW history.ttime_gethistory_custom AS
SELECT ROW_NUMBER() OVER (ORDER BY transaction_timestamp ASC) AS rowid, * FROM history.ttime_gethistory('object_res1.main') 
	main (gid integer, 
	      survey_gid integer, 
	      description character varying, 
	      source text, 
	      res2_id integer, 
	      res3_id integer, 
	      the_geom geometry, 
	      transaction_timestamp timestamptz, 
	      transaction_type text) WHERE gid=2;

    
------------------------------------------------------------
-- Example for "get valid time history" vtime_gethistory()--
------------------------------------------------------------
-- This gives the valid time history of a table/view and writes it to a view (only the real world changes - it gives the latest version of the object primitives at each real world change time)
SELECT * FROM history.vtime_gethistory('object_res1.ve_resolution1', 'history.vtime_history', 'yr_built_vt', 'yr_built_vt1');

-- Same as above, but output as records. 
SELECT * FROM history.vtime_gethistory('object_res1.ve_resolution1', 'yr_built_vt', 'yr_built_vt1') 
	main (gid int4,survey_gid int4,description varchar,source text,res2_id int4,res3_id int4,the_geom geometry,object_id int4,mat_type varchar,mat_tech varchar,mat_prop varchar,llrs varchar,llrs_duct varchar,height varchar,yr_built varchar,occupy varchar,occupy_dt varchar,position varchar,plan_shape varchar,str_irreg varchar,str_irreg_dt varchar,str_irreg_type varchar,nonstrcexw varchar,roof_shape varchar,roofcovmat varchar,roofsysmat varchar,roofsystyp varchar,roof_conn varchar,floor_mat varchar,floor_type varchar,floor_conn varchar,foundn_sys varchar,build_type varchar,build_subtype varchar,vuln varchar,vuln_1 numeric,vuln_2 numeric,height_1 numeric,height_2 numeric,object_id1 int4,mat_type_bp int4,mat_tech_bp int4,mat_prop_bp int4,llrs_bp int4,llrs_duct_bp int4,height_bp int4,yr_built_bp int4,occupy_bp int4,occupy_dt_bp int4,position_bp int4,plan_shape_bp int4,str_irreg_bp int4,str_irreg_dt_bp int4,str_irreg_type_bp int4,nonstrcexw_bp int4,roof_shape_bp int4,roofcovmat_bp int4,roofsysmat_bp int4,roofsystyp_bp int4,roof_conn_bp int4,floor_mat_bp int4,floor_type_bp int4,floor_conn_bp int4,foundn_sys_bp int4,build_type_bp int4,build_subtype_bp int4,vuln_bp int4,yr_built_vt varchar,yr_built_vt1 timestamptz,  
	      transaction_timestamp timestamptz, 
	      transaction_type text) ORDER BY transaction_timestamp;


-----------------------------------------------------------
------------ Example for "temporal queries" ---------------
-----------------------------------------------------------
-- transaction time query (timestamp): timestamp EQUALS timestamp
SELECT * FROM history.ttime_history WHERE 
	date_trunc('minute', transaction_timestamp) = '2015-01-12 15:45' 
	ORDER BY gid, transaction_timestamp DESC;

-- transaction time query (timestamp): timestamp INSIDE timerange
SELECT * FROM history.ttime_history WHERE 
	date_trunc('minute', transaction_timestamp) >= '2015-01-12 15:45' AND 
	date_trunc('minute', transaction_timestamp) <= '2015-01-12 15:47' AND
	gid = 2
	ORDER BY gid, transaction_timestamp ASC;

-----------------------------------------------------------

-- valid time query (timestamp): timestamp EQUALS timestamp
SELECT DISTINCT ON (gid) * FROM history.vtime_history WHERE 
	date_trunc('day', yr_built_vt1) = '2014-10-01' 
	ORDER BY gid, transaction_timestamp DESC;

-- valid time query (timestamp): timestamp INSIDE timerange
SELECT DISTINCT ON (gid) * FROM history.vtime_history WHERE 
	yr_built_vt1 >= '2013-12-01' AND 
	yr_built_vt1 <= '2014-10-01' 
	ORDER BY gid, transaction_timestamp DESC;

-- valid time query (timerange): timerange EQUALS timerange
SELECT DISTINCT ON (gid) * FROM
	(SELECT *, count(gid) over (partition by gid) as count FROM history.vtime_history WHERE 
		date_trunc('day', yr_built_vt1) = '1995-06-01' AND yr_built_vt = 'BUILT' OR
		date_trunc('day', yr_built_vt1) = '2014-12-01' AND yr_built_vt = 'DESTR') a
	WHERE count = 2 ORDER BY gid, transaction_timestamp DESC; 

-- valid time query (timerange): timerange INSIDE timerange
SELECT DISTINCT ON (gid) * FROM
	(SELECT *, count(gid) over (partition by gid) as count FROM history.vtime_history WHERE 
		date_trunc('day', yr_built_vt1) >= '1995-06-01' AND yr_built_vt = 'BUILT' OR
		date_trunc('day', yr_built_vt1) <= '2014-12-01' AND yr_built_vt = 'DESTR') a
	WHERE count = 2 ORDER BY gid, transaction_timestamp DESC; 

-- valid time query (timerange): timerange INTERSECT timerange


------------------------------------------------------------------
------------ Example for "spatio-temporal queries" ---------------
------------------------------------------------------------------
-- This performs a spatio-temporal query that selects all the buildings that
-- Valid time: were modified in the year before the earthquake (between 2013-12-01 and 2014-12-01),
-- Spatial: are located inside a buffer of 50m to a street,
-- Attribute: that are of material type MR and
-- Transaction time: that got an information update within the last two weeḱs from the issue of the query.
SELECT DISTINCT ON (a.gid) a.* FROM history.vtime_history as a, public.streets_osm as b WHERE 
	a.yr_built_vt1 >= '2013-12-01' AND a.yr_built_vt1 <= '2014-12-01' AND a.yr_built_vt = 'MODIF' AND
	ST_INTERSECTS(ST_BUFFER(ST_TRANSFORM(b.the_geom,32632),50), ST_TRANSFORM(a.the_geom,32632)) IS TRUE AND
	a.mat_type = 'MR' AND
	a.transaction_timestamp > (timestamp 'now' - interval '1 week')
	ORDER BY a.gid, a.transaction_timestamp DESC;


---------------------------------------------------------------------------------
-------------------- Other temporal queries and useful functions ----------------
---------------------------------------------------------------------------------
-- See also: http://www.postgresql.org/docs/9.1/static/functions-datetime.html --
---------------------------------------------------------------------------------

-- Truncate timestamp to desired unit
SELECT date_trunc('minute', transaction_timestamp) FROM history.ttime_history; 

-- Convert timestamptz to timestamp
SELECT transaction_timestamp AT TIME ZONE 'UTC' FROM history.ttime_history;

-- Create input for time series visualisation with for example QGIS time manager plugin
-- note: plugin runs much faster with a table than with a view!
SELECT *, transaction_timestamp AT TIME ZONE 'UTC' AS transaction_timestamp_utc INTO public.ttime_history_t FROM history.ttime_history;
