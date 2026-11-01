# Architecture

## Request flow

Flutter screen → service → shared Dio API client → authenticated HTTP endpoint → Spring controller → service → repository → PostgreSQL.

The Flutter app renders server results. Ownership, recipe visibility, quantities, dietary evaluation, nutrition and recommendation scores are enforced or calculated by the backend.

## Flutter boundaries

- `screens/`: feature screens grouped by authentication, recipes, pantry, planning, groceries and preferences.
- `widgets/`: reusable presentation components, including recipe images and navigation.
- `models/`: typed API payloads and view data.
- `services/`: feature API calls; injectable services allow widget tests to run without a server.
- `core/network/`: Dio client, bearer-token attachment and API errors.
- `core/storage/`: secure token storage. `core/theme/`, `constants/` and `presentation/` own shared styling and labels.

`KitchenShell` owns the primary tabs. `HomeScreen` connects dashboard actions to the feature screens. Screens should not make raw HTTP calls or decide whether another user's resource is accessible.

## Backend boundaries

- `controller/` validates HTTP requests and delegates use cases.
- `dto/` defines API requests and responses; persistence entities are not the public contract.
- `service/` owns transactions, access checks and domain rules.
- `repository/` owns JPA queries. `entity/` defines the stored model and constraints.
- `config/` handles JWT authentication, API errors and CORS. Authentication throttling is not implemented.
- `nutrition/` separates persisted nutrient snapshots from curator-only USDA lookups.

Keep recipe mutation in `RecipeService`; discovery, evaluation, nutrition and saved bookmarks have focused services. `RecommendationPolicy` owns ranking rules and `RecommendationService` orchestrates selection. Pantry matching and quantity/unit handling are shared by groceries and recipe comparisons.

## API feature inventory

All business routes require a valid JWT. User identity comes from authentication, not a client-supplied user ID.

| Routes | Responsibility |
|---|---|
| `/api/auth/register`, `/api/auth/login` | Public authentication |
| `/api/users/me`, `/api/users/me/profile`, `/api/preferences` | Current user's profile and preferences |
| `/api/ingredients` | Ingredient catalog reads and validated additions; ordinary users cannot update or delete shared entries |
| `/api/recipes` and its library/community/mine/saved routes | Readable recipes, owner mutations and bookmarks |
| `/api/recipes/{id}/ingredients`, `/{id}/nutrition` | Recipe ingredient lines and calculated nutrition |
| `/api/recipes/recommendations`, `/home` | Ranked selection and dashboard recommendations |
| `/api/pantry` and `/api/recipes/pantry-matches` | Current user's inventory and matching |
| `/api/meal-plans` | Current user's dated meal slots and snapshots |
| `/api/grocery-list` | Weekly grocery generation, purchased state and recipe contributions |
| `/api/nutrition/curation` | Curator USDA lookup and reviewed nutrition mappings |
| `/api/food-metadata/curation` | Curator allergen and dietary classifications |

Curator routes additionally require `X-Nutrition-Curator-Token`. They are operational catalog maintenance, not an alternative user role. The configured token must remain private; leaving it empty denies access.

## Data and security

Private recipes are visible only to their owner. Public recipes can be read by authenticated users, but editing remains owner-controlled; curated recipes cannot be changed through ordinary recipe CRUD. Pantry, plans, bookmarks and groceries are scoped to the current user.

Planned meals capture recipe snapshots. Grocery contributions capture their source lines; later private recipe edits do not become visible through old snapshots. Shared catalog metadata is reviewed separately from user-authored recipe text.

Normal nutrition reads use stored reviewed data without network calls. Missing or invalid data remains unknown. USDA access is confined to the curator workflow. There is no event tracking, inferred saved-category ranking, reset-token subsystem or automatic recipe import in the MVP.

Schema validation is enabled, automatic SQL initialization is disabled, and local credentials are ignored. Backend tests use mocks and generated keys rather than the development database. Flutter tests use fake services and HTTP adapters. These checks do not replace database migration, device or deployment testing.
