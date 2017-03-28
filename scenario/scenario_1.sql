------------------------------------------------------------------
-- SCENARIO: Paper IJGIS database model
------------------------------------------------------------------
-- description: application scenario for paper in IJGIS
-- input: scenario_data.sql
-- author: Marc Wieland
-- last modified: 16.01.2015

-- activate logs for editable view
select history.history_table('object_res1.ve_resolution1', 'true', 'false', '{res2_id, res3_id}'::text[]);

----------------------------------------------------------------------------------------------------------------
-- CREATE TIMELINE OF EVENTS
----------------------------------------------------------------------------------------------------------------

-- tt0: populate database - insert 500 objects with geometry (from OSM of a random town) and attributes (from RRVS of Bishkek)
insert into object_res1.ve_resolution1 (
  gid,
  survey_gid,
  description,
  source,
  res2_id,
  res3_id,
  the_geom,
  object_id,
  mat_type,
  mat_tech,
  mat_prop,
  llrs,
  llrs_duct,
  height,
  yr_built,
  "position",
  plan_shape,
  str_irreg,
  str_irreg_dt,
  str_irreg_type,
  nonstrcexw,
  roof_shape,
  roofcovmat,
  roofsysmat,
  roofsystyp,
  roof_conn,
  floor_mat,
  floor_type,
  floor_conn,
  foundn_sys,
  build_type,
  build_subtype,
  vuln,
  vuln_1,
  vuln_2,
  height_1,
  height_2,
  object_id1,
  mat_type_bp,
  mat_tech_bp,
  mat_prop_bp,
  llrs_bp,
  llrs_duct_bp,
  height_bp,
  yr_built_bp,
  position_bp,
  plan_shape_bp,
  str_irreg_bp,
  str_irreg_dt_bp,
  str_irreg_type_bp,
  nonstrcexw_bp,
  roof_shape_bp,
  roofcovmat_bp,
  roofsysmat_bp,
  roofsystyp_bp,
  roof_conn_bp,
  floor_mat_bp,
  floor_type_bp,
  floor_conn_bp,
  foundn_sys_bp,
  build_type_bp,
  build_subtype_bp,
  vuln_bp,
  yr_built_vt,
  yr_built_vt1,
  mat_type_src,
  mat_tech_src,
  mat_prop_src,
  llrs_src,
  llrs_duct_src,
  height_src,
  yr_built_src,
  str_irreg_src,
  str_irreg_dt_src,
  str_irreg_type_src,
  roofsystyp_src,
  floor_mat_src,
  floor_type_src,
  build_type_src,
  vuln_src,
  accuracy
) select 
  gid,
  survey_gid,
  description,
  source,
  resolution2_id,
  resolution3_id,
  the_geom,
  object_id,
  mat_type,
  mat_tech,
  mat_prop,
  llrs,
  llrs_duct,
  height,
  yr_built,
  "position",
  plan_shape,
  str_irreg,
  str_irreg_dt,
  str_irreg_type,
  nonstrcexw,
  roof_shape,
  roofcovmat,
  roofsysmat,
  roofsystyp,
  roof_conn,
  floor_mat,
  floor_type,
  floor_conn,
  foundn_sys,
  build_type,
  build_subtype,
  vuln,
  vuln_1,
  vuln_2,
  height_1,
  height_2,
  object_id1,
  mat_type_bp,
  mat_tech_bp,
  mat_prop_bp,
  llrs_bp,
  llrs_duct_bp,
  height_bp,
  yr_built_bp,
  position_bp,
  plan_shape_bp,
  str_irreg_bp,
  str_irreg_dt_bp,
  str_irreg_type_bp,
  nonstrcexw_bp,
  roof_shape_bp,
  roofcovmat_bp,
  roofsysmat_bp,
  roofsystyp_bp,
  roof_conn_bp,
  floor_mat_bp,
  floor_type_bp,
  floor_conn_bp,
  foundn_sys_bp,
  build_type_bp,
  build_subtype_bp,
  vuln_bp,
  yr_built_vt,
  yr_built_vt1,
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  'RRVS',
  85
from scenario_town;

----------------------------------------------------------------------------------------------------------------

-- tt1/vt0: retrofitting - 50 buildings are retrofitted (RVS)
update object_res1.ve_resolution1 set 
	survey_gid=2,
	yr_built_vt='MODIF', 
	yr_built_vt1='2014-06-01 00:00:00',
	yr_built_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1),
	yr_built_src='RVS',
	mat_type='MR',
	mat_type_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1),
	mat_type_src='RVS',
	mat_tech='RCM', --fibre reinforcing mesh (often used for retrofitting of masonry)
	mat_tech_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1),
	mat_tech_src='RVS'
	from (select gid as id from object_res1.ve_resolution1 
		where gid in (select gid from object_res1.ve_resolution1 where mat_type='MUR' order by random() limit 50)) a
	where gid = a.id;
	
----------------------------------------------------------------------------------------------------------------

-- tt2/vt1: modification - 20 buildings are modified by owners (RVS)
update object_res1.ve_resolution1 set 
	survey_gid=3,
	yr_built_vt='MODIF', 
	yr_built_vt1='2014-10-01 00:00:00',
	yr_built_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1),
	yr_built_src='RVS',
	height_1=height_1+1,	--add another storey
	height_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1),
	height_src='RVS'
	from (select gid as id from object_res1.ve_resolution1 
		where gid in (select gid from object_res1.ve_resolution1 where yr_built_vt!='MODIF' order by random() limit 20)) a
	where gid = a.id;

