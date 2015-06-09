'''
-----------------------------------------------------------------------------
    sensum_db_publish.py
-----------------------------------------------------------------------------                         
Created on 26.11.2014
Last modified on 01.12.2014
Author: Marc Wieland
Description: 
	- this script publishes the data and metadata tables of the sensum_db model
	  to github for versioning        
	- dump database views of sensum_db model to geojson and csv 
	- add files and commit changes to local git repository
	- push changes to remote git repository
Input:
    - a database that follows the sensum_db model with data (object_res1.v_resolution1_data)
      and metadata (object_res1.v_resolution1_metadata) views
    - an initiated local git repository with added remote repository
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
dbname = 'sensum_db_scenario'
user = 'postgres'
pw = '****'
s_srs = '4326'	# source spatial reference system
git_local = 'PATH_TO_LOCAL_GIT_REPO/'	# path to local git repository (should have a remote repo assigned)
############################################################################################################################

# delete existing files
if os.path.exists(git_local + 'v_resolution1_data.geojson'):
    com = 'sudo rm ' + git_local + 'v_resolution1_data.geojson'
    os.system(com)

if os.path.exists(git_local + 'v_resolution1_metadata.csv'):
    com = 'sudo rm ' + git_local + 'v_resolution1_metadata.csv'
    os.system(com)

# get source srs of table

# dump data to geojson with specified source and target spatial reference system (4326 - WGS84)
com = 'ogr2ogr -f "GeoJSON" ' + git_local + 'v_resolution1_data.geojson -s_srs EPSG:' + s_srs + ' -t_srs EPSG:4326 PG:"host=' + host + ' port=' + port + ' dbname=' + dbname + ' user=' + user + ' password=' + pw + '" "object_res1.v_resolution1_data"'
os.system(com)        
                
# dump metadata to csv (note: use psql and \copy to avoid permission error)
com = 'psql -U ' + user + ' -p ' + port + ' -d ' + dbname + ' -c "\COPY (SELECT * FROM object_res1.v_resolution1_metadata) TO ' + git_local + 'v_resolution1_metadata.csv DELIMITER \',\' CSV HEADER;"'
os.system(com)

# add file to local git repo
os.chdir(git_local)
com = 'git add *'
os.system(com)              
 
# commit changes
com = 'git commit -m "new ' + dbname + ' release"'
os.system(com)              

# pull from remote repo
#com = 'git pull -u origin master'
#os.system(com)

# push to remote repo
com = 'git push -u origin master'
os.system(com)
