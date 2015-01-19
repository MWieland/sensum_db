------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- Name: SENSUM multi-resolution database support
-- Version: 0.9.2
-- Date: 02.12.14
-- Author: M. Wieland
-- DBMS: PostgreSQL9.2 / PostGIS2.0
-- Description: Adds the multi-resolution support to the basic SENSUM data model.
--		1. Create editable views for three resolution levels with basic table structure
--		2. Auto-update resolution ids based on spatial join between resolution levels
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

-------------------------------------------
-- resolution 1 view (e.g. per-building) --
-------------------------------------------
CREATE OR REPLACE VIEW object_res1.ve_resolution1 AS
SELECT 
a.gid,
a.survey_gid,
a.description,
a.source,
a.accuracy,
a.res2_id,
a.res3_id,
a.the_geom,
b.object_id,
b.attribute_type_code,
b.attribute_value,
b.attribute_numeric_1,
b.attribute_numeric_2,
b.attribute_text_1,
c.detail_id,
c.qualifier_type_code,
c.qualifier_value,
c.qualifier_numeric_1,
c.qualifier_text_1,
c.qualifier_timestamp_1
FROM object_res1.main AS a
JOIN object_res1.main_detail AS b ON (a.gid = b.object_id)
JOIN object_res1.main_detail_qualifier AS c ON (b.gid = c.detail_id)
ORDER BY a.gid ASC;

--------------------------------------------
-- resolution 2 view (e.g. neighbourhood) --
--------------------------------------------
CREATE OR REPLACE VIEW object_res2.ve_resolution2 AS
SELECT 
a.gid,
a.survey_gid,
a.description,
a.source,
a.accuracy,
a.res3_id,
a.the_geom,
b.object_id,
b.attribute_type_code,
b.attribute_value,
b.attribute_numeric_1,
b.attribute_numeric_2,
b.attribute_text_1,
c.detail_id,
c.qualifier_type_code,
c.qualifier_value,
c.qualifier_numeric_1,
c.qualifier_text_1,
c.qualifier_timestamp_1
FROM object_res2.main AS a
JOIN object_res2.main_detail AS b ON (a.gid = b.object_id)
JOIN object_res2.main_detail_qualifier AS c ON (b.gid = c.detail_id)
ORDER BY a.gid ASC;

-----------------------------------------
-- resolution 3 view (e.g. settlement) --
-----------------------------------------
CREATE OR REPLACE VIEW object_res3.ve_resolution3 AS
SELECT 
a.gid,
a.survey_gid,
a.description,
a.source,
a.accuracy,
a.the_geom,
b.attribute_type_code,
b.attribute_value,
b.attribute_numeric_1,
b.attribute_numeric_2,
b.attribute_text_1,
c.detail_id,
c.qualifier_type_code,
c.qualifier_value,
c.qualifier_numeric_1,
c.qualifier_text_1,
c.qualifier_timestamp_1
FROM object_res3.main AS a
JOIN object_res3.main_detail AS b ON (a.gid = b.object_id)
JOIN object_res3.main_detail_qualifier AS c ON (b.gid = c.detail_id)
ORDER BY a.gid ASC;


