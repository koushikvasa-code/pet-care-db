SET SESSION sql_mode = '';
USE pet_care_db;

INSERT INTO shelters (name, city)
SELECT 'Austin Animal Center (dataset source)', 'Austin'
WHERE NOT EXISTS (
    SELECT 1 FROM shelters
    WHERE name = 'Austin Animal Center (dataset source)'
);

SET @source_shelter_id := (
    SELECT shelter_id FROM shelters
    WHERE name = 'Austin Animal Center (dataset source)'
    LIMIT 1
);

INSERT IGNORE INTO animal_types (type_name)
SELECT DISTINCT TRIM(animal_type)
FROM staging_outcomes
WHERE animal_type IS NOT NULL AND TRIM(animal_type) <> '';

INSERT IGNORE INTO breeds (breed_name, type_id)
SELECT DISTINCT TRIM(s.primary_breed), t.type_id
FROM staging_outcomes s
JOIN animal_types t ON t.type_name = TRIM(s.animal_type)
WHERE s.primary_breed IS NOT NULL AND TRIM(s.primary_breed) <> '';

INSERT INTO animals (
    animal_id, name, type_id, breed_id, shelter_id, sex,
    date_of_birth, spayed_neutered, primary_color, secondary_color, status
)
WITH ranked AS (
    SELECT
        source_animal_id,
        NULLIF(TRIM(animal_name), '') AS animal_name,
        TRIM(animal_type) AS animal_type,
        TRIM(primary_breed) AS primary_breed,
        NULLIF(TRIM(sex), '') AS sex,
        NULLIF(LOWER(TRIM(spayed_neutered)), '') AS altered_value,
        NULLIF(TRIM(primary_color), '') AS primary_color,
        NULLIF(TRIM(secondary_color), '') AS secondary_color,
        STR_TO_DATE(NULLIF(TRIM(date_of_birth_raw), ''), '%Y %b %d %h:%i:%s %p') AS birth_date,
        outcome_status,
        ROW_NUMBER() OVER (
            PARTITION BY source_animal_id
            ORDER BY STR_TO_DATE(NULLIF(TRIM(timestamp_raw), ''), '%Y %b %d %h:%i:%s %p') DESC, source_record_id DESC
        ) AS rn
    FROM staging_outcomes
)
SELECT
    r.source_animal_id, r.animal_name, t.type_id, b.breed_id, @source_shelter_id, r.sex, r.birth_date,
    CASE
      WHEN r.altered_value IN ('yes','y','true') THEN 'Yes'
      WHEN r.altered_value IN ('no','n','false') THEN 'No'
      ELSE NULL
    END,
    r.primary_color, r.secondary_color, r.outcome_status
FROM ranked r
JOIN animal_types t ON t.type_name = r.animal_type
LEFT JOIN breeds b ON b.breed_name = r.primary_breed AND b.type_id = t.type_id
WHERE r.rn = 1
ON DUPLICATE KEY UPDATE
    name = COALESCE(VALUES(name), name),
    status = VALUES(status);

INSERT INTO intakes (
    source_record_id, animal_id, shelter_id, intake_date, intake_type
)
SELECT
    s.source_record_id, s.source_animal_id, @source_shelter_id,
    STR_TO_DATE(TRIM(s.intake_date_raw), '%Y %b %d %h:%i:%s %p'),
    'Austin Animal Center dataset record'
FROM staging_outcomes s
WHERE STR_TO_DATE(TRIM(s.intake_date_raw), '%Y %b %d %h:%i:%s %p') IS NOT NULL
ON DUPLICATE KEY UPDATE
    animal_id = VALUES(animal_id);

INSERT INTO outcomes (
    intake_id, outcome_date, outcome_group, euthanasia_reason, days_in_shelter
)
SELECT
    i.intake_id,
    STR_TO_DATE(TRIM(s.outcome_date_raw), '%Y %b %d %h:%i:%s %p'),
    TRIM(s.outcome_status),
    NULLIF(TRIM(s.euthanasia_reason), ''),
    GREATEST(0, CAST(NULLIF(TRIM(REPLACE(s.days_in_shelter_raw, ',', '')), '') AS SIGNED))
FROM staging_outcomes s
JOIN intakes i ON i.source_record_id = s.source_record_id
WHERE STR_TO_DATE(TRIM(s.outcome_date_raw), '%Y %b %d %h:%i:%s %p') IS NOT NULL
ON DUPLICATE KEY UPDATE
    outcome_date = VALUES(outcome_date),
    outcome_group = VALUES(outcome_group),
    euthanasia_reason = VALUES(euthanasia_reason),
    days_in_shelter = VALUES(days_in_shelter);