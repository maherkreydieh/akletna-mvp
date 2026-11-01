-- Existing pre-Hibernate migration convention. One atomic, repeatable migration.
-- Legacy snapshots describe migration-time state, never invented historical state.
DO $$
BEGIN
    IF to_regclass('meal_plans') IS NOT NULL THEN
        LOCK TABLE meal_plans, recipes IN SHARE ROW EXCLUSIVE MODE;
        ALTER TABLE meal_plans ADD COLUMN IF NOT EXISTS snapshot_state varchar(20) DEFAULT 'PENDING';
        ALTER TABLE meal_plans ADD COLUMN IF NOT EXISTS snapshot_name varchar(255);
        ALTER TABLE meal_plans ADD COLUMN IF NOT EXISTS snapshot_category varchar(255);
        ALTER TABLE meal_plans ADD COLUMN IF NOT EXISTS snapshot_image_url varchar(255);
        ALTER TABLE meal_plans ADD COLUMN IF NOT EXISTS snapshot_base_servings integer;
        ALTER TABLE meal_plans ADD COLUMN IF NOT EXISTS snapshot_captured_at timestamp(6);
        CREATE TABLE IF NOT EXISTS meal_plan_ingredient_snapshots (
            meal_plan_id bigint NOT NULL REFERENCES meal_plans(id) ON DELETE CASCADE,
            line_index integer NOT NULL,
            ingredient_id bigint NOT NULL,
            ingredient_name varchar(255) NOT NULL,
            quantity numeric(24,12) NOT NULL,
            unit varchar(30),
            PRIMARY KEY(meal_plan_id,line_index)
        );
        IF to_regclass('recipe_ingredients') IS NOT NULL AND to_regclass('ingredients') IS NOT NULL THEN
            LOCK TABLE recipe_ingredients, ingredients IN SHARE ROW EXCLUSIVE MODE;
            WITH captured AS (
            UPDATE meal_plans p SET snapshot_state='READY', snapshot_name=r.name,
                snapshot_category=to_jsonb(r)->>'category', snapshot_image_url=to_jsonb(r)->>'image_url',
                snapshot_base_servings=r.servings, snapshot_captured_at=CURRENT_TIMESTAMP
            FROM recipes r
            WHERE p.recipe_id=r.id AND (p.snapshot_state IS NULL OR p.snapshot_state='PENDING')
                AND r.servings>0 AND NULLIF(btrim(r.name),'') IS NOT NULL
                AND (r.user_id=p.user_id OR coalesce(to_jsonb(r)->>'visibility','PRIVATE')='PUBLIC')
                AND NOT EXISTS (
                    SELECT 1 FROM recipe_ingredients ri LEFT JOIN ingredients i ON i.id=ri.ingredient_id
                    WHERE ri.recipe_id=r.id AND (i.id IS NULL OR NULLIF(btrim(i.name),'') IS NULL
                        OR ri.quantity IS NULL OR ri.quantity<=0 OR ri.quantity::text IN ('NaN','Infinity','-Infinity'))
                )
            RETURNING p.id,p.recipe_id
            )
            -- Only the rows updated above are copied, including same-transaction reruns.
            INSERT INTO meal_plan_ingredient_snapshots(meal_plan_id,line_index,ingredient_id,ingredient_name,quantity,unit)
            SELECT p.id, (row_number() OVER(PARTITION BY p.id ORDER BY ri.id)-1)::integer,
                   i.id,i.name,ri.quantity,ri.unit
            FROM captured p JOIN recipe_ingredients ri ON ri.recipe_id=p.recipe_id JOIN ingredients i ON i.id=ri.ingredient_id;
        END IF;
        UPDATE meal_plans SET snapshot_state='UNRESOLVED'
        WHERE snapshot_state IS NULL OR snapshot_state='PENDING';
    END IF;
END
$$@@
