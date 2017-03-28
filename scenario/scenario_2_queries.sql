------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- Name: scenario_2_queries.sql
-- Date: 16.01.15
-- Author: M. Wieland
-- DBMS: PostgreSQL9.2 / PostGIS2.0 or higher
-- Description: Example queries for the fictious application scenario II: real-world changes and object life-cycle.
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

-- This gives the transaction time history (all the logged changes) of a table/view and writes it to a view
SELECT * FROM history.ttime_gethistory('object_res1.ve_resolution1', 'history.ttime_history');

----------------------------------------------------------------------------------------------------------------

-- This gives the valid time history (only the real world changes - it gives the latest version of the object primitives at each real world change time) of a table/view and writes it to a view
SELECT * FROM history.vtime_gethistory('object_res1.ve_resolution1', 'history.vtime_history', 'yr_built_vt', 'yr_built_vt1');

----------------------------------------------------------------------------------------------------------------

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

----------------------------------------------------------------------------------------------------------------
-- EXAMPLE OF MULTI-RESOLUTION SUPPORT
----------------------------------------------------------------------------------------------------------------

-- create resolution 2 representation (generalization of resolution 1)
INSERT INTO object_res2.ve_resolution2 (the_geom) SELECT ST_SimplifyPreserveTopology(the_geom,0.00001) AS the_geom FROM 
	-- multipart to singlepart
	(SELECT (ST_Dump(the_geom)).geom AS the_geom FROM 
	-- union
	(SELECT ST_Union(the_geom) AS the_geom FROM 
	-- remove interior rings of polygons
	(SELECT ST_MakePolygon(ST_ExteriorRing(ST_SimplifyPreserveTopology(the_geom,0))) AS the_geom
	FROM object_res1.ve_resolution1) a
	) b) c;
-- remove small polygons
DELETE FROM object_res2.ve_resolution2 WHERE ST_Area(ST_TRANSFORM(the_geom,32632)) < 10;

-- create resolution 3 representation (load external zonation)
INSERT INTO object_res3.ve_resolution3 (gid, the_geom) 
	SELECT gid, the_geom FROM resolution3_zonation;

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

-- delete data and clean history
delete from object_res1.ve_resolution1;
delete from history.logged_actions;

-- deactivate logs for editable view
DROP TRIGGER IF EXISTS zhistory_trigger_row ON object_res1.ve_resolution1;
DROP TRIGGER IF EXISTS zhistory_trigger_row_modified ON history.logged_actions;
