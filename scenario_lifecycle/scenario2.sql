-------------------------------------------------
-- SCENARIO II: Tracking of real-world changes
------------------------------------------------
-- author: Marc Wieland
-- last modified: 02.12.2014

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

-- This gives the valid time history of a specified object primitive (only the real world changes - it gives the latest version of the object primitives at each real world change time)
SELECT * FROM history.vtime_gethistory('object_res1.ve_resolution1', 'history.vtime_history', 'yr_built_vt', 'yr_built_vt1');

-- Prepare input table for QGIS time manager
DROP TABLE IF EXISTS history.vtime_history_utc;
SELECT *, yr_built_vt1 AT TIME ZONE 'UTC' AS yr_built_vt1_utc INTO history.vtime_history_utc FROM history.vtime_history;
ALTER TABLE history.vtime_history_utc ADD PRIMARY KEY (rowid);
CREATE INDEX vtime_history_utc_idx on history.vtime_history_utc using gist (the_geom);

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

-- delete data and clean history
delete from object_res1.ve_resolution1;
delete from history.logged_actions;

-- deactivate logs for editable view
DROP TRIGGER IF EXISTS zhistory_trigger_row ON object_res1.ve_resolution1;
DROP TRIGGER IF EXISTS zhistory_trigger_row_modified ON history.logged_actions;