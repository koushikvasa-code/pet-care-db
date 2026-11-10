import random
from faker import Faker
from sqlalchemy import create_engine, text

fake = Faker()


engine = create_engine("mysql+mysqlconnector://root@localhost/pet_care_db")

with engine.begin() as connection:
    # 2. Generate 1,000 Adopters
    print("Generating 1,000 adopters...")
    adopters = [
        {
            "fn": fake.first_name(), "ln": fake.last_name(),
            "ph": fake.phone_number()[:20], "addr": fake.address().replace('\n', ', '),
            "em": fake.unique.email()
        } for _ in range(1000)
    ]
    connection.execute(
        text("INSERT INTO adopters (first_name, last_name, phone, address, email) VALUES (:fn, :ln, :ph, :addr, :em)"),
        adopters
    )

    # 3. Generate Clinics
    print("Generating clinics and veterinarians...")
    clinics = [
        {"n": f"{fake.last_name()} Animal Hospital", "c": fake.city(), "p": fake.phone_number()[:20]}
        for _ in range(5)
    ]
    connection.execute(
        text("INSERT INTO clinics (name, city, phone) VALUES (:n, :c, :p)"),
        clinics
    )

    clinic_ids = [row[0] for row in connection.execute(text("SELECT clinic_id FROM clinics")).fetchall()]

    # 4. Generate Veterinarians
    vets = [
        {
            "c_id": random.choice(clinic_ids), "fn": fake.first_name(), "ln": fake.last_name(),
            "lic": fake.unique.bothify(text='VET-#####'), "ph": fake.phone_number()[:20],
            "spec": random.choice(['General Practice', 'Surgery', 'Dentistry', 'Emergency'])
        } for _ in range(20)
    ]
    connection.execute(
        text("INSERT INTO veterinarians (clinic_id, first_name, last_name, license_number, phone, specialty) VALUES (:c_id, :fn, :ln, :lic, :ph, :spec)"),
        vets
    )

    # 5. Generate Appointments
    print("Generating 1,000 veterinary appointments...")
    vet_ids = [row[0] for row in connection.execute(text("SELECT vet_id FROM veterinarians")).fetchall()]
    animal_ids = [row[0] for row in connection.execute(text("SELECT animal_id FROM animals LIMIT 1000")).fetchall()]

    appointments = [
        {
            "a_id": animal_id, "v_id": random.choice(vet_ids),
            "dt": fake.date_time_between(start_date='-2y', end_date='now').strftime('%Y-%m-%d %H:%M:%S'),
            "rsn": random.choice(['Annual Checkup', 'Vaccination', 'Injury', 'Illness', 'Follow-up']),
            "stat": random.choice(['Completed', 'Scheduled', 'Cancelled'])
        } for animal_id in animal_ids
    ]
    connection.execute(
        text("INSERT INTO appointments (animal_id, vet_id, appointment_datetime, reason, status) VALUES (:a_id, :v_id, :dt, :rsn, :stat)"),
        appointments
    )

print("All synthetic data generated! Project tables are fully populated.")