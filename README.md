# Akletna MVP

A Flutter app and Spring Boot API for Lebanese home cooking. Browse recipes, match meals to your pantry, plan a week and build a grocery list.

## Features

- Register and sign in; edit your own profile and food preferences.
- Browse the curated recipe library and public community recipes.
- Create private or public recipes, edit your own recipes and save bookmarks.
- Manage pantry ingredients and compare recipe quantities with what you have.
- Get recommendations with reasons based on preferences and pantry information.
- Plan meals with serving counts; generate groceries and add recipe shortages.
- Display nutrition estimates when complete reviewed ingredient data is available.

Allergen and nutrition information can be incomplete. The app displays uncertainty; recipe matching is an estimate.

## Repository map

| Path | Purpose |
|---|---|
| `code/akletna_frontend/` | Flutter app, platform projects and widget tests |
| `code/backend/backend/` | Java 21 API, Maven wrapper and backend tests |
| `code/data/seeds/` | Original development recipe data; never loaded automatically |
| `docs/ARCHITECTURE.md` | Boundaries, data flow and API feature inventory |
| `docs/IMAGE_CREDITS.md` | Photo sources and reuse restrictions |

Android is the primary development target. Other Flutter platform folders are scaffolded and have not been independently verified.

## Local setup

Requires Java 21, PostgreSQL, and Flutter with Dart compatible with `^3.13.4`.

1. Use an isolated local database named `demo`. For an empty database, manually apply `code/backend/backend/src/main/resources/db/bootstrap.sql` with PostgreSQL before starting the backend. Do not apply it to an existing database. The backend validates the schema and does not create or migrate tables automatically. See `code/backend/backend/src/main/resources/db/README.md` before starting.
2. Copy `code/backend/backend/config/application-local.properties.example` to `application-local.properties` in the same directory. Fill in your private database connection and a Base64 JWT key containing at least 32 random bytes. The filled file is ignored by Git.
3. Start the backend, then launch the Flutter app.

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

The Android emulator connects to `http://10.0.2.2:18091`. For a physical device, set `--dart-define=AKLETNA_API_BASE_URL=http://YOUR_LOCAL_IP:18091` and use your connected device ID.

Environment variables can replace local configuration: `AKLETNA_DB_URL`, `AKLETNA_DB_USERNAME`, `AKLETNA_DB_PASSWORD`, `AKLETNA_JWT_SECRET`; `AKLETNA_SERVER_PORT` defaults to `18091`. Keep schema handling at `validate` and SQL initialization at `never`.

## Behavior to know

Pantry entries without quantities count as present but remain labelled uncertain. Comparable shortages receive proportional credit; incompatible units receive partial credit. Water, salt, black pepper, olive oil and vegetable oil are assumed staples. Browse results require at least 50% before rounding.

Meal plans retain recipe snapshots and serving counts. Regenerating the weekly grocery list replaces it and resets purchased checks. Recipe-specific additions remain separately removable contributions.

## Catalog administration

Reviewed allergen/dietary metadata and USDA nutrition mappings use separate curator API endpoints documented in `docs/ARCHITECTURE.md`. They require a valid user JWT plus the separately configured `AKLETNA_NUTRITION_CURATOR_TOKEN`; an empty token disables curator access. `AKLETNA_USDA_API_KEY` is needed only for curator USDA searches and mappings, not normal recipe reads. There is no admin screen, automatic importer, password-reset flow or background AI service.

## Publication and deployment

This is an MVP source repository, not a production deployment. Local HTTP and debug signing are development settings. Deployment requires HTTPS, release signing, managed secrets and an operational security review. Authentication throttling is not implemented; add deployment-level request limits before exposing the API to the internet.

Check image rights in `docs/IMAGE_CREDITS.md` before publication. No source-code licence has been selected; a public repository alone does not grant a general reuse licence. Photo licences are independent of the application code.