-------------------------------------
-- make resolution 1 view editable --
-------------------------------------
CREATE OR REPLACE FUNCTION object_res1.edit_resolution_view()
RETURNS TRIGGER AS 
$BODY$
BEGIN
      IF TG_OP = 'INSERT' THEN
       INSERT INTO object_res1.main (gid, survey_gid, description, source, accuracy, res2_id, res3_id, the_geom) VALUES (DEFAULT, NEW.survey_gid, NEW.description, NEW. source, NEW.accuracy, NEW.res2_id, NEW.res3_id, NEW.the_geom);
       INSERT INTO object_res1.main_detail (object_id, attribute_type_code, attribute_value, attribute_numeric_1, attribute_numeric_2, attribute_text_1) VALUES ((SELECT max(gid) FROM object_res1.main), NEW.attribute_type_code, NEW.attribute_value, NEW.attribute_numeric_1, NEW.attribute_numeric_2, NEW.attribute_text_1);
       INSERT INTO object_res1.main_detail_qualifier (detail_id, qualifier_type_code, qualifier_value, qualifier_numeric_1, qualifier_text_1, qualifier_timestamp_1) VALUES ((SELECT max(gid) FROM object_res1.main_detail), NEW.qualifier_type_code, NEW.qualifier_value, NEW.qualifier_numeric_1, NEW.qualifier_text_1, NEW.qualifier_timestamp_1);
       RETURN NEW;
      ELSIF TG_OP = 'UPDATE' THEN
       UPDATE object_res1.main SET gid=NEW.gid, survey_gid=NEW.survey_gid, description=NEW.description, source=NEW.source, accuracy=NEW.accuracy, res2_id=NEW.res2_id, res3_id=NEW.res3_id, the_geom=NEW.the_geom WHERE gid=OLD.gid;
       UPDATE object_res1.main_detail SET attribute_type_code=NEW.attribute_type_code, attribute_value=NEW.attribute_value, attribute_numeric_1=NEW.attribute_numeric_1, attribute_numeric_2=NEW.attribute_numeric_2, attribute_text_1=NEW.attribute_text_1 WHERE object_id=OLD.gid;
       UPDATE object_res1.main_detail_qualifier SET qualifier_type_code=NEW.qualifier_type_code, qualifier_value=NEW.qualifier_value, qualifier_numeric_1=NEW.qualifier_numeric_1, qualifier_text_1=NEW.qualifier_text_1, qualifier_timestamp_1=NEW.qualifier_timestamp_1 WHERE detail_id=OLD.gid;
       RETURN NEW;
      ELSIF TG_OP = 'DELETE' THEN
       DELETE FROM object_res1.main_detail_qualifier WHERE detail_id IN (SELECT gid FROM object_res1.main_detail WHERE object_id=OLD.gid);
       DELETE FROM object_res1.main_detail WHERE object_id=OLD.gid;
       DELETE FROM object_res1.main WHERE gid=OLD.gid;
       --workaround to log row information after delete if transaction logging on view is active (because it is not possible to define a AFTER FOR EACH ROW trigger on a view)
       IF EXISTS (SELECT event_object_schema, trigger_name FROM information_schema.triggers WHERE event_object_schema = 'object_res1' AND trigger_name = 'zhistory_trigger_row') THEN
       	       INSERT INTO history.logged_actions VALUES(
	        NEXTVAL('history.logged_actions_gid_seq'),    -- gid
		TG_TABLE_SCHEMA::text,                        -- schema_name
		TG_TABLE_NAME::text,                          -- table_name
		TG_RELID,                                     -- relation OID for much quicker searches
		txid_current(),                               -- transaction_id
		session_user::text,                           -- transaction_user
		current_timestamp,                            -- transaction_time
		NULL,                              	      -- top-level query or queries (if multistatement) from client
		'D',					      -- transaction_type
		hstore(OLD.*), NULL, NULL);                   -- old_record, new_record, changed_fields
	END IF;
       RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$ 
LANGUAGE 'plpgsql';

COMMENT ON FUNCTION object_res1.edit_resolution_view() IS $body$
This function makes the resolution 1 view editable and forwards the edits to the underlying tables.
$body$;

DROP TRIGGER IF EXISTS res1_trigger ON object_res1.ve_resolution1;
CREATE TRIGGER res1_trigger
    INSTEAD OF INSERT OR UPDATE OR DELETE ON object_res1.ve_resolution1 
      FOR EACH ROW 
      EXECUTE PROCEDURE object_res1.edit_resolution_view();


