CREATE DATABASE IF NOT EXISTS pet_care_db
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE pet_care_db;

-- Drop in dependency order so this script can be rerun during development.
SET FOREIGN_KEY_CHECKS = 0;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS invoices;
DROP TABLE IF EXISTS prescriptions;
DROP TABLE IF EXISTS medications;
DROP TABLE IF EXISTS medical_records;
DROP TABLE IF EXISTS vaccinations;
DROP TABLE IF EXISTS appointments;
DROP TABLE IF EXISTS veterinarians;
DROP TABLE IF EXISTS clinics;
DROP TABLE IF EXISTS adoptions;
DROP TABLE IF EXISTS adoption_applications;
DROP TABLE IF EXISTS outcomes;
DROP TABLE IF EXISTS intakes;
DROP TABLE IF EXISTS animals;
DROP TABLE IF EXISTS adopters;
DROP TABLE IF EXISTS breeds;
DROP TABLE IF EXISTS animal_types;
DROP TABLE IF EXISTS shelters;
DROP TABLE IF EXISTS staging_outcomes;
SET FOREIGN_KEY_CHECKS = 1;

-- LOOKUP / CORE TABLES

CREATE TABLE shelters (
    shelter_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    address VARCHAR(255),
    city VARCHAR(100),
    phone VARCHAR(30),
    email VARCHAR(150),
    capacity INT,
    CONSTRAINT chk_shelter_capacity CHECK (capacity IS NULL OR capacity >= 0)
) ENGINE=InnoDB;

CREATE TABLE animal_types (
    type_id INT AUTO_INCREMENT PRIMARY KEY,
    type_name VARCHAR(80) NOT NULL UNIQUE
) ENGINE=InnoDB;

