-- =====================================================================
-- complex_queries.sql
-- =====================================================================
USE pet_care_db;
SET @today = '2026-11-16';

-- ---------------------------------------------------------------------
-- Q1  Available animals with their latest vaccination status
-- PURPOSE   Staff need to see which adoptable animals are vaccinated.
-- TECHNIQUES CTE with ROW_NUMBER() window function, LEFT JOINs, CASE.
-- ---------------------------------------------------------------------
WITH LatestVaccinations AS (
    SELECT vaccination_id, animal_id, vaccine_name, next_due_date,
           ROW_NUMBER() OVER(PARTITION BY animal_id ORDER BY date_administered DESC) as rn
    FROM vaccinations
)
SELECT a.animal_id, COALESCE(a.name, '(unnamed)') AS name, t.type_name, b.breed_name,
       s.name AS shelter, v.vaccine_name AS last_vaccine, v.next_due_date,
       CASE WHEN v.vaccination_id IS NULL        THEN 'Never vaccinated'
            WHEN v.next_due_date < '2026-11-16'  THEN 'Overdue'
            ELSE 'Up to date' END AS vaccine_status
FROM animals a
LEFT JOIN animal_types t ON t.type_id    = a.type_id
LEFT JOIN breeds       b ON b.breed_id   = a.breed_id
LEFT JOIN shelters     s ON s.shelter_id = a.shelter_id
LEFT JOIN LatestVaccinations v ON v.animal_id = a.animal_id AND v.rn = 1
WHERE a.status LIKE '%Available%'
ORDER BY a.animal_id
LIMIT 25;

-- ---------------------------------------------------------------------
-- Q2  Busiest vets each month (top 3)
-- PURPOSE   Balance workload across vets.
-- TECHNIQUES CTE, GROUP BY, RANK() window function with PARTITION BY.
-- ---------------------------------------------------------------------
WITH monthly AS (
  SELECT v.vet_id, CONCAT(v.first_name, ' ', v.last_name) AS vet, c.name AS clinic,
         DATE_FORMAT(a.appointment_datetime, '%Y-%m') AS month, COUNT(*) AS appts
  FROM appointments a
  JOIN veterinarians v ON v.vet_id = a.vet_id
  JOIN clinics c       ON c.clinic_id = v.clinic_id
  WHERE a.status = 'Completed'
  GROUP BY v.vet_id, vet, clinic, month
)
SELECT month, vet, clinic, appts, rnk
FROM (SELECT m.*, RANK() OVER (PARTITION BY month ORDER BY appts DESC) AS rnk FROM monthly m) r
WHERE rnk <= 3
ORDER BY month DESC, rnk, vet
LIMIT 30;

-- ---------------------------------------------------------------------
-- Q3  Average days in shelter before adoption, by animal type
-- PURPOSE   Which animals wait longest to be adopted?
-- TECHNIQUES CTE, JOIN, AVG/MIN/MAX, HAVING to hide tiny groups.
-- ---------------------------------------------------------------------
WITH adoption_stays AS (
  SELECT a.type_id, o.days_in_shelter
  FROM outcomes o
  JOIN intakes i ON o.intake_id = i.intake_id
  JOIN animals a ON i.animal_id = a.animal_id
  WHERE o.outcome_group LIKE 'Adopted%'
)
SELECT t.type_name, COUNT(*) AS adoptions,
       ROUND(AVG(s.days_in_shelter), 1) AS avg_days, MIN(s.days_in_shelter) AS min_days,
       MAX(s.days_in_shelter) AS max_days
FROM adoption_stays s JOIN animal_types t ON t.type_id = s.type_id
GROUP BY t.type_name
HAVING COUNT(*) >= 20
ORDER BY avg_days DESC;

-- ---------------------------------------------------------------------
-- Q4  Animals in the shelter with NO current vaccination (anti-join)
-- PURPOSE   Vaccination work list for the vet team.
-- TECHNIQUES LEFT JOIN ... IS NULL (anti-join), IN list, date comparison.
-- ---------------------------------------------------------------------
SELECT a.animal_id, COALESCE(a.name, '(unnamed)') AS name, t.type_name, a.status
FROM animals a
JOIN animal_types t ON t.type_id = a.type_id
LEFT JOIN vaccinations v ON v.animal_id = a.animal_id AND v.next_due_date >= @today
WHERE a.status IN ('Available', 'Pending', 'Fostered')
  AND v.vaccination_id IS NULL
ORDER BY a.animal_id
LIMIT 25;

-- ---------------------------------------------------------------------
-- Q5  Monthly revenue per clinic with a running total
-- PURPOSE   Track clinic income over time.
-- TECHNIQUES 6-table join, CTE, SUM() OVER (PARTITION BY ... ORDER BY ...).
-- ---------------------------------------------------------------------
WITH monthly AS (
  SELECT c.clinic_id, c.name AS clinic, DATE_FORMAT(p.payment_date, '%Y-%m') AS month,
         SUM(p.amount) AS revenue
  FROM payments p
  JOIN invoices i      ON i.invoice_id = p.invoice_id
  JOIN appointments a  ON a.appointment_id = i.appointment_id
  JOIN veterinarians v ON v.vet_id = a.vet_id
  JOIN clinics c       ON c.clinic_id = v.clinic_id
  GROUP BY c.clinic_id, c.name, month
)
SELECT clinic, month, ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (PARTITION BY clinic_id ORDER BY month), 2) AS running_total
FROM monthly
ORDER BY clinic, month
LIMIT 30;

