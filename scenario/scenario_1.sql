------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- Name: scenario_1.sql
-- Date: 16.01.15
-- Author: M. Wieland
-- DBMS: PostgreSQL9.2 / PostGIS2.0 or higher
-- Description: Run fictious application scenario I: information integration and value updating.
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

-- preprocessing: make sure all input layers have the same srs and an index on the geometry for faster queries
alter table public.eo_cl alter column the_geom type Geometry(Polygon, 4326) using st_transform(the_geom, 4326);
alter table public.osm_cl alter column the_geom type Geometry(Polygon, 4326) using st_transform(the_geom, 4326);
alter table public.alk_cl_subset alter column the_geom type Geometry(Polygon, 4326) using st_transform(the_geom, 4326);
--create index eo_cl_idx on public.eo_cl using gist (the_geom);
create index if not exists osm_cl_idx on public.osm_cl using gist (the_geom);
create index if not exists alk_cl_idx on public.alk_cl_subset using gist (the_geom);
create index if not exists main_idx on object_res1.main using gist (the_geom);

-- activate logs for editable view
select history.history_table('object_res1.ve_resolution1', 'true', 'false', '{res2_id, res3_id}'::text[]);

----------------------------------------------------------------------------------------------------------------

-- tt1: insert objects with geometry from EO tool results
insert into object_res1.ve_resolution1 (survey_gid, description, source, accuracy, the_geom) 
	select 1, 'building', 'EO', 73, the_geom from public.eo_cl;

----------------------------------------------------------------------------------------------------------------
-- RELEASE 1: publish via github or geogig to create a new release
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
	from (select distinct on (aid) a.gid as aid, b.gid as bid, a.the_geom as geom from public.osm_cl a, object_res1.ve_resolution1 b 
		where st_intersects(a.the_geom, b.the_geom) group by a.gid, b.gid, a.the_geom order by a.gid) as c
	where gid=c.bid;
	
delete from object_res1.ve_resolution1 
	where gid in (select b.gid from public.osm_cl a, object_res1.ve_resolution1 b where st_intersects(a.the_geom, b.the_geom)) and source!='OSM';

-- tt3: insert new objects (where no intersection between new and old) from OSM
-- note: insert into editable view takes ages (772353ms) compared to insert into table (718ms)
insert into object_res1.ve_resolution1 (survey_gid, description, source, accuracy, the_geom) 
	select * from (select 2, 'building', 'OSM', 85, the_geom from public.osm_cl
		except select 2, 'building', 'OSM', 85, a.the_geom from public.osm_cl a, object_res1.ve_resolution1 b 
			where st_equals(a.the_geom, b.the_geom)) c;

----------------------------------------------------------------------------------------------------------------
-- RELEASE 2: publish via github or geogig to create a new release
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
	from (select distinct on (aid) a.gid as aid, b.gid as bid, a.the_geom as geom from public.alk_cl_subset a, object_res1.ve_resolution1 b 
		where st_intersects(a.the_geom, b.the_geom) group by a.gid, b.gid order by a.gid) as c
	where gid=c.bid;
	
delete from object_res1.ve_resolution1 
	where gid in (select b.gid from public.alk_cl_subset a, object_res1.ve_resolution1 b where st_intersects(a.the_geom, b.the_geom)) and source!='OF';

-- tt6: insert new objects from cadastre (465299ms)
insert into object_res1.ve_resolution1 (survey_gid, description, source, accuracy, the_geom) 
	select * from (select 3, 'building', 'OF', 95, the_geom from public.alk_cl_subset
		except select 3, 'building', 'OF', 95, a.the_geom from public.alk_cl_subset a, object_res1.ve_resolution1 b 
			where st_equals(a.the_geom, b.the_geom)) c;

----------------------------------------------------------------------------------------------------------------
-- RELEASE 3: publish via github or geogig to create a new release
----------------------------------------------------------------------------------------------------------------

-- preprocessing: update scenario I results with random construction dates
update object_res1.ve_resolution1 set 
	yr_built='YAPP',
	yr_built_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 
	yr_built_vt='BUILT',
	yr_built_vt1=a.time
	from (select gid as id, (timestamp '1990-01-01 01:00:00' + random() * (timestamp '2010-05-30 01:00:00' - timestamp '1990-01-01 01:00:00')) as time 
			from object_res1.ve_resolution1 where gid in (select gid from object_res1.ve_resolution1)) a
	where gid = a.id;
	
----------------------------------------------------------------------------------------------------------------
-- RELEASE 4: publish on github -> run "sensum_db_publish.py" to create a new release
----------------------------------------------------------------------------------------------------------------

-- vt1: update some of the objects with construction dates cause of a real world modification: 1. mark the object change type as 'MODIF'; 2. set the date of modification; 3. update it
update object_res1.ve_resolution1 set 
	yr_built_bp=(select trunc(random() * 99 + 1) from generate_series(1,100) limit 1),
	yr_built_vt='MODIF', 
	yr_built_vt1=a.time,
	
	from (select gid as id, (timestamp '2010-05-30 01:00:00' + random() * (timestamp '2014-12-01 01:00:00' - timestamp '2010-05-30 01:00:00')) as time 
			from object_res1.ve_resolution1 where gid in (select gid from object_res1.ve_resolution1 where yr_built_vt='BUILT') order by random() limit 400) a
	where gid = a.id;

----------------------------------------------------------------------------------------------------------------
-- RELEASE 5: publish on github -> run "sensum_db_publish.py" to create a new release
----------------------------------------------------------------------------------------------------------------

-- vt2: delete objects cause of a real world destruction: 1. mark the object change type as 'DESTR'; 2. set the date of destruction; 3. delete it
update object_res1.ve_resolution1 set 
	yr_built_vt='DESTR', 
	yr_built_vt1='2014-12-02 01:00:00'
	from (select gid as id from object_res1.ve_resolution1 order by random() limit 100) a
	where gid = a.id;
delete from object_res1.ve_resolution1 where yr_built_vt='DESTR';

----------------------------------------------------------------------------------------------------------------
-- RELEASE 6: publish on github -> run "sensum_db_publish.py" to create a new release
----------------------------------------------------------------------------------------------------------------

-- vt3: insert some objects cause of a real world construction: 1. mark the object change type as 'BUILT'; 2. set the date of construction; 3. insert it
-- TODO: get geometry for these objects!!!
insert into object_res1.ve_resolution1 (survey_gid, description, yr_built, yr_built_bp, yr_built_vt, yr_built_vt1) values 
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014'),
	(1, 'building', 'YAPP', (select trunc(random() * 99 + 1) from generate_series(1,100) limit 1), 'BUILT', '12-02-2014');

----------------------------------------------------------------------------------------------------------------
-- RELEASE 7: publish on github -> run "sensum_db_publish.py" to create a new release
----------------------------------------------------------------------------------------------------------------