-------------------------------------
-- make resolution 2 view editable --
-------------------------------------
CREATE OR REPLACE FUNCTION object_res2.edit_resolution_view()
RETURNS TRIGGER AS 
$BODY$
BEGIN
      IF TG_OP = 'INSERT' THEN
       INSERT INTO object_res2.main (gid, survey_gid, description, source, accuracy, res3_id, the_geom) VALUES (DEFAULT, NEW.survey_gid, NEW.description, NEW. source, NEW.accuracy, NEW.res3_id, NEW.the_geom);
       INSERT INTO object_res2.main_detail (object_id, attribute_type_code, attribute_value, attribute_numeric_1, attribute_numeric_2, attribute_text_1) VALUES ((SELECT max(gid) FROM object_res2.main), NEW.attribute_type_code, NEW.attribute_value, NEW.attribute_numeric_1, NEW.attribute_numeric_2, NEW.attribute_text_1);
       INSERT INTO object_res2.main_detail_qualifier (detail_id, qualifier_type_code, qualifier_value, qualifier_numeric_1, qualifier_text_1, qualifier_timestamp_1) VALUES ((SELECT max(gid) FROM object_res2.main_detail), NEW.qualifier_type_code, NEW.qualifier_value, NEW.qualifier_numeric_1, NEW.qualifier_text_1, NEW.qualifier_timestamp_1);
       RETURN NEW;
      ELSIF TG_OP = 'UPDATE' THEN
       UPDATE object_res2.main SET gid=NEW.gid, survey_gid=NEW.survey_gid, description=NEW.description, source=NEW.source, accuracy=NEW.accuracy, res3_id=NEW.res3_id, the_geom=NEW.the_geom WHERE gid=OLD.gid;
       UPDATE object_res2.main_detail SET attribute_type_code=NEW.attribute_type_code, attribute_value=NEW.attribute_value, attribute_numeric_1=NEW.attribute_numeric_1, attribute_numeric_2=NEW.attribute_numeric_2, attribute_text_1=NEW.attribute_text_1 WHERE object_id=OLD.gid;
       UPDATE object_res2.main_detail_qualifier SET qualifier_type_code=NEW.qualifier_type_code, qualifier_value=NEW.qualifier_value, qualifier_numeric_1=NEW.qualifier_numeric_1, qualifier_text_1=NEW.qualifier_text_1, qualifier_timestamp_1=NEW.qualifier_timestamp_1 WHERE detail_id=OLD.gid;
       RETURN NEW;
      ELSIF TG_OP = 'DELETE' THEN
       DELETE FROM object_res2.main_detail_qualifier WHERE detail_id IN (SELECT gid FROM object_res2.main_detail WHERE object_id=OLD.gid);
       DELETE FROM object_res2.main_detail WHERE object_id=OLD.gid;
       DELETE FROM object_res2.main WHERE gid=OLD.gid;
       --workaround to log row information after delete if transaction logging on view is active (because it is not possible to define a AFTER FOR EACH ROW trigger on a view)
       IF EXISTS (SELECT event_object_schema, trigger_name FROM information_schema.triggers WHERE event_object_schema = 'object_res2' AND trigger_name = 'zhistory_trigger_row') THEN
	       INSERT INTO history.logged_actions VALUES(
	        NEXTVAL('history.logged_actions_gid_seq'),    -- gid
		TG_TABLE_SCHEMA::text,                        -- schema_name
		TG_TABLE_NAME::text,                          -- table_name
		TG_RELID,                                     -- relation OID for much quicker searches
		txid_current(),                               -- transaction_id
		session_user::text,                           -- transaction_user
		current_timestamp,                            -- transaction_time
		NULL,                              	      -- top-level query or queries (if multistatement) from client
		'D',					      -- transaction_type
		hstore(OLD.*), NULL, NULL);                   -- old_record, new_record, changed_fields
	END IF;
       RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$ 
LANGUAGE 'plpgsql';

COMMENT ON FUNCTION object_res2.edit_resolution_view() IS $body$
This function makes the resolution 2 view editable and forwards the edits to the underlying tables.
$body$;

DROP TRIGGER IF EXISTS res2_trigger ON object_res2.ve_resolution2;
CREATE TRIGGER res2_trigger
    INSTEAD OF INSERT OR UPDATE OR DELETE ON object_res2.ve_resolution2 
      FOR EACH ROW 
      EXECUTE PROCEDURE object_res2.edit_resolution_view();