----------------------------------------------------------------------------------------------------------------

-- tt3: information update - information about the occupancy of buildings becomes available (OF - Census)
update object_res1.ve_resolution1 set 
	occupy=a.occupy, 
	occupy_bp=a.occupy_bp,
	occupy_src='OF',
	occupy_dt=a.occupy_dt,
	occupy_dt_bp=a.occupy_dt_bp,
	occupy_dt_src='OF'
	from (select gid as id, occupy, occupy_bp, occupy_dt, occupy_dt_bp from scenario_town) a
	where gid = a.id;

----------------------------------------------------------------------------------------------------------------

-- tt4/vt2: destruction - an earthquake occurs and destroys 125 buildings (total collapses) (RVS - 1st damage survey)
update object_res1.ve_resolution1 set 
	survey_gid=4,
	yr_built_vt='DESTR', 
	yr_built_vt1='2014-12-01 01:00:00',
	yr_built_bp=100,
	yr_built_src='RVS'
	from (select gid as id from object_res1.ve_resolution1 where vuln_1=1 order by random() limit 125) a
	where gid = a.id;
delete from object_res1.ve_resolution1 where yr_built_vt='DESTR';

----------------------------------------------------------------------------------------------------------------

-- tt5: information update - information about the damage grades of 200 (not totally collapsed) buildings becomes available (RVS - 2nd damage survey)
-- TODO: adjust so that for each update object a new random damage grade is assigned (currently only the same for all buildings)
update object_res1.ve_resolution1 set
	yr_built_vt='MODIF', 
	yr_built_vt1='2014-12-01 01:00:00',
	yr_built_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1),
	yr_built_src='RVS',
	damage='DAMAGE_EX',
	damage_1=(select trunc(random() * 5 + 1) from generate_series(1,5) limit 1),
	damage_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1),
	damage_src='RVS'
	from (select gid as id from object_res1.ve_resolution1 
		where gid in (select gid from object_res1.ve_resolution1 order by random() limit 200)) a
	where gid = a.id;

----------------------------------------------------------------------------------------------------------------

-- tt6/vt3: shelters build - 100 temporary shelters are constructed (RS)
insert into object_res1.ve_resolution1 (survey_gid, description, yr_built, yr_built_bp, yr_built_vt, yr_built_vt1, yr_built_src, the_geom) select 
	5, 'shelter', 'YAPP', 75, 'BUILT', '2014-12-10 01:00:00', 'RS', the_geom from camp_osm;

----------------------------------------------------------------------------------------------------------------

-- tt7/vt4: reconstruction - 95 new buildings are constructed (RS)
insert into object_res1.ve_resolution1 (survey_gid, description, yr_built, yr_built_bp, yr_built_vt, yr_built_vt1, yr_built_src, the_geom) select 
	6, 'building', 'YAPP', 80, 'BUILT', '2015-10-15 01:00:00', 'RS', the_geom from newconstruction_osm;

----------------------------------------------------------------------------------------------------------------

-- tt8/vt5: shelters remove - temporary shelters are removed (RS)
update object_res1.ve_resolution1 set 
	survey_gid=7,
	yr_built_vt='DESTR', 
	yr_built_vt1='2016-05-01 01:00:00',
	yr_built_bp=75,
	yr_built_src='RS'
	from (select gid as id from object_res1.ve_resolution1 where description='shelter') a
	where gid = a.id;
delete from object_res1.ve_resolution1 where yr_built_vt='DESTR';

----------------------------------------------------------------------------------------------------------------
-- QUERY EXAMPLES
----------------------------------------------------------------------------------------------------------------

-- This gives the transaction time history (all the logged changes) of a table/view and writes it to a view
SELECT * FROM history.ttime_gethistory('object_res1.ve_resolution1', 'history.ttime_history');

-- Prepare input table for QGIS time manager
DROP TABLE IF EXISTS history.ttime_history_utc;
SELECT *, transaction_timestamp AT TIME ZONE 'UTC' AS transaction_timestamp_utc INTO history.ttime_history_utc FROM history.ttime_history;
ALTER TABLE history.ttime_history_utc ADD PRIMARY KEY (rowid);
CREATE INDEX ttime_history_utc_idx on history.ttime_history_utc using gist (the_geom);

----------------------------------------------------------------------------------------------------------------

-- This gives the valid time history (only the real world changes - it gives the latest version of the object primitives at each real world change time) of a table/view and writes it to a view
SELECT * FROM history.vtime_gethistory('object_res1.ve_resolution1', 'history.vtime_history', 'yr_built_vt', 'yr_built_vt1');

-- Prepare input table for QGIS time manager
DROP TABLE IF EXISTS history.vtime_history_utc;
SELECT *, yr_built_vt1 AT TIME ZONE 'UTC' AS yr_built_vt1_utc INTO history.vtime_history_utc FROM history.vtime_history;
ALTER TABLE history.vtime_history_utc ADD PRIMARY KEY (rowid);
CREATE INDEX vtime_history_utc_idx on history.vtime_history_utc using gist (the_geom);

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

-- aggregate resolution 1 data to resolution 3 zones


----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

-- delete data and clean history
delete from object_res1.ve_resolution1;
delete from history.logged_actions;

-- deactivate logs for editable view
DROP TRIGGER IF EXISTS zhistory_trigger_row ON object_res1.ve_resolution1;
DROP TRIGGER IF EXISTS zhistory_trigger_row_modified ON history.logged_actions;