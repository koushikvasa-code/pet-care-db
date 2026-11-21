
-- Test 1: Concurrency Control
-- This test simulates two employees attempting to approve different adoption applications for the same animal.

-- Session 1
-- Lock Cumin's animal record to prevent another transaction from modifying it while processing an adoption.

USE pet_care_db;

-- Find Cumin's available animal record
SET @animal_id = (
    SELECT animal_id FROM animals
    WHERE name = 'Cumin' AND status = 'Available'
    ORDER BY animal_id LIMIT 1
);
SELECT @animal_id AS animal_id;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;

-- Lock Cumin's animal record
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @animal_id
FOR UPDATE;


-- Session 2
-- This transaction attempts to lock the same animal

USE pet_care_db;

SET @animal_id = (
    SELECT animal_id FROM animals
    WHERE name = 'Cumin' AND status = 'Available'
    ORDER BY animal_id LIMIT 1
);
SELECT @animal_id AS animal_id;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION innodb_lock_wait_timeout = 10;
START TRANSACTION;

-- Attempt to lock the same animal
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @animal_id
FOR UPDATE;

-- Run in Terminal 2:
ROLLBACK;

-- Run in Terminal 1:
ROLLBACK;

-- Test 2: Preventing Double Adoption
-- This test simulates two sessions attempting to process different adoption applications for Cumin.

-- Session 1

USE pet_care_db;

SET @app1 = (
    SELECT application_id FROM adoption_applications
    WHERE animal_id = @animal_id AND status = 'Pending'
    ORDER BY application_id LIMIT 1
);
SET @app2 = (
    SELECT application_id FROM adoption_applications
    WHERE animal_id = @animal_id AND status = 'Pending'
      AND application_id <> @app1
    ORDER BY application_id LIMIT 1
);
SET @intake = (
    SELECT i.intake_id FROM intakes i
    WHERE i.animal_id = @animal_id
      AND NOT EXISTS (SELECT 1 FROM adoptions ad WHERE ad.intake_id = i.intake_id)
    ORDER BY i.intake_id LIMIT 1
);
SELECT @animal_id AS animal_id, @app1 AS application_1,
       @app2 AS application_2, @intake AS intake_id;

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;

-- Lock Cumin's record before processing the adoption
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @animal_id
FOR UPDATE;

-- Approve application
UPDATE adoption_applications
SET status = 'Approved'
WHERE application_id = @app1
  AND animal_id = @animal_id
  AND status = 'Pending';

-- Create an adoption record
INSERT INTO adoptions
    (application_id, intake_id, adoption_date, adoption_fee)
VALUES
    (@app1, @intake, CURDATE(), 100.00);

-- Update Cumin's status as adopted
UPDATE animals
SET status = 'Adopted'
WHERE animal_id = @animal_id
  AND status = 'Available';

-- Session 2

SET SESSION innodb_lock_wait_timeout = 10;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;

-- Attempt to lock Cumin's record
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @animal_id
FOR UPDATE;

-- End transaction.
ROLLBACK;

-- Session 1: Verify uncommitted changes.
SELECT
    a.animal_id,
    a.name,
    a.status AS animal_status,
    aa.application_id,
    aa.status AS application_status,
    ad.adoption_id
FROM animals a
JOIN adoption_applications aa
    ON a.animal_id = aa.animal_id
LEFT JOIN adoptions ad
    ON aa.application_id = ad.application_id
WHERE aa.application_id = @app1;

ROLLBACK;

-- Terminal 1
-- Confirm Cumin is still available
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @animal_id;

-- Confirm both applications are still pending
SELECT application_id, status
FROM adoption_applications
WHERE application_id IN (@app1, @app2);

-- Confirm no adoption records were saved
SELECT adoption_id, application_id
FROM adoptions
WHERE application_id IN (@app1, @app2);

-- Test 3 Setup: Create Temporary Test Data
-- Terminal 1

USE pet_care_db;

-- Select unused IDs for temporary test records.
SET @test_animal = (
    SELECT LEAST(COALESCE(MIN(animal_id), 0), 0) - 1 FROM animals
);
SET @test_source = (
    SELECT COALESCE(MAX(source_record_id), 0) + 1 FROM intakes
);
SET @type_id = (SELECT MIN(type_id) FROM animal_types);
SET @shelter_id = (SELECT MIN(shelter_id) FROM shelters);
SET @adopter1 = (SELECT adopter_id FROM adopters ORDER BY adopter_id LIMIT 1);
SET @adopter2 = (SELECT adopter_id FROM adopters ORDER BY adopter_id LIMIT 1 OFFSET 1);
SELECT @test_animal AS animal_id, @test_source AS source_record_id,
       @type_id AS type_id, @shelter_id AS shelter_id,
       @adopter1 AS adopter_1, @adopter2 AS adopter_2;

-- Create the test animal.
INSERT INTO animals (animal_id, name, type_id, shelter_id, status)
VALUES (@test_animal, 'ConcurrencyTest', @type_id, @shelter_id, 'Available');

-- Create two pending adoption applications
INSERT INTO adoption_applications
    (animal_id, adopter_id, application_date, status)