-------------------------------------
-- make resolution 3 view editable --
-------------------------------------
CREATE OR REPLACE FUNCTION object_res3.edit_resolution_view()
RETURNS TRIGGER AS 
$BODY$
BEGIN
      IF TG_OP = 'INSERT' THEN
       INSERT INTO object_res3.main (gid, survey_gid, description, source, accuracy, the_geom) VALUES (DEFAULT, NEW.survey_gid, NEW.description, NEW. source, NEW.accuracy, NEW.the_geom);
       INSERT INTO object_res3.main_detail (object_id, attribute_type_code, attribute_value, attribute_numeric_1, attribute_numeric_2, attribute_text_1) VALUES ((SELECT max(gid) FROM object_res3.main), NEW.attribute_type_code, NEW.attribute_value, NEW.attribute_numeric_1, NEW.attribute_numeric_2, NEW.attribute_text_1);
       INSERT INTO object_res3.main_detail_qualifier (detail_id, qualifier_type_code, qualifier_value, qualifier_numeric_1, qualifier_text_1, qualifier_timestamp_1) VALUES ((SELECT max(gid) FROM object_res3.main_detail), NEW.qualifier_type_code, NEW.qualifier_value, NEW.qualifier_numeric_1, NEW.qualifier_text_1, NEW.qualifier_timestamp_1);
       RETURN NEW;
      ELSIF TG_OP = 'UPDATE' THEN
       UPDATE object_res3.main SET gid=NEW.gid, survey_gid=NEW.survey_gid, description=NEW.description, source=NEW.source, accuracy=NEW.accuracy, the_geom=NEW.the_geom WHERE gid=OLD.gid;
       UPDATE object_res3.main_detail SET attribute_type_code=NEW.attribute_type_code, attribute_value=NEW.attribute_value, attribute_numeric_1=NEW.attribute_numeric_1, attribute_numeric_2=NEW.attribute_numeric_2, attribute_text_1=NEW.attribute_text_1 WHERE object_id=OLD.gid;
       UPDATE object_res3.main_detail_qualifier SET qualifier_type_code=NEW.qualifier_type_code, qualifier_value=NEW.qualifier_value, qualifier_numeric_1=NEW.qualifier_numeric_1, qualifier_text_1=NEW.qualifier_text_1, qualifier_timestamp_1=NEW.qualifier_timestamp_1 WHERE detail_id=OLD.gid;
       RETURN NEW;
      ELSIF TG_OP = 'DELETE' THEN
       DELETE FROM object_res3.main_detail_qualifier WHERE detail_id IN (SELECT gid FROM object_res3.main_detail WHERE object_id=OLD.gid);
       DELETE FROM object_res3.main_detail WHERE object_id=OLD.gid;
       DELETE FROM object_res3.main WHERE gid=OLD.gid;
       --workaround to log row information after delete if transaction logging on view is active (because it is not possible to define a AFTER FOR EACH ROW trigger on a view)
       IF EXISTS (SELECT event_object_schema, trigger_name FROM information_schema.triggers WHERE event_object_schema = 'object_res3' AND trigger_name = 'zhistory_trigger_row') THEN
	       INSERT INTO history.logged_actions VALUES(
	        NEXTVAL('history.logged_actions_gid_seq'),    -- gid
		TG_TABLE_SCHEMA::text,                        -- schema_name
		TG_TABLE_NAME::text,                          -- table_name
		TG_RELID,                                     -- relation OID for much quicker searches
		txid_current(),                               -- transaction_id
		session_user::text,                           -- transaction_user
		current_timestamp,                            -- transaction_time
		NULL,                              	      -- top-level query or queries (if multistatement) from client
		'D',					      -- transaction_type
		hstore(OLD.*), NULL, NULL);                   -- old_record, new_record, changed_fields
	END IF;
       RETURN NULL;
      END IF;
      RETURN NEW;
END;
$BODY$ 
LANGUAGE 'plpgsql';

COMMENT ON FUNCTION object_res3.edit_resolution_view() IS $body$
This function makes the resolution 3 view editable and forwards the edits to the underlying tables.
$body$;

DROP TRIGGER IF EXISTS res3_trigger ON object_res3.ve_resolution3;
CREATE TRIGGER res3_trigger
    INSTEAD OF INSERT OR UPDATE OR DELETE ON object_res3.ve_resolution3 
      FOR EACH ROW 
      EXECUTE PROCEDURE object_res3.edit_resolution_view();


-----------------------------------------------------------------------------------------
-- Link resolutions: Update once the resolution_ids in case some records already exist --
-----------------------------------------------------------------------------------------
-- Update res2_ids for resolution1 records based on spatial join
UPDATE object_res1.main SET res2_id=a.res2_id 
  FROM (SELECT res2.gid AS res2_id, res1.gid AS res1_id FROM (SELECT gid, the_geom FROM object_res1.main) res1 
    LEFT JOIN (SELECT gid, the_geom FROM object_res2.main) res2 
    ON ST_Contains(res2.the_geom, (SELECT ST_PointOnSurface(res1.the_geom)))) AS a
WHERE object_res1.main.gid=a.res1_id;

-- Update res3_ids for resolution1 records based on spatial join
UPDATE object_res1.main SET res3_id=a.res3_id 
  FROM (SELECT res3.gid AS res3_id, res1.gid AS res1_id FROM (SELECT gid, the_geom FROM object_res1.main) res1
    LEFT JOIN (SELECT gid, the_geom FROM object_res3.main) res3 
    ON ST_Contains(res3.the_geom, (SELECT ST_PointOnSurface(res1.the_geom)))) AS a
WHERE object_res1.main.gid=a.res1_id;

