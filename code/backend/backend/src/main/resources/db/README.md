# Database setup

## Fresh local database

`bootstrap.sql` contains the current PostgreSQL schema generated from the JPA model. It contains no accounts, credentials or recipe data. It runs inside a transaction and is intended only for an empty, isolated database.

Create a local database named `demo`, then apply the script manually from the backend directory:

```powershell
psql -h localhost -U YOUR_LOCAL_DATABASE_USER -d demo -v ON_ERROR_STOP=1 -f src/main/resources/db/bootstrap.sql
```

Supply the password privately when prompted. Never run this script on an existing populated database. Do not run the historical upgrades after a fresh bootstrap; the generated schema already includes the current model. The export was generated without a database connection; live PostgreSQL application and startup validation still need verification.

The backend defaults to Hibernate `validate` and `spring.sql.init.mode=never`; no script runs automatically. Start the backend after schema creation to validate its table/column mappings. Use the app to register a local account and create recipes; the optional JSON data in `code/data/seeds/` is not loaded automatically.

## Existing development databases

The following files are historical manual upgrades, in order:

1. `day15-nutrition-foundation.sql`
2. `day18-planned-servings.sql`
3. `day24-meal-plan-snapshots.sql`
4. `day25-grocery-contributions.sql`
5. `day27-integrity.sql`

The day numbers identify migration order. Review the target schema and take a backup before any upgrade. Some historical scripts use a custom `@@` statement separator; they are not directly executable as standard psql scripts. They are retained for existing-schema reference, not as an automated migration system.

Existing JVM tests use mock repositories and do not validate PostgreSQL migrations. No existing development database was changed during the repository cleanup.
