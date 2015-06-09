------------------------------------------------------------------
-- SCENARIO I: Database history and git release with versioning
------------------------------------------------------------------
-- description: tests the history and versioning for different database transactions
-- input: scenario_data.sql (three tables with data from earth observation, openstreetmap and cadastre)
-- author: Marc Wieland
-- last modified: 02.12.2014

-- preprocessing: make sure all input layers have the same srs and an index on the geometry for faster queries
alter table public.eo_cologne alter column the_geom type Geometry(Polygon, 4326) using st_transform(the_geom, 4326);
alter table public.osm_cologne alter column the_geom type Geometry(Polygon, 4326) using st_transform(the_geom, 4326);
alter table public.alk_cologne_subset alter column the_geom type Geometry(Polygon, 4326) using st_transform(the_geom, 4326);
--create index eo_cologne_idx on public.eo_cologne using gist (the_geom);
create index osm_cologne_idx on public.osm_cologne using gist (the_geom);
create index alk_cologne_idx on public.alk_cologne_subset using gist (the_geom);
create index main_idx on object_res1.main using gist (the_geom);

-- activate logs for editable view
select history.history_table('object_res1.ve_resolution1', 'true', 'false', '{res2_id, res3_id}'::text[]);

----------------------------------------------------------------------------------------------------------------

-- tt1: insert objects with geometry from EO tool results
insert into object_res1.ve_resolution1 (survey_gid, description, source, accuracy, the_geom) 
	select 1, 'building', 'EO', 73, the_geom from public.eo_cologne;

----------------------------------------------------------------------------------------------------------------
-- RELEASE 1: publish via github -> run "sensum_db_publish_git.py" to create a new release OR
--	      publish via geogig -> run "sensum_db_publish_geogig.py" to create a new release
----------------------------------------------------------------------------------------------------------------

-- tt2: update existing objects (where new and old intersect) with data from OSM
-- TODO: for real application improve matching criteria (intersects does not give a unique matching)
-- note: now the first intersecting object is updated in case of multiple intersections per object (the other intersecting objects are deleted)
update object_res1.ve_resolution1 set 
	survey_gid=2, 
	description='building',
	source='OSM',
	accuracy=85,
	the_geom=c.geom
	from (select distinct on (aid) a.gid as aid, b.gid as bid, a.the_geom as geom from public.osm_cologne a, object_res1.ve_resolution1 b 
		where st_intersects(a.the_geom, b.the_geom) group by a.gid, b.gid, a.the_geom order by a.gid) as c
	where gid=c.bid;
	
delete from object_res1.ve_resolution1 
	where gid in (select b.gid from public.osm_cologne a, object_res1.ve_resolution1 b where st_intersects(a.the_geom, b.the_geom)) and source!='OSM';

-- tt3: insert new objects (where no intersection between new and old) from OSM
-- note: insert into editable view takes ages (772353ms) compared to insert into table (718ms)
insert into object_res1.ve_resolution1 (survey_gid, description, source, accuracy, the_geom) 
	select * from (select 2, 'building', 'OSM', 85, the_geom from public.osm_cologne
		except select 2, 'building', 'OSM', 85, a.the_geom from public.osm_cologne a, object_res1.ve_resolution1 b 
			where st_equals(a.the_geom, b.the_geom)) c;

----------------------------------------------------------------------------------------------------------------
-- RELEASE 2: publish via github -> run "sensum_db_publish_git.py" to create a new release OR
--	      publish via geogig -> run "sensum_db_publish_geogig.py" to create a new release
----------------------------------------------------------------------------------------------------------------

-- tt4: update attributes of a random object with random values following RRVS data entry
update object_res1.ve_resolution1 set 
	mat_type=(select attribute_value from taxonomy.dic_attribute_value where attribute_type_code='MAT_TYPE' order by random() limit 1), 
	mat_tech=(select attribute_value from taxonomy.dic_attribute_value where attribute_type_code='MAT_TECH' order by random() limit 1), 
	mat_prop=(select attribute_value from taxonomy.dic_attribute_value where attribute_type_code='MAT_PROP' order by random() limit 1), 
	llrs=(select attribute_value from taxonomy.dic_attribute_value where attribute_type_code='LLRS' order by random() limit 1), 
	height='H', 
	height_1=(select trunc(random() * 99 + 1) from generate_series(1,15) limit 1), 
	occupy=(select attribute_value from taxonomy.dic_attribute_value where attribute_type_code='OCCUPY' order by random() limit 1), 
	occupy_dt=(select attribute_value from taxonomy.dic_attribute_value where attribute_type_code='OCCUPY_DT' order by random() limit 1), 
	mat_type_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 
	mat_tech_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 
	mat_prop_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 
	llrs_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 
	height_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 
	occupy_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 
	occupy_dt_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 
	mat_type_src='RRVS', mat_tech_src='RRVS', mat_prop_src='RRVS', llrs_src='RRVS', height_src='RRVS', occupy_src='RRVS', occupy_dt_src='RRVS'
	where gid=(select gid from object_res1.ve_resolution1 order by random() limit 1);

-- tt5: update existing objects with cadastral data (keep object attributes)
update object_res1.ve_resolution1 set 
	survey_gid=3, 
	description='building', 
	source='OF',
	accuracy=95,
	the_geom=c.geom
	from (select distinct on (aid) a.gid as aid, b.gid as bid, a.the_geom as geom from public.alk_cologne_subset a, object_res1.ve_resolution1 b 
		where st_intersects(a.the_geom, b.the_geom) group by a.gid, b.gid order by a.gid) as c
	where gid=c.bid;
	
delete from object_res1.ve_resolution1 
	where gid in (select b.gid from public.alk_cologne_subset a, object_res1.ve_resolution1 b where st_intersects(a.the_geom, b.the_geom)) and source!='OF';

-- tt6: insert new objects from cadastre (465299ms)
insert into object_res1.ve_resolution1 (survey_gid, description, source, accuracy, the_geom) 
	select * from (select 3, 'building', 'OF', 95, the_geom from public.alk_cologne_subset
		except select 3, 'building', 'OF', 95, a.the_geom from public.alk_cologne_subset a, object_res1.ve_resolution1 b 
			where st_equals(a.the_geom, b.the_geom)) c;

----------------------------------------------------------------------------------------------------------------
-- RELEASE 3: publish via github -> run "sensum_db_publish_git.py" to create a new release OR
--	      publish via geogig -> run "sensum_db_publish_geogig.py" to create a new release
----------------------------------------------------------------------------------------------------------------

-- This gives the full transaction time history (all the logged changes) of a table/view and writes it to a view
SELECT * FROM history.ttime_gethistory('object_res1.ve_resolution1', 'history.ttime_history');

-- Prepare input table for QGIS time manager
DROP TABLE IF EXISTS history.ttime_history_utc;
SELECT *, transaction_timestamp AT TIME ZONE 'UTC' AS transaction_timestamp_utc INTO history.ttime_history_utc FROM history.ttime_history;
ALTER TABLE history.ttime_history_utc ADD PRIMARY KEY (rowid);
CREATE INDEX ttime_history_utc_idx on history.ttime_history_utc using gist (the_geom);

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

-- delete data and clean history
delete from object_res1.ve_resolution1;
delete from history.logged_actions;

-- deactivate logs for editable view
DROP TRIGGER IF EXISTS zhistory_trigger_row ON object_res1.ve_resolution1;
DROP TRIGGER IF EXISTS zhistory_trigger_row_modified ON history.logged_actions;