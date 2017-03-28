------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------
-- Name: scenario_1_queries.sql
-- Date: 16.01.15
-- Author: M. Wieland
-- DBMS: PostgreSQL9.2 / PostGIS2.0 or higher
-- Description: Example queries for the fictious application scenario II: real-world changes and object life-cycle.
------------------------------------------------------------------------------------------------
------------------------------------------------------------------------------------------------

-- This gives the full transaction time history (all the logged changes) of a table/view and writes it to a view
SELECT * FROM history.ttime_gethistory('object_res1.ve_resolution1', 'history.ttime_history');

-- This gives the valid time history of a specified object primitive (only the real world changes - it gives the latest version of the object primitives at each real world change time)
SELECT * FROM history.vtime_gethistory('object_res1.ve_resolution1', 'history.vtime_history', 'yr_built_vt', 'yr_built_vt1');

----------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------

-- delete data and clean history
delete from object_res1.ve_resolution1;
delete from history.logged_actions;

-- deactivate logs for editable view
DROP TRIGGER IF EXISTS zhistory_trigger_row ON object_res1.ve_resolution1;
DROP TRIGGER IF EXISTS zhistory_trigger_row_modified ON history.logged_actions;
