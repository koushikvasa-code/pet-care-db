# Pet Adoption & Veterinary Care Management Database

**Author:** Koushik Vasa

This project implements a fully normalized 3NF MySQL relational database for tracking pet shelter intakes, outcomes, adoptions, and veterinary care. It integrates real-world data from the Austin Animal Center (19,619 records) alongside synthetic data generated via Python to fulfill volume and testing requirements.

## Prerequisites
* **macOS Environment** with Homebrew installed
* **MySQL Server 8.0+** (`brew install mysql`)
* **Python 3** with `pip`
* Database Client (DBeaver, MySQL Workbench, or native terminal) for querying

## Python Dependencies
Install the required Python libraries for synthetic data generation:
```bash
pip install sqlalchemy mysql-connector-python faker
```

## Setup & Execution Instructions

**Note:** For robust execution and to prevent IDE extension timeouts on large bulk inserts, all database builds and data ETL steps must be executed natively in the Mac terminal.

### 1. Initialize the Database Schema
Navigate to the project root directory and log into MySQL with local file reading permissions:
```bash
cd /Users/koushikvasa/pet-care-db
mysql -u root -p --local-infile=1
```
Drop any existing conflicts and create the fresh schema:
```sql
DROP DATABASE IF EXISTS pet_care_db;
CREATE DATABASE pet_care_db;
USE pet_care_db;
source database/create_database.sql;
```

### 2. Import Raw Staging Data
Execute the import script to safely load the raw CSV data into the staging table (ensure you are still in the MySQL prompt from Step 1):
```sql
source data/import_dataset.sql;
```
*(Note: The `import_dataset.sql` file contains the specific `LOAD DATA LOCAL INFILE` command required to execute the bulk import without crashing).*

### 3. Clean and Distribute Relational Data
Process the raw data to remove invalid characters, cast integers, and distribute the staging data into the normalized relational tables (`animals`, `intakes`, `outcomes`):
```sql
source data/clean_data.sql;
```
*Once this completes successfully, type `exit;` to leave the MySQL terminal.*

### 4. Generate Synthetic Data
Execute the Python script to map 1,000 synthetic adopters, clinics, veterinarians, and appointments to the real animals in the database:
```bash
python3 generate_data.py
```

### 5. Run Queries
With the database completely populated, run your query files from the `queries/` folder in your preferred database GUI or IDE to view the integrated results.