-- Update res3_ids for resolution2 records based on spatial join
UPDATE object_res2.main SET res3_id=a.res3_id 
  FROM (SELECT res3.gid AS res3_id, res2.gid AS res2_id FROM (SELECT gid, the_geom FROM object_res2.main) res2
    LEFT JOIN (SELECT gid, the_geom FROM object_res3.main) res3 
    ON ST_Contains(res3.the_geom, (SELECT ST_PointOnSurface(res2.the_geom)))) AS a
WHERE object_res2.main.gid=a.res2_id;


-----------------------------------------------------------------------------------------
-- Link resolutions: Update resolution_ids on INSERT and UPDATE (main.the_geom) --
-----------------------------------------------------------------------------------------
-- Trigger function and trigger to update resolution_ids for each INSERT and UPDATE OF the_geom ON object_res1.main
CREATE OR REPLACE FUNCTION object_res1.update_resolution_ids() 
RETURNS TRIGGER AS
$BODY$
BEGIN 
     IF TG_OP = 'INSERT' OR TG_OP = 'UPDATE' THEN	
	-- Update res2_ids for resolution1 records based on spatial join
	UPDATE object_res1.main SET res2_id=a.res2_id 
	  FROM (SELECT res2.gid AS res2_id, res1.gid AS res1_id FROM (SELECT gid, res2_id, res3_id, the_geom FROM object_res1.main) res1 
	    LEFT JOIN (SELECT gid, the_geom FROM object_res2.main) res2 
	    ON ST_Contains(res2.the_geom, (SELECT ST_PointOnSurface(res1.the_geom))) 
		WHERE res1.gid=NEW.gid	-- if resolution1 record is updated
		OR res1.res2_id=NEW.gid	-- if resolution2 record is updated
		OR res1.res3_id=NEW.gid	-- if resolution3 record is updated
		OR ST_Intersects(res1.the_geom, NEW.the_geom)	-- update ids also for resolution1 records that intersect with the newly updated resolution2 or resolution3 records
		) AS a
	WHERE object_res1.main.gid=a.res1_id OR object_res1.main.gid=NEW.gid;

	-- Update res3_ids for resolution1 records based on spatial join
	UPDATE object_res1.main SET res3_id=a.res3_id 
	  FROM (SELECT res3.gid AS res3_id, res1.gid AS res1_id FROM (SELECT gid, res2_id, res3_id, the_geom FROM object_res1.main) res1
	    LEFT JOIN (SELECT gid, the_geom FROM object_res3.main) res3 
	    ON ST_Contains(res3.the_geom, (SELECT ST_PointOnSurface(res1.the_geom))) 
		WHERE res1.gid=NEW.gid 
		OR res1.res2_id=NEW.gid 
		OR res1.res3_id=NEW.gid 
		OR ST_Intersects(res1.the_geom, NEW.the_geom)
		) AS a
	WHERE object_res1.main.gid=a.res1_id OR object_res1.main.gid=NEW.gid;

	-- Update res3_ids for resolution2 records based on spatial join
	UPDATE object_res2.main SET res3_id=a.res3_id 
	  FROM (SELECT res3.gid AS res3_id, res2.gid AS res2_id FROM (SELECT gid, res3_id, the_geom FROM object_res2.main) res2
	    LEFT JOIN (SELECT gid, the_geom FROM object_res3.main) res3 
	    ON ST_Contains(res3.the_geom, (SELECT ST_PointOnSurface(res2.the_geom))) 
		WHERE res2.gid=NEW.gid 
		OR res2.res3_id=NEW.gid 
		OR ST_Intersects(res2.the_geom, NEW.the_geom)
		) AS a
	WHERE object_res2.main.gid=a.res2_id OR object_res2.main.gid=NEW.gid;
	
     RETURN NEW;

     ELSIF TG_OP = 'DELETE' THEN
	-- Update res2_ids for resolution1 records based on spatial join
	UPDATE object_res1.main SET res2_id=a.res2_id 
	  FROM (SELECT res2.gid AS res2_id, res1.gid AS res1_id FROM (SELECT gid, res2_id, res3_id, the_geom FROM object_res1.main) res1 
	    LEFT JOIN (SELECT gid, the_geom FROM object_res2.main) res2 
	    ON ST_Contains(res2.the_geom, (SELECT ST_PointOnSurface(res1.the_geom))) 
		WHERE res1.res2_id=OLD.gid	-- if resolution2 record is deleted
		OR res1.res3_id=OLD.gid	-- if resolution3 record is deleted
		) AS a
	WHERE object_res1.main.gid=a.res1_id;

	-- Update res3_ids for resolution1 records based on spatial join
	UPDATE object_res1.main SET res3_id=a.res3_id 
	  FROM (SELECT res3.gid AS res3_id, res1.gid AS res1_id FROM (SELECT gid, res2_id, res3_id, the_geom FROM object_res1.main) res1
	    LEFT JOIN (SELECT gid, the_geom FROM object_res3.main) res3 
	    ON ST_Contains(res3.the_geom, (SELECT ST_PointOnSurface(res1.the_geom))) 
		WHERE res1.res2_id=OLD.gid 
		OR res1.res3_id=OLD.gid
		) AS a
	WHERE object_res1.main.gid=a.res1_id;

	-- Update res3_ids for resolution2 records based on spatial join
	UPDATE object_res2.main SET res3_id=a.res3_id 
	  FROM (SELECT res3.gid AS res3_id, res2.gid AS res2_id FROM (SELECT gid, res3_id, the_geom FROM object_res2.main) res2
	    LEFT JOIN (SELECT gid, the_geom FROM object_res3.main) res3 
	    ON ST_Contains(res3.the_geom, (SELECT ST_PointOnSurface(res2.the_geom))) 
		WHERE res2.gid=OLD.gid 
		OR res2.res3_id=OLD.gid 
		OR ST_Intersects(res2.the_geom, OLD.the_geom)
		) AS a
	WHERE object_res2.main.gid=a.res2_id;
     
     RETURN NULL;

     END IF;
     RETURN NEW;