-- ---------------------------------------------------------------------
-- Q6  Adopters with more than one pending application
-- PURPOSE   Spot people applying for several animals at once.
-- TECHNIQUES GROUP BY, HAVING, GROUP_CONCAT.
-- ---------------------------------------------------------------------
SELECT ad.adopter_id, CONCAT(ad.first_name, ' ', ad.last_name) AS adopter,
       COUNT(*) AS pending_applications,
       GROUP_CONCAT(app.animal_id ORDER BY app.animal_id) AS animal_ids
FROM adoption_applications app
JOIN adopters ad ON ad.adopter_id = app.adopter_id
WHERE app.status = 'Pending'
GROUP BY ad.adopter_id, adopter
HAVING COUNT(*) >= 2
ORDER BY pending_applications DESC, ad.adopter_id
LIMIT 20;

-- ---------------------------------------------------------------------
-- Q7  Medications at or below the reorder level, with demand
-- PURPOSE   Restocking list.
-- TECHNIQUES Derived table (total prescribed per medication), LEFT JOIN, COALESCE.
-- ---------------------------------------------------------------------
SELECT m.medication_id, m.name, m.stock_qty, m.reorder_level,
       m.reorder_level - m.stock_qty AS units_below_reorder,
       COALESCE(d.total_prescribed, 0) AS total_units_prescribed
FROM medications m
LEFT JOIN (SELECT medication_id, SUM(quantity) AS total_prescribed
           FROM prescriptions GROUP BY medication_id) d ON d.medication_id = m.medication_id
WHERE m.stock_qty <= m.reorder_level
ORDER BY units_below_reorder DESC;

-- ---------------------------------------------------------------------
-- Q8  Adoption funnel by month: applications -> approved -> rejected
-- PURPOSE   Measure how many applications turn into adoptions.
-- TECHNIQUES Conditional aggregation: SUM(condition) counts matching rows.
-- ---------------------------------------------------------------------
SELECT DATE_FORMAT(application_date, '%Y-%m') AS month,
       COUNT(*)                                  AS applications,
       SUM(status = 'Approved')                  AS approved,
       SUM(status = 'Rejected')                  AS rejected,
       ROUND(100 * SUM(status = 'Approved') / COUNT(*), 1) AS pct_approved
FROM adoption_applications
GROUP BY month
ORDER BY month;

-- ---------------------------------------------------------------------
-- Q9  Most common diagnosis for each breed (breeds with 100+ records)
-- PURPOSE   Show which health problems cluster in which breeds.
-- TECHNIQUES 5-table join, two CTEs, ROW_NUMBER() and SUM() OVER (PARTITION BY).
-- ---------------------------------------------------------------------
WITH dx AS (
  SELECT b.breed_id, b.breed_name, t.type_name, mr.diagnosis, COUNT(*) AS cases
  FROM medical_records mr
  JOIN appointments ap ON ap.appointment_id = mr.appointment_id
  JOIN animals a       ON a.animal_id = ap.animal_id
  JOIN breeds b        ON b.breed_id = a.breed_id
  JOIN animal_types t  ON t.type_id = b.type_id
  GROUP BY b.breed_id, b.breed_name, t.type_name, mr.diagnosis
), ranked AS (
  SELECT dx.*, SUM(cases) OVER (PARTITION BY breed_id) AS breed_total,
         ROW_NUMBER() OVER (PARTITION BY breed_id ORDER BY cases DESC, diagnosis) AS rn
  FROM dx
)
SELECT breed_name, type_name, diagnosis AS most_common_diagnosis, cases, breed_total
FROM ranked
WHERE rn = 1 AND breed_total >= 100
ORDER BY breed_total DESC
LIMIT 15;

-- ---------------------------------------------------------------------
-- Q10 Monthly intakes vs outcomes vs adoptions (shelter capacity trend)
-- PURPOSE   Are more animals arriving than leaving? Positive net = shelter filling up.
-- TECHNIQUES Three CTEs, UNION to build a month list (MySQL has no FULL JOIN), LEFT JOINs.
-- ---------------------------------------------------------------------
WITH i AS (SELECT DATE_FORMAT(intake_date, '%Y-%m') AS month, COUNT(*) AS intakes
           FROM intakes GROUP BY month),
     o AS (SELECT DATE_FORMAT(outcome_date, '%Y-%m') AS month, COUNT(*) AS outcomes,
                  SUM(outcome_group LIKE 'Adopted%') AS adoptions
           FROM outcomes GROUP BY month),
     months AS (SELECT month FROM i UNION SELECT month FROM o)
SELECT m.month, COALESCE(i.intakes, 0) AS intakes, COALESCE(o.outcomes, 0) AS outcomes,
       COALESCE(o.adoptions, 0) AS adoptions,
       COALESCE(i.intakes, 0) - COALESCE(o.outcomes, 0) AS net_change
FROM months m
LEFT JOIN i ON i.month = m.month
LEFT JOIN o ON o.month = m.month
ORDER BY m.month;
