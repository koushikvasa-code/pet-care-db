import random
from datetime import date, datetime, timedelta
from sqlalchemy import create_engine, text

# Connect to the local database
engine = create_engine("mysql+mysqlconnector://root:pluto123@localhost/pet_care_db")

with engine.begin() as conn:
    # 1. Populate Medications (if empty)
    existing_meds = conn.execute(text("SELECT medication_id FROM medications")).fetchall()
    if not existing_meds:
        med_data = [
            {"name": "Amoxicillin (Antibiotic)", "stock_qty": 100, "reorder_level": 20, "unit_price": 15.50},
            {"name": "Rimadyl (Pain Relief)", "stock_qty": 50, "reorder_level": 10, "unit_price": 25.00},
            {"name": "Clavamox (Antibiotic)", "stock_qty": 75, "reorder_level": 15, "unit_price": 30.00},
            {"name": "Gabapentin (Nerve Pain)", "stock_qty": 200, "reorder_level": 50, "unit_price": 12.00}
        ]
        conn.execute(text("""
            INSERT INTO medications (name, stock_qty, reorder_level, unit_price)
            VALUES (:name, :stock_qty, :reorder_level, :unit_price)
        """), med_data)

    med_ids = [row[0] for row in conn.execute(text("SELECT medication_id FROM medications")).fetchall()]
    animal_ids = [row[0] for row in conn.execute(text("SELECT animal_id FROM animals LIMIT 200")).fetchall()]
    vet_ids = [row[0] for row in conn.execute(text("SELECT vet_id FROM veterinarians")).fetchall()]

    if not animal_ids or not vet_ids:
        print("Error: Make sure animals and veterinarians tables have data first.")
    else:
        # 2. Populate Vaccinations
        vac_data = []
        for a_id in random.sample(animal_ids, k=min(50, len(animal_ids))):
            vac_date = date.today() - timedelta(days=random.randint(1, 300))
            vac_data.append({
                "animal_id": a_id,
                "vet_id": random.choice(vet_ids),
                "vaccine_name": random.choice(["Rabies (1-year)", "DHPP", "Bordetella", "FVRCP"]),
                "date_administered": vac_date,
                "next_due_date": vac_date + timedelta(days=365)
            })
        conn.execute(text("""
            INSERT INTO vaccinations (animal_id, vet_id, vaccine_name, date_administered, next_due_date)
            VALUES (:animal_id, :vet_id, :vaccine_name, :date_administered, :next_due_date)
        """), vac_data)

        # 3. Ensure Appointments exist
        appt_ids = [row[0] for row in conn.execute(text("SELECT appointment_id FROM appointments")).fetchall()]
        if not appt_ids:
            appt_data = []
            for a_id in random.sample(animal_ids, k=min(40, len(animal_ids))):
                appt_data.append({
                    "animal_id": a_id,
                    "vet_id": random.choice(vet_ids),
                    "appointment_datetime": datetime.now() - timedelta(days=random.randint(1, 60)),
                    "reason": random.choice(["General Checkup", "Limping", "Skin Infection", "Lethargy"]),
                    "status": "Completed"
                })
            conn.execute(text("""
                INSERT INTO appointments (animal_id, vet_id, appointment_datetime, reason, status)
                VALUES (:animal_id, :vet_id, :appointment_datetime, :reason, :status)
            """), appt_data)
            appt_ids = [row[0] for row in conn.execute(text("SELECT appointment_id FROM appointments")).fetchall()]

        # 4. Generate Medical Records & Invoices for Appointments
        existing_records = [row[0] for row in conn.execute(text("SELECT appointment_id FROM medical_records")).fetchall()]
        unrecorded_appts = [a for a in appt_ids if a not in existing_records]

        med_rec_data, invoice_data = [], []
        for appt_id in unrecorded_appts:
            med_rec_data.append({
                "appointment_id": appt_id,
                "diagnosis": random.choice(["Healthy", "Minor Sprain", "Bacterial Infection", "Allergies"]),
                "treatment": random.choice(["Rest", "Prescribed Antibiotics", "Diet Change", "Pain Management"])
            })
            invoice_data.append({
                "appointment_id": appt_id,
                "invoice_date": date.today() - timedelta(days=random.randint(1, 30)),
                "amount": round(random.uniform(50.0, 250.0), 2),
                "status": "Paid"
            })

        if med_rec_data:
            conn.execute(text("""
                INSERT INTO medical_records (appointment_id, diagnosis, treatment)
                VALUES (:appointment_id, :diagnosis, :treatment)
            """), med_rec_data)
        if invoice_data:
            conn.execute(text("""
                INSERT INTO invoices (appointment_id, invoice_date, amount, status)
                VALUES (:appointment_id, :invoice_date, :amount, :status)
            """), invoice_data)

        # 5. Generate Prescriptions & Payments
        records = conn.execute(text("SELECT record_id FROM medical_records")).fetchall()

        # Prevent double-paying invoices on multiple script runs
        invoices = conn.execute(text("""
            SELECT invoice_id, amount, invoice_date FROM invoices
            WHERE invoice_id NOT IN (SELECT invoice_id FROM payments)
        """)).fetchall()

        rx_data = []
        for rec in records:
            if random.random() > 0.5: # 50% chance of getting a prescription
                rx_data.append({
                    "record_id": rec[0],
                    "medication_id": random.choice(med_ids),
                    "quantity": random.randint(10, 30),
                    "dosage": "1 tablet twice daily"
                })
        # Ignore duplicate prescriptions if script is run again
        conn.execute(text("DELETE FROM prescriptions"))

        if rx_data:
            conn.execute(text("""
                INSERT INTO prescriptions (record_id, medication_id, quantity, dosage)
                VALUES (:record_id, :medication_id, :quantity, :dosage)
            """), rx_data)

        payment_data = []
        for inv in invoices:
            payment_data.append({
                "invoice_id": inv[0],
                "payment_date": inv[2],
                "amount": inv[1],
                "method": random.choice(["Credit Card", "Cash", "Pet Insurance"])
            })
        if payment_data:
            conn.execute(text("""
                INSERT INTO payments (invoice_id, payment_date, amount, method)
                VALUES (:invoice_id, :payment_date, :amount, :method)
            """), payment_data)

        print("Success! Veterinary clinic and billing tables have been fully populated.")