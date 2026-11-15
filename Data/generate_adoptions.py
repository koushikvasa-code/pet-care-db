
import random
from getpass import getpass
from decimal import Decimal

from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

# Database connection

random.seed(42)

password = getpass("Enter MySQL password: ")

db_url = URL.create(
    "mysql+mysqlconnector",
    username="root",
    password=password,
    host="localhost",
    database="pet_care_db"
)

engine = create_engine(db_url)


try:
    with engine.begin() as conn:


        existing_adoptions = conn.execute(text("""
            SELECT COUNT(*) FROM adoptions
        """)).scalar_one()

        if existing_adoptions > 0:
            raise RuntimeError(
                "The adoptions table already contains "
                "records. Review them before running."
            )

        # Retrieve approved applications

        approved_applications = conn.execute(text("""
            SELECT
                application_id,
                animal_id,
                adopter_id,
                application_date
            FROM adoption_applications
            WHERE status = 'Approved'
            ORDER BY application_id
        """)).mappings().all()

        print(
            f"Found {len(approved_applications)} "
            "approved applications."
        )

        if not approved_applications:
            raise RuntimeError(
                "No approved applications found."
            )

        # Match applications with adoption outcomes

        adoption_data = []
        used_animals = set()
        used_intakes = set()

        for application in approved_applications:

            animal_id = application["animal_id"]
            application_id = application["application_id"]
            application_date = application["application_date"]

            if animal_id in used_animals:
                raise RuntimeError(
                    f"Animal {animal_id} has more than "
                    "one approved application."
                )

            matching_outcomes = conn.execute(text("""
                SELECT
                    i.intake_id,
                    i.intake_date,
                    o.outcome_date,
                    o.outcome_group
                FROM intakes i
                JOIN outcomes o
                    ON i.intake_id = o.intake_id
                WHERE i.animal_id = :animal_id
                  AND o.outcome_group LIKE 'Adopted%'
                  AND :application_date
                      BETWEEN DATE(i.intake_date)
                      AND DATE(o.outcome_date)
                ORDER BY
                    o.outcome_date DESC,
                    i.intake_id DESC
            """), {
                "animal_id": animal_id,
                "application_date": application_date
            }).mappings().all()

            if not matching_outcomes:
                raise RuntimeError(
                    f"No matching adoption outcome "
                    f"found for application {application_id}."
                )

            outcome = matching_outcomes[0]

            intake_id = outcome["intake_id"]

            if intake_id in used_intakes:
                raise RuntimeError(
                    f"Intake {intake_id} is already used."
                )


            adoption_date = outcome["outcome_date"].date()

            adoption_fee = Decimal(
                random.choice(
                    [25, 50, 75, 100, 125, 150, 175, 200]
                )
            )

            adoption_data.append({
                "application_id": application_id,
                "intake_id": intake_id,
                "adoption_date": adoption_date,
                "adoption_fee": adoption_fee
            })

            used_animals.add(animal_id)
            used_intakes.add(intake_id)

        conn.execute(text("""
            INSERT INTO adoptions (
                application_id,
                intake_id,
                adoption_date,
                adoption_fee
            )
            VALUES (
                :application_id,
                :intake_id,
                :adoption_date,
                :adoption_fee
            )
        """), adoption_data)

        print(
            f"Successfully inserted "
            f"{len(adoption_data)} adoptions!"
        )

finally:
    engine.dispose()
