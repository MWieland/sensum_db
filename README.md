# A spatio-temporal building exposure database and information life-cycle management solution

## Summary
This is a prototype implementation of an information life-cycle management solution, based on a relational spatio-temporal database model. 
Two fictious application scenarios focusing on the modelling of residential building stocks and their changes during different phases of 
the disaster risk management cycle are provided to show the capabilities of the solution in the context of disaster risk management.  

## References
Wieland, M., Pittore M. A spatio-temporal building exposure database and information life-cycle management solution. International Journal of Geo-Information, under review.

## Dependencies
PostgreSQL 9.2 or higher
PostGIS 2.0 or higher

## Installation 
#### Create empty database
$ createdb sensum_db -h localhost -U postgres

#### Add main database model
$ psql -h localhost -U postgres -d sensum_db -f main_db.sql;

#### Add multi-temporal support to the database model
$ psql -h localhost -U postgres -d sensum_db -f add_temporal_support.sql;

#### Add multi-resolution support to the database model
$ psql -h localhost -U postgres -d sensum_db -f add_resolution_support.sql;

#### Add sample taxonomies to the database model
$ psql -h localhost -U postgres -d sensum_db -f add_taxonomies.sql;

## Scenarios
#### Load scenario data
$ psql -h localhost -U postgres -d sensum_db -f scenario_2_data.sql;

#### Run scenario
$ psql -h localhost -U postgres -d sensum_db -f scenario_2.sql;

#### Explore scenario with example queries or by looking at the run scenario scripts
scenario_2_queries.sql

#### Make sure to clean scenario data and history before running a new scenario

## Examples
More example queries can be found in example_queries.sql

## Acknowledgements
This research has been supported by the SENSUM project (Grant Agreement Number 312972).