VALUES
    (@test_animal, @adopter1, CURDATE(), 'Pending');
SET @test_app1 = LAST_INSERT_ID();

INSERT INTO adoption_applications
    (animal_id, adopter_id, application_date, status)
VALUES
    (@test_animal, @adopter2, CURDATE(), 'Pending');
SET @test_app2 = LAST_INSERT_ID();

-- Retrieve the generated application IDs
SELECT application_id, animal_id, adopter_id, status
FROM adoption_applications
WHERE animal_id = @test_animal
ORDER BY application_id;

-- Create an intake record for the test animal
INSERT INTO intakes
    (source_record_id, animal_id, shelter_id,
     intake_date, intake_type)
VALUES
    (@test_source, @test_animal, @shelter_id, NOW(), 'Test');
SET @test_intake = LAST_INSERT_ID();

-- Retrieve the generated intake ID
SELECT intake_id, animal_id, source_record_id
FROM intakes
WHERE animal_id = @test_animal;

COMMIT;
SELECT @test_animal AS animal_id, @test_app1 AS application_1,
       @test_app2 AS application_2, @test_intake AS intake_id;

-- Session 2: Initialize Variables Before Session 1 Locks the Animal
-- Terminal 2

USE pet_care_db;

SET @test_animal = (
    SELECT animal_id FROM animals
    WHERE name = 'ConcurrencyTest' AND status = 'Available'
    ORDER BY animal_id LIMIT 1
);

SET @test_app2 = (
    SELECT application_id FROM adoption_applications
    WHERE animal_id = @test_animal AND status = 'Pending'
    ORDER BY application_id DESC LIMIT 1
);

SELECT @test_animal AS animal_id, @test_app2 AS application_2;


-- Test 6: Preventing Double Adoption After COMMIT

-- This test simulates two sessions attempting to adopt the same animal using different applications.
-- Session 1 completes the adoption.
-- Session 2 checks the animal's status after Session 1 commits and rejects the second application.

-- Session 1

USE pet_care_db;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;

-- Lock the animal before processing the adoption
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @test_animal
FOR UPDATE;

-- Approve Session 1's application
UPDATE adoption_applications
SET status = 'Approved'
WHERE application_id = @test_app1
  AND animal_id = @test_animal
  AND status = 'Pending';

-- Create the adoption record
INSERT INTO adoptions
    (application_id, intake_id, adoption_date, adoption_fee)
VALUES
    (@test_app1, @test_intake, CURDATE(), 100.00);

-- Mark the animal as adopted
UPDATE animals
SET status = 'Adopted'
WHERE animal_id = @test_animal
  AND status = 'Available';


-- Session 2
-- Terminal 2

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SET SESSION innodb_lock_wait_timeout = 10;
START TRANSACTION;

-- Attempt to lock the same animal
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @test_animal
FOR UPDATE;

ROLLBACK;

-- Session 1: Commit Adoption
-- Terminal 1
COMMIT;

-- Session 2: Retry After Session 1 Commits
-- Terminal 2

SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;

-- Lock the animal and check its updated status
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @test_animal
FOR UPDATE;

UPDATE adoption_applications
SET status = 'Rejected'
WHERE application_id = @test_app2
  AND animal_id = @test_animal
  AND status = 'Pending'
  AND EXISTS (
      SELECT 1
      FROM animals
      WHERE animal_id = @test_animal
        AND status = 'Adopted'
  );

COMMIT;
-- Terminal 1 (after Session 2 commits)

-- Verify the animal is adopted
SELECT animal_id, name, status
FROM animals
WHERE animal_id = @test_animal;

-- Verify the application statuses
SELECT application_id, adopter_id, status
FROM adoption_applications
WHERE animal_id = @test_animal;

-- Count completed adoptions for the animal
SELECT COUNT(*) AS adoption_count
FROM adoptions ad
JOIN adoption_applications aa
    ON ad.application_id = aa.application_id
WHERE aa.animal_id = @test_animal;

-- Test 6 Cleanup: Remove Temporary Test Data
-- Terminal 1

START TRANSACTION;

-- Delete the temporary adoption record
DELETE FROM adoptions
WHERE application_id = @test_app1
  AND intake_id = @test_intake;

-- Delete both temporary applications
DELETE FROM adoption_applications
WHERE animal_id = @test_animal
  AND application_id IN (@test_app1, @test_app2);

-- Delete the temporary intake
DELETE FROM intakes
WHERE intake_id = @test_intake
  AND animal_id = @test_animal
  AND source_record_id = @test_source;

-- Delete the temporary animal
DELETE FROM animals
WHERE animal_id = @test_animal
  AND name = 'ConcurrencyTest';

-- Verify that the temporary records were deleted
SELECT * FROM animals
WHERE animal_id = @test_animal;

SELECT * FROM adoption_applications
WHERE application_id IN (@test_app1, @test_app2);

SELECT * FROM adoptions
WHERE application_id = @test_app1;

SELECT * FROM intakes
WHERE intake_id = @test_intake;

COMMIT;
