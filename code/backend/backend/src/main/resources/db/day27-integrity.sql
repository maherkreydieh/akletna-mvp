-- Add constraints without discarding or guessing how to merge existing data.
-- An invalid upgrade is stopped atomically so it can be reviewed explicitly.
DO $$
BEGIN
    IF to_regclass('users') IS NOT NULL THEN
        LOCK TABLE users IN SHARE ROW EXCLUSIVE MODE;
        IF EXISTS (SELECT 1 FROM users WHERE email IS NULL OR trim(email) = '' OR email <> lower(trim(email)))
           OR EXISTS (SELECT 1 FROM users GROUP BY email HAVING count(*) > 1) THEN
            RAISE EXCEPTION 'Account integrity upgrade requires review of existing email identities; no rows changed.';
        END IF;
        ALTER TABLE users ALTER COLUMN email SET NOT NULL;
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='users'::regclass AND conname='uq_users_email') THEN
            ALTER TABLE users ADD CONSTRAINT uq_users_email UNIQUE(email);
        END IF;
    END IF;
    IF to_regclass('meal_plans') IS NOT NULL THEN
        LOCK TABLE meal_plans IN SHARE ROW EXCLUSIVE MODE;
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='meal_plans'::regclass AND conname='uq_meal_plan_slot') THEN
            IF EXISTS (SELECT 1 FROM meal_plans GROUP BY user_id,date,meal_type HAVING count(*)>1) THEN
                RAISE EXCEPTION 'Meal slot integrity upgrade requires review of existing duplicates; no rows changed.';
            END IF;
            ALTER TABLE meal_plans ADD CONSTRAINT uq_meal_plan_slot UNIQUE(user_id,date,meal_type);
        END IF;
    END IF;
    IF to_regclass('recipe_ingredients') IS NOT NULL THEN
        LOCK TABLE recipe_ingredients IN SHARE ROW EXCLUSIVE MODE;
        IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conrelid='recipe_ingredients'::regclass AND conname='uq_recipe_ingredient') THEN
            IF EXISTS (SELECT 1 FROM recipe_ingredients GROUP BY recipe_id,ingredient_id HAVING count(*)>1) THEN
                RAISE EXCEPTION 'Recipe ingredient integrity upgrade requires review of existing duplicates; no rows changed.';
            END IF;
            ALTER TABLE recipe_ingredients ADD CONSTRAINT uq_recipe_ingredient UNIQUE(recipe_id,ingredient_id);
        END IF;
    END IF;
END
$$@@
