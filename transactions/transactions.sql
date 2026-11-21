
-- Test 1: ROLLBACK
-- Test 2: COMMIT
-- Test 3: Atomicity Across Multiple Tables

USE pet_care_db;

-- Select an available animal with a pending adoption application
SET @animal_id = (
    SELECT a.animal_id
    FROM animals a
    JOIN adoption_applications aa
        ON a.animal_id = aa.animal_id
    WHERE a.status = 'Available'
      AND aa.status = 'Pending'
      AND EXISTS (
          SELECT 1
          FROM intakes i
          WHERE i.animal_id = a.animal_id
      )
      AND NOT EXISTS (
          SELECT 1
          FROM adoption_applications aa2
          JOIN adoptions ad
              ON ad.application_id = aa2.application_id
          WHERE aa2.animal_id = a.animal_id
      )
    ORDER BY a.animal_id
    LIMIT 1
);

SET @application_id = (
    SELECT application_id
    FROM adoption_applications
    WHERE animal_id = @animal_id
      AND status = 'Pending'
    ORDER BY application_id
    LIMIT 1
);

SET @intake_id = (
    SELECT intake_id
    FROM intakes
    WHERE animal_id = @animal_id
    ORDER BY intake_id DESC
    LIMIT 1
);

-- Verify selected records
SELECT @animal_id AS animal_id,
       @application_id AS application_id,
       @intake_id AS intake_id;



-- Test 1: Demonstrating ROLLBACK
-- This test temporarily approves an adoption application and rolls back the transaction to restore its original status.

-- Begin transaction
START TRANSACTION;

-- Temporarily approve the applications
UPDATE adoption_applications
SET status = 'Approved'
WHERE application_id = @application_id
  AND status = 'Pending';

-- Verify the change within the transaction
SELECT application_id, animal_id, adopter_id, status
FROM adoption_applications
WHERE application_id = @application_id;

-- Undo the change
ROLLBACK;

-- Verify the original status is restored
SELECT application_id, animal_id, adopter_id, status
FROM adoption_applications
WHERE application_id = @application_id;

-- Test 2: Demonstrating COMMIT
-- This test changes an adoption application's status from Pending to Approved and back to Pending

START TRANSACTION;

UPDATE adoption_applications
SET status = 'Approved'
WHERE application_id = @application_id
  AND status = 'Pending';

-- Restore the original status
UPDATE adoption_applications
SET status = 'Pending'
WHERE application_id = @application_id
  AND status = 'Approved';

COMMIT;

-- Verify the final status
SELECT application_id, animal_id, adopter_id, status
FROM adoption_applications
WHERE application_id = @application_id;


-- Test 3: Demonstrating Atomicity with Multiple Tables
-- This test temporarily approves an adoption application, creates an adoption record, and updates the animal's status.

START TRANSACTION;

-- Approve the adoption application
UPDATE adoption_applications
SET status = 'Approved'
WHERE application_id = @application_id
  AND status = 'Pending';

-- Create the adoption record
INSERT INTO adoptions
    (application_id, intake_id, adoption_date, adoption_fee)
VALUES
    (@application_id, @intake_id, CURDATE(), 100.00);

-- Update the animal's status
UPDATE animals
SET status = 'Adopted'
WHERE animal_id = @animal_id
  AND status = 'Available';

-- Verify the changes before rollback
SELECT
    a.animal_id,
    a.status AS animal_status,
    aa.application_id,
    aa.status AS application_status,
    ad.adoption_id
FROM animals a
JOIN adoption_applications aa
    ON a.animal_id = aa.animal_id
LEFT JOIN adoptions ad
    ON aa.application_id = ad.application_id
WHERE aa.application_id = @application_id;

ROLLBACK;

-- Verify the original state is restored
SELECT
    a.animal_id,
    a.status AS animal_status,
    aa.application_id,
    aa.status AS application_status,
    ad.adoption_id
FROM animals a
JOIN adoption_applications aa
    ON a.animal_id = aa.animal_id
LEFT JOIN adoptions ad
    ON aa.application_id = ad.application_id
WHERE aa.application_id = @application_id;