CREATE TABLE breeds (
    breed_id INT AUTO_INCREMENT PRIMARY KEY,
    breed_name VARCHAR(120) NOT NULL,
    type_id INT NOT NULL,
    CONSTRAINT uq_breed_type UNIQUE (breed_name, type_id),
    CONSTRAINT fk_breed_type FOREIGN KEY (type_id)
        REFERENCES animal_types(type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE adopters (
    adopter_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    phone VARCHAR(30),
    address VARCHAR(255),
    email VARCHAR(150) UNIQUE
) ENGINE=InnoDB;

CREATE TABLE animals (
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
    CONSTRAINT fk_animal_type FOREIGN KEY (type_id)
        REFERENCES animal_types(type_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_animal_breed FOREIGN KEY (breed_id)
        REFERENCES breeds(breed_id)
        ON UPDATE CASCADE ON DELETE SET NULL,
    CONSTRAINT fk_animal_shelter FOREIGN KEY (shelter_id)
        REFERENCES shelters(shelter_id)
        ON UPDATE CASCADE ON DELETE SET NULL
) ENGINE=InnoDB;

-- SHELTER INTAKE / OUTCOME HISTORY

CREATE TABLE intakes (
    intake_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    source_record_id BIGINT UNIQUE,
    animal_id BIGINT NOT NULL,
    shelter_id INT NOT NULL,
    intake_date DATETIME NOT NULL,
    intake_type VARCHAR(100),
    CONSTRAINT fk_intake_animal FOREIGN KEY (animal_id)
        REFERENCES animals(animal_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_intake_shelter FOREIGN KEY (shelter_id)
        REFERENCES shelters(shelter_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_intake_animal_date (animal_id, intake_date),
    INDEX idx_intake_shelter_date (shelter_id, intake_date)
) ENGINE=InnoDB;

CREATE TABLE outcomes (
    outcome_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    intake_id BIGINT NOT NULL UNIQUE,
    outcome_date DATETIME NOT NULL,
    outcome_group VARCHAR(100) NOT NULL,
    euthanasia_reason VARCHAR(255),
    days_in_shelter INT,
    CONSTRAINT fk_outcome_intake FOREIGN KEY (intake_id)
        REFERENCES intakes(intake_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_days_in_shelter CHECK (days_in_shelter IS NULL OR days_in_shelter >= 0),
    INDEX idx_outcome_group_date (outcome_group, outcome_date)
) ENGINE=InnoDB;

-- ADOPTION

CREATE TABLE adoption_applications (
    application_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    animal_id BIGINT NOT NULL,
    adopter_id INT NOT NULL,
    application_date DATE NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'Pending',
    CONSTRAINT fk_application_animal FOREIGN KEY (animal_id)
        REFERENCES animals(animal_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_application_adopter FOREIGN KEY (adopter_id)
        REFERENCES adopters(adopter_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_application_animal_status (animal_id, status),
    INDEX idx_application_adopter_date (adopter_id, application_date)
) ENGINE=InnoDB;

CREATE TABLE adoptions (
    adoption_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    application_id BIGINT NOT NULL UNIQUE,
    intake_id BIGINT NOT NULL UNIQUE,
    adoption_date DATE NOT NULL,
    adoption_fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT fk_adoption_application FOREIGN KEY (application_id)
        REFERENCES adoption_applications(application_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_adoption_intake FOREIGN KEY (intake_id)
        REFERENCES intakes(intake_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_adoption_fee CHECK (adoption_fee >= 0)
) ENGINE=InnoDB;

-- VETERINARY

CREATE TABLE clinics (
    clinic_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    city VARCHAR(100),
    phone VARCHAR(30)
) ENGINE=InnoDB;

CREATE TABLE veterinarians (
    vet_id INT AUTO_INCREMENT PRIMARY KEY,
    clinic_id INT NOT NULL,
    first_name VARCHAR(80) NOT NULL,
    last_name VARCHAR(80) NOT NULL,
    license_number VARCHAR(80) UNIQUE,
    phone VARCHAR(30),
    specialty VARCHAR(100),
    CONSTRAINT fk_vet_clinic FOREIGN KEY (clinic_id)
        REFERENCES clinics(clinic_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

CREATE TABLE appointments (
    appointment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    animal_id BIGINT NOT NULL,
    vet_id INT NOT NULL,
    appointment_datetime DATETIME NOT NULL,
    reason VARCHAR(255),
    status VARCHAR(40) NOT NULL DEFAULT 'Scheduled',
    CONSTRAINT fk_appointment_animal FOREIGN KEY (animal_id)
        REFERENCES animals(animal_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_appointment_vet FOREIGN KEY (vet_id)
        REFERENCES veterinarians(vet_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_appointment_animal_date (animal_id, appointment_datetime),
    INDEX idx_appointment_vet_date (vet_id, appointment_datetime)
) ENGINE=InnoDB;

CREATE TABLE vaccinations (
    vaccination_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    animal_id BIGINT NOT NULL,
    vet_id INT NOT NULL,
    vaccine_name VARCHAR(120) NOT NULL,
    date_administered DATE NOT NULL,
    next_due_date DATE,
    CONSTRAINT fk_vaccination_animal FOREIGN KEY (animal_id)
        REFERENCES animals(animal_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_vaccination_vet FOREIGN KEY (vet_id)
        REFERENCES veterinarians(vet_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_vaccination_animal_due (animal_id, next_due_date)
) ENGINE=InnoDB;

CREATE TABLE medical_records (
    record_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    appointment_id BIGINT NOT NULL UNIQUE,
    diagnosis TEXT,
    treatment TEXT,
    CONSTRAINT fk_record_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointments(appointment_id)
        ON UPDATE CASCADE ON DELETE RESTRICT
) ENGINE=InnoDB;

-- PHARMACY / BILLING

CREATE TABLE medications (
    medication_id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL UNIQUE,
    stock_qty INT NOT NULL DEFAULT 0,
    reorder_level INT NOT NULL DEFAULT 0,
    unit_price DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_med_stock CHECK (stock_qty >= 0),
    CONSTRAINT chk_med_reorder CHECK (reorder_level >= 0),
    CONSTRAINT chk_med_price CHECK (unit_price >= 0)
) ENGINE=InnoDB;

CREATE TABLE prescriptions (
    prescription_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    record_id BIGINT NOT NULL,
    medication_id INT NOT NULL,
    quantity INT NOT NULL,
    dosage VARCHAR(120),
    CONSTRAINT fk_prescription_record FOREIGN KEY (record_id)
        REFERENCES medical_records(record_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_prescription_medication FOREIGN KEY (medication_id)
        REFERENCES medications(medication_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_prescription_quantity CHECK (quantity > 0),
    INDEX idx_prescription_medication (medication_id)
) ENGINE=InnoDB;

CREATE TABLE invoices (
    invoice_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    appointment_id BIGINT UNIQUE,
    adoption_id BIGINT UNIQUE,
    invoice_date DATE NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'Unpaid',
    CONSTRAINT fk_invoice_appointment FOREIGN KEY (appointment_id)
        REFERENCES appointments(appointment_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_invoice_adoption FOREIGN KEY (adoption_id)
        REFERENCES adoptions(adoption_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_invoice_one_source CHECK (
        (appointment_id IS NOT NULL AND adoption_id IS NULL) OR
        (appointment_id IS NULL AND adoption_id IS NOT NULL)
    ),
    CONSTRAINT chk_invoice_amount CHECK (amount >= 0)
) ENGINE=InnoDB;

CREATE TABLE payments (
    payment_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    invoice_id BIGINT NOT NULL,
    payment_date DATETIME NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    method VARCHAR(40),
    CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id)
        REFERENCES invoices(invoice_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_payment_amount CHECK (amount > 0),
    INDEX idx_payment_invoice_date (invoice_id, payment_date)
) ENGINE=InnoDB;

-- CSV STAGING TABLE

CREATE TABLE staging_outcomes (
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