END;
$BODY$
LANGUAGE 'plpgsql';

COMMENT ON FUNCTION object_res1.update_resolution_ids() IS $body$
This function updates the resolution_ids for an object when its geometry is updated or an object is inserted or deleted.
$body$;

DROP TRIGGER IF EXISTS resolution_id_trigger ON object_res1.main;
CREATE TRIGGER resolution_id_trigger
    AFTER INSERT OR UPDATE OF the_geom ON object_res1.main 
      FOR EACH ROW 
      WHEN (pg_trigger_depth() = 1)	-- current nesting level of trigger (1 if called once from inside a trigger)
      EXECUTE PROCEDURE object_res1.update_resolution_ids();

DROP TRIGGER IF EXISTS resolution_id_trigger_del ON object_res1.main;
CREATE TRIGGER resolution_id_trigger_del
    AFTER DELETE ON object_res1.main 
      FOR EACH ROW 
      WHEN (pg_trigger_depth() = 1)	-- current nesting level of trigger (1 if called once from inside a trigger)
      EXECUTE PROCEDURE object_res1.update_resolution_ids();

DROP TRIGGER IF EXISTS resolution_id_trigger ON object_res2.main;
CREATE TRIGGER resolution_id_trigger
    AFTER INSERT OR UPDATE OF the_geom ON object_res2.main 
      FOR EACH ROW 
      WHEN (pg_trigger_depth() = 1)	-- current nesting level of trigger (1 if called once from inside a trigger)
      EXECUTE PROCEDURE object_res1.update_resolution_ids();

DROP TRIGGER IF EXISTS resolution_id_trigger_del ON object_res2.main;
CREATE TRIGGER resolution_id_trigger_del
    AFTER DELETE ON object_res2.main 
      FOR EACH ROW 
      WHEN (pg_trigger_depth() = 1)	-- current nesting level of trigger (1 if called once from inside a trigger)
      EXECUTE PROCEDURE object_res1.update_resolution_ids();

DROP TRIGGER IF EXISTS resolution_id_trigger ON object_res3.main;
CREATE TRIGGER resolution_id_trigger
    AFTER INSERT OR UPDATE OF the_geom ON object_res3.main 
      FOR EACH ROW 
      WHEN (pg_trigger_depth() = 1)	-- current nesting level of trigger (1 if called once from inside a trigger)
      EXECUTE PROCEDURE object_res1.update_resolution_ids();

DROP TRIGGER IF EXISTS resolution_id_trigger_del ON object_res3.main;
CREATE TRIGGER resolution_id_trigger_del
    AFTER DELETE ON object_res3.main 
      FOR EACH ROW 
      WHEN (pg_trigger_depth() = 1)	-- current nesting level of trigger (1 if called once from inside a trigger)
      EXECUTE PROCEDURE object_res1.update_resolution_ids();
