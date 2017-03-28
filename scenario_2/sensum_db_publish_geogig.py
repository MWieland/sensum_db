'''
-----------------------------------------------------------------------------
    sensum_db_publish_geogig.py
-----------------------------------------------------------------------------                         
Created on 09.06.2015
Last modified on 09.06.2015
Author: Marc Wieland
Description: 
	- this script publishes the data and metadata tables of the sensum_db model
	  to geogig for versioning        
	- add files and commit changes to local geogig repository
Input:
    - a database that follows the sensum_db model with data (object_res1.v_resolution1_data)
      and metadata (object_res1.v_resolution1_metadata) views
    - an initiated geogig repository
Dependencies:
        - psycopg2
        - sensum_db model
----
'''
print(__doc__)

import os

# Parameters to set ########################################################################################################
host = 'localhost'
port = '5432'
dbname = 'db_paper_lifecycle'
user = 'postgres'
pw = 'postgres'
s_srs = '4326'	# source spatial reference system
geogig_local = '/media/datadrive_/documents/papers/Journal 2015 - LifecycleManagement_TOFINISH/scenario_geogig/'	# path to local git repository (should have a remote repo assigned)
############################################################################################################################

# escape strings for shell commands
def shellquote(s):
    return "'" + s.replace("'", "'\\''") + "'"

# TODO: test workflow and implement here
'''
# 1. import data from postgres database (single table):
geogig pg import --host localhost --port 5432 --schema object_res1 --database sensum_db_scenario --user postgres --password postgres --table v_resolution1_data

# 2. import data from postgres database (all tables):
geogig pg import --host localhost --port 5432 --schema object_res1 --database sensum_db_scenario --user postgres --password postgres --all

# 3. add to staging area
geogig add

# 4. commit changes
geogig commit -m "initial commit"
'''

# add file to local git repo
os.chdir(geogig_local)
com = 'git add *'
os.system(com)              
 
# commit changes
com = 'git commit -m "new ' + dbname + ' release"'
os.system(com)
