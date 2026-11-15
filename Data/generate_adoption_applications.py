
import random
from datetime import date, datetime, timedelta
from getpass import getpass

from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL



NUM_APPROVED = 500
NUM_REJECTED = 200
NUM_AVAILABLE_ANIMALS = 100
NUM_PENDING = 300

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


def random_application_date(start_date, end_date):
    """Choose a random date between two dates, inclusive."""
    days_between = (end_date - start_date).days

    if days_between < 0:
        raise ValueError("End date is before start date.")

    return start_date + timedelta(
        days=random.randint(0, days_between)
    )


try:
    with engine.begin() as conn:


        existing_applications = conn.execute(text(""" SELECT COUNT(*) FROM adoption_applications """)).scalar_one()

        if existing_applications > 0:
            raise RuntimeError(
                "adoption_applications is not empty. "
                "Review existing records before running."
            )

        existing_adoptions = conn.execute(text("""
            SELECT COUNT(*) FROM adoptions
        """)).scalar_one()

        if existing_adoptions > 0:
            raise RuntimeError(
                "adoptions already contains records."
            )

        existing_available = conn.execute(text("""
            SELECT COUNT(*) FROM animals WHERE status = 'Available'
        """)).scalar_one()

        if existing_available > 0:
            raise RuntimeError(
                "Available animals already exist. "
                "Review them before generating new ones."
            )


        # Retrieve historical adopted animals

        rows = conn.execute(text("""
            SELECT
                a.animal_id,
                i.intake_id,
                i.intake_date,
                o.outcome_date,
                o.outcome_group
            FROM animals a
            JOIN intakes i
                ON a.animal_id = i.animal_id
            JOIN outcomes o
                ON i.intake_id = o.intake_id
            WHERE o.outcome_group LIKE 'Adopted%'
              AND o.outcome_date >= i.intake_date
            ORDER BY
                a.animal_id,
                o.outcome_date DESC,
                i.intake_id DESC
        """)).mappings().all()

        eligible_animals = {}

        for row in rows:
            animal_id = row["animal_id"]

            if animal_id not in eligible_animals:
                eligible_animals[animal_id] = row

        adopted_animals = list(eligible_animals.values())

        # Retrieve existing adopter IDs


        adopter_ids = conn.execute(text("""
            SELECT adopter_id FROM adopters
        """)).scalars().all()

        if len(adopted_animals) < NUM_APPROVED:
            raise RuntimeError(
                "Not enough historical adoption records."
            )

        if len(adopter_ids) < 2:
            raise RuntimeError(
                "At least two adopters are required."
            )

        used_pairs = set()
        application_data = []

        # Generate APPROVED applications

        selected_animals = random.sample(
            adopted_animals,
            NUM_APPROVED
        )

        for animal in selected_animals:

            animal_id = animal["animal_id"]
            adopter_id = random.choice(adopter_ids)

            application_date = random_application_date(
                animal["intake_date"].date(),
                animal["outcome_date"].date()
            )

            application_data.append({
                "animal_id": animal_id,
                "adopter_id": adopter_id,
                "application_date": application_date,
                "status": "Approved"
            })

            used_pairs.add((animal_id, adopter_id))

        print(
            f"Prepared {NUM_APPROVED} approved applications."
        )

        # Generate REJECTED applications


        rejected_count = 0

        while rejected_count < NUM_REJECTED:

            animal = random.choice(selected_animals)

            animal_id = animal["animal_id"]
            adopter_id = random.choice(adopter_ids)

            pair = (animal_id, adopter_id)

            if pair in used_pairs:
                continue

            application_date = random_application_date(
                animal["intake_date"].date(),
                animal["outcome_date"].date()
            )

            application_data.append({
                "animal_id": animal_id,
                "adopter_id": adopter_id,
                "application_date": application_date,
                "status": "Rejected"
            })

            used_pairs.add(pair)
            rejected_count += 1

        print(
            f"Prepared {NUM_REJECTED} rejected applications."
        )

        # Create synthetic AVAILABLE animals


        source_animals = conn.execute(text("""
            SELECT
                name,
                type_id,
                breed_id,
                shelter_id,
                sex,
                date_of_birth,
                life_stage,
                spayed_neutered,
                primary_color,
                secondary_color
            FROM animals
            WHERE shelter_id IS NOT NULL
            ORDER BY RAND()
            LIMIT :limit
        """), {
            "limit": NUM_AVAILABLE_ANIMALS
        }).mappings().all()

        if len(source_animals) < NUM_AVAILABLE_ANIMALS:
            raise RuntimeError(
                "Not enough source animals."
            )

        max_animal_id = conn.execute(text("""
            SELECT COALESCE(MAX(animal_id), 0)
            FROM animals
        """)).scalar_one()

        available_intakes = []
        today = date.today()

        min_source_record_id = conn.execute(text("""
        SELECT COALESCE(MIN(source_record_id), 0)
        FROM intakes
        """)).scalar_one()

        next_source_record_id = min(
        min_source_record_id, 0
        ) - 1

        for index, animal in enumerate(source_animals):

            new_animal_id = max_animal_id + index + 1

            conn.execute(text("""
                INSERT INTO animals (
                    animal_id,
                    name,
                    type_id,
                    breed_id,
                    shelter_id,
                    sex,
                    date_of_birth,
                    life_stage,
                    spayed_neutered,
                    primary_color,
                    secondary_color,
                    status
                )
                VALUES (
                    :animal_id,
                    :name,
                    :type_id,
                    :breed_id,
                    :shelter_id,
                    :sex,
                    :date_of_birth,
                    :life_stage,
                    :spayed_neutered,
                    :primary_color,
                    :secondary_color,
                    'Available'
                )
            """), {
                "animal_id": new_animal_id,
                "name": animal["name"],
                "type_id": animal["type_id"],
                "breed_id": animal["breed_id"],
                "shelter_id": animal["shelter_id"],
                "sex": animal["sex"],
                "date_of_birth": animal["date_of_birth"],
                "life_stage": animal["life_stage"],
                "spayed_neutered": animal["spayed_neutered"],
                "primary_color": animal["primary_color"],
                "secondary_color": animal["secondary_color"]
            })

            intake_date = today - timedelta(
                days=random.randint(10, 60)
            )

            available_intakes.append({
              "source_record_id": next_source_record_id - index,
              "animal_id": new_animal_id,
              "shelter_id": animal["shelter_id"],
              "intake_date": datetime.combine(
                  intake_date,
                  datetime.min.time()
              ),
              "intake_type": "Synthetic Intake"
          })

        conn.execute(text("""
            INSERT INTO intakes (source_record_id, animal_id, shelter_id, intake_date, intake_type)
            VALUES (:source_record_id, :animal_id, :shelter_id, :intake_date, :intake_type)
        """), available_intakes)

        print(
            f"Created {NUM_AVAILABLE_ANIMALS} "
            "synthetic available animals."
        )

        # Generate PENDING applications

        available_rows = conn.execute(text("""
            SELECT
                a.animal_id,
                i.intake_date
            FROM animals a
            JOIN intakes i
                ON a.animal_id = i.animal_id
            WHERE a.status = 'Available'
        """)).mappings().all()

        pending_count = 0

        while pending_count < NUM_PENDING:

            animal = random.choice(available_rows)

            animal_id = animal["animal_id"]
            adopter_id = random.choice(adopter_ids)

            pair = (animal_id, adopter_id)

            if pair in used_pairs:
                continue

            application_date = random_application_date(
                animal["intake_date"].date(),
                today
            )

            application_data.append({
                "animal_id": animal_id,
                "adopter_id": adopter_id,
                "application_date": application_date,
                "status": "Pending"
            })

            used_pairs.add(pair)
            pending_count += 1

        print(
            f"Prepared {NUM_PENDING} pending applications."
        )

        conn.execute(text("""
            INSERT INTO adoption_applications (
                animal_id,
                adopter_id,
                application_date,
                status
            )
            VALUES (
                :animal_id,
                :adopter_id,
                :application_date,
                :status
            )
        """), application_data)

        print(
            f"Successfully inserted "
            f"{len(application_data)} applications!"
        )

finally:
    engine.dispose()
