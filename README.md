# Akletna

A Flutter app and Spring Boot API for Lebanese home cooking: find recipes using your pantry, plan meals, and generate a grocery list.

## Projects

- `code/akletna_frontend`: Flutter Android app, models, API clients and widget tests.
- `code/backend/backend`: Java 21 / Spring Boot API with PostgreSQL persistence and Maven tests.
- `code/data`: recipe and ingredient catalog data.
- `docs/IMAGE_CREDITS.md`: recipe image attribution and outstanding licence checks.

## Local setup

Use Flutter matching the SDK constraint in `pubspec.yaml`, Java 21 and PostgreSQL. The backend validates an existing schema; it never initializes or migrates a database automatically. Local database provisioning is required before startup. Historical schema upgrades are under `src/main/resources/db`; review them before manual use.

Copy `code/backend/backend/config/application-local.properties.example` to `application-local.properties` in the same directory and replace the placeholders privately. Alternatively provide `AKLETNA_DB_URL`, `AKLETNA_DB_USERNAME`, `AKLETNA_DB_PASSWORD` and `AKLETNA_JWT_SECRET` as environment variables. The signing key must be Base64 encoded and contain at least 32 random bytes. Never reuse example values or commit filled configuration.

For the local demo, select database `demo` and port `18091`. Keep Hibernate schema handling at `validate` and SQL initialization at `never`.

From `code/backend/backend`:

```powershell
.\mvnw.cmd test
.\mvnw.cmd spring-boot:run
```

From `code/akletna_frontend`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554
```

The Android emulator defaults to the local backend on port 18091. Override `AKLETNA_API_BASE_URL` with `--dart-define` when using a physical device. Local HTTP and debug signing are development settings; configure HTTPS and release signing before deployment.

## Pantry matching

Amount-free pantry items count as fully present while retaining the uncertain quantity label. Incompatible units receive partial credit; comparable shortages receive proportional credit. Water, salt, black pepper, olive oil and vegetable oil are assumed staples. Browse results require at least 50% before display rounding. Matching is an estimate: check quantities and dietary suitability before cooking.

Meal plans store recipe snapshots and serving counts. Grocery generation replaces the saved weekly list and resets purchased checks; recipe-specific additions are kept as separately removable contributions.

## Public repository hygiene

Private configuration, local instructions/notes, database exports, personal assets, logs and build output are excluded. Automated tests use synthetic accounts and generated test keys. No account data or database dump is required in the repository. Inspect `git status --short` and ignored-file rules before staging. This repository is a demo application, not a production deployment.
