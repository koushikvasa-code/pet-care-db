CREATE DATABASE IF NOT EXISTS pet_care_db
CHARACTER SET utf8mb4
COLLATE utf8mb4_unicode_ci;

USE pet_care_db;

CREATE TABLE IF NOT EXISTS shelters (
    shelter_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    phone VARCHAR(30),
    email VARCHAR(150),
    capacity INT,
    CHECK (capacity IS NULL OR capacity >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS animal_types (
    type_id INT AUTO_INCREMENT PRIMARY KEY,
    type_name VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS breeds (
    breed_id INT AUTO_INCREMENT PRIMARY KEY,
    breed_name VARCHAR(120) NOT NULL,
    type_id INT NOT NULL,
    UNIQUE (breed_name, type_id),
    FOREIGN KEY (type_id) REFERENCES animal_types(type_id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS adopters (
    adopter_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    phone VARCHAR(30),
    address VARCHAR(255),
    email VARCHAR(150) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS animals (
    animal_id BIGINT PRIMARY KEY,
    name VARCHAR(120),
    type_id INT NOT NULL,
    breed_id INT,
    shelter_id INT,
    sex VARCHAR(30),
    date_of_birth DATE,
    life_stage VARCHAR(40),
    spayed_neutered VARCHAR(20),
    primary_color VARCHAR(80),
    secondary_color VARCHAR(80),
    status VARCHAR(40) NOT NULL DEFAULT 'Unknown',
    FOREIGN KEY (type_id) REFERENCES animal_types(type_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (breed_id) REFERENCES breeds(breed_id)
      ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY (shelter_id) REFERENCES shelters(shelter_id)
      ON UPDATE CASCADE ON DELETE SET NULL,
    INDEX idx_animals_type_status (type_id, status),
    INDEX idx_animals_breed (breed_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS intakes (
    intake_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    source_record_id BIGINT NOT NULL UNIQUE,
    animal_id BIGINT NOT NULL,
    shelter_id INT NOT NULL,
    intake_date DATETIME NOT NULL,
    intake_type VARCHAR(100),
    FOREIGN KEY (animal_id) REFERENCES animals(animal_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (shelter_id) REFERENCES shelters(shelter_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_intake_animal_date (animal_id, intake_date),
    INDEX idx_intake_shelter_date (shelter_id, intake_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS outcomes (
    outcome_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    intake_id BIGINT NOT NULL UNIQUE,
    outcome_date DATETIME NOT NULL,
    outcome_group VARCHAR(100) NOT NULL,
    euthanasia_reason VARCHAR(255),
    days_in_shelter INT,
    FOREIGN KEY (intake_id) REFERENCES intakes(intake_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (days_in_shelter IS NULL OR days_in_shelter >= 0),
    INDEX idx_outcome_group_date (outcome_group, outcome_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS adoption_applications (
    application_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    animal_id BIGINT NOT NULL,
    adopter_id INT NOT NULL,
    application_date DATE NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'Pending',
    FOREIGN KEY (animal_id) REFERENCES animals(animal_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (adopter_id) REFERENCES adopters(adopter_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_application_animal_status (animal_id, status),
    INDEX idx_application_adopter_date (adopter_id, application_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS adoptions (
    adoption_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    application_id BIGINT NOT NULL UNIQUE,
    intake_id BIGINT NOT NULL UNIQUE,
    adoption_date DATE NOT NULL,
    adoption_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (application_id) REFERENCES adoption_applications(application_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (intake_id) REFERENCES intakes(intake_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (adoption_fee >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clinics (
    clinic_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    city VARCHAR(100),
    phone VARCHAR(30)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS veterinarians (
    vet_id INT AUTO_INCREMENT PRIMARY KEY,
    clinic_id INT NOT NULL,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    license_number VARCHAR(80) UNIQUE,
    phone VARCHAR(30),
    specialty VARCHAR(100),
    FOREIGN KEY (clinic_id) REFERENCES clinics(clinic_id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS appointments (
    appointment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    animal_id BIGINT NOT NULL,
    vet_id INT NOT NULL,
    appointment_datetime DATETIME NOT NULL,
    reason VARCHAR(255),
    status VARCHAR(40) NOT NULL DEFAULT 'Scheduled',
    FOREIGN KEY (animal_id) REFERENCES animals(animal_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (vet_id) REFERENCES veterinarians(vet_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_appointment_animal_date (animal_id, appointment_datetime),
    INDEX idx_appointment_vet_date (vet_id, appointment_datetime)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS vaccinations (
    vaccination_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    animal_id BIGINT NOT NULL,
    vet_id INT NOT NULL,
    vaccine_name VARCHAR(120) NOT NULL,
    date_administered DATE NOT NULL,
    next_due_date DATE,
    FOREIGN KEY (animal_id) REFERENCES animals(animal_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (vet_id) REFERENCES veterinarians(vet_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_vaccination_animal_due (animal_id, next_due_date)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS medical_records (
    record_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    appointment_id BIGINT NOT NULL UNIQUE,
    diagnosis TEXT,
    treatment TEXT,
    FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id)
      ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS medications (
    medication_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE,
    stock_qty INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 0,
    unit_price DECIMAL(10,2) NOT NULL,
    CHECK (stock_qty >= 0),
    CHECK (reorder_level >= 0),
    CHECK (unit_price >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS prescriptions (
    prescription_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_id BIGINT NOT NULL,
    medication_id INT NOT NULL,
    quantity INT NOT NULL,
    dosage VARCHAR(120),
    FOREIGN KEY (record_id) REFERENCES medical_records(record_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    FOREIGN KEY (medication_id) REFERENCES medications(medication_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (quantity > 0),
    INDEX idx_prescription_medication (medication_id)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS invoices (
    invoice_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    appointment_id BIGINT UNIQUE,
    adoption_id BIGINT UNIQUE,
    invoice_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'Unpaid',

    FOREIGN KEY (appointment_id)
      REFERENCES appointments(appointment_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,

    FOREIGN KEY (adoption_id)
      REFERENCES adoptions(adoption_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,

    CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS payments (
    payment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    invoice_id BIGINT NOT NULL,
    payment_date DATETIME NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    method VARCHAR(40),
    FOREIGN KEY (invoice_id) REFERENCES invoices(invoice_id)
      ON UPDATE CASCADE ON DELETE RESTRICT,
    CHECK (amount > 0),
    INDEX idx_payment_invoice_date (invoice_id, payment_date)
) ENGINE=InnoDB;

-- Raw import table. Dates remain text until the cleaning step.
CREATE TABLE IF NOT EXISTS staging_outcomes (
    source_record_id BIGINT PRIMARY KEY,
    outcome_date_raw VARCHAR(40) NOT NULL,
    source_animal_id BIGINT NOT NULL,
    animal_name VARCHAR(120),
    outcome_status VARCHAR(100) NOT NULL,
    euthanasia_reason VARCHAR(255),
    animal_type VARCHAR(80) NOT NULL,
    sex VARCHAR(30),
    spayed_neutered VARCHAR(20),
    primary_breed VARCHAR(120) NOT NULL,
    primary_color VARCHAR(80),
    secondary_color VARCHAR(80),
    date_of_birth_raw VARCHAR(40),
    intake_date_raw VARCHAR(40) NOT NULL,
    days_in_shelter_raw VARCHAR(20),
    timestamp_raw VARCHAR(40)
) ENGINE=InnoDB;
