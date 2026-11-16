-- =====================================================================
-- performance_analysis.sql
-- =====================================================================
USE pet_care_db;

-- ---------------------------------------------------------------------
-- SCENARIO 1: Optimizing the Animals table for status lookups
-- ---------------------------------------------------------------------

EXPLAIN
SELECT animal_id, name, shelter_id
FROM animals
WHERE status = 'Available';

-- Implement the Index
CREATE INDEX idx_animals_status ON animals(status);

-- Run EXPLAIN AFTER the index
SELECT animal_id, name, shelter_id
FROM animals
WHERE status = 'Available';


-- ---------------------------------------------------------------------
-- SCENARIO 2: Optimizing Adoption Applications
-- We frequently filter adoption applications by their status ('Pending', 'Approved').
-- ---------------------------------------------------------------------

EXPLAIN
SELECT adopter_id, COUNT(*) AS pending_apps
FROM adoption_applications
WHERE status = 'Pending'
GROUP BY adopter_id;

-- Implement the Index
CREATE INDEX idx_app_status ON adoption_applications(status);

-- Run EXPLAIN AFTER the index
EXPLAIN
SELECT adopter_id, COUNT(*) AS pending_apps
FROM adoption_applications
WHERE status = 'Pending'
GROUP BY adopter_id;


