LOAD DATA LOCAL INFILE '/Users/koushikvasa/pet-care-db/data/Austin_Animal_Center_Outcomes_20261104.csv'
INTO TABLE staging_outcomes
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ','
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(source_record_id, outcome_date_raw, source_animal_id, animal_name, outcome_status, euthanasia_reason, animal_type, sex, spayed_neutered, primary_breed, primary_color, secondary_color, date_of_birth_raw, intake_date_raw, days_in_shelter_raw, timestamp_raw);