-- Runs before Hibernate update, atomically and idempotently. Never invent a baseline.
DO $$
DECLARE
    target_schema text := current_schema();
    plan_table text := format('%I.meal_plans', target_schema);
    recipe_table text := format('%I.recipes', target_schema);
BEGIN
    IF to_regclass(plan_table) IS NOT NULL THEN
        EXECUTE format('ALTER TABLE %s ADD COLUMN IF NOT EXISTS planned_servings integer', plan_table);
        EXECUTE format('UPDATE %s p SET planned_servings=r.servings FROM %s r WHERE p.recipe_id=r.id AND p.planned_servings IS NULL AND r.servings>0', plan_table, recipe_table);
        -- Invalid/null recipe baselines leave legacy plans unresolved (NULL), not guessed.
        -- New plans are required by the API to provide a positive count. CHECK protects SQL writes.
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid=to_regclass(plan_table) AND conname='ck_meal_plans_planned_servings_positive') THEN
            EXECUTE format('ALTER TABLE %s ADD CONSTRAINT ck_meal_plans_planned_servings_positive CHECK (planned_servings>0)', plan_table);
        END IF;
    END IF;
END
$$@@
