# Quantify Jiujitsu Database

This directory contains database schema definitions, migrations, and documentation for the Quantify Jiujitsu application.

## Directory Structure

```
qj_db/
├── README.md                 # This file
├── schema/                   # Core schema definitions 
│   ├── init.sql              # Initial database setup
│   └── tables.sql            # Main table definitions
├── migrations/               # Database migration scripts
│   ├── owner_name_to_id.sql  # Migration from owner_name to owner_id
│   ├── full_text_search.sql  # Full-text search implementation
│   └── game_plan_schema.sql  # Game plan feature schema
├── functions/                # Database functions and triggers
│   └── search_vector.sql     # Full-text search functions and triggers
├── documentation/            # Documentation files
│   ├── MIGRATION_PLAN.md     # Detailed migration plans
│   └── schema_reference.md   # Schema reference documentation
└── utils/                    # Utility scripts
    └── seed_data.sql         # Test data generation
```

## Setup Instructions

1. Create a new PostgreSQL database
2. Run the initial schema setup:
   ```
   psql -d your_database -f schema/init.sql
   psql -d your_database -f schema/tables.sql
   ```
3. Apply migrations as needed:
   ```
   psql -d your_database -f migrations/full_text_search.sql
   ```

## Key Features

### Full-Text Search

The database implements PostgreSQL full-text search for posts with weighted ranking:
- Titles (A weight) - highest priority
- Starting/ending positions, practitioner, movement type (B weight) - medium priority
- Position types (C weight) - lower priority

### Referential Integrity

- Posts are linked to users via a proper foreign key relationship (owner_id → users.id)
- Profiles contain extended user information but maintain user_id reference

### Security

- Password hashing implemented at application level
- Row-level security through ownership checks in application code
- Separate lambda_user with limited privileges

## Maintenance

When making schema changes:
1. Create a migration script in the `migrations/` directory
2. Update the schema reference documentation
3. Test the migration on a staging database before production# qj_db
