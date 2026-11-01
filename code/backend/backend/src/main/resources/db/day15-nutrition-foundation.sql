-- Run before Hibernate update. Fail rather than round/truncate legacy quantities.
-- @@ is the Spring script separator; the DO block executes as one transaction.
DO $$
DECLARE
    target_schema text := current_schema();
    line_table text := format('%I.recipe_ingredients', target_schema);
    ingredient_table text := format('%I.ingredients', target_schema);
    unsafe_count bigint;
BEGIN
    IF to_regclass(line_table) IS NOT NULL THEN
        EXECUTE format('SELECT count(*) FROM %s WHERE quantity::text IN (''NaN'',''Infinity'',''-Infinity'')', line_table) INTO unsafe_count;
        IF unsafe_count > 0 THEN
            RAISE EXCEPTION 'Legacy ingredient quantities are not finite; migration stopped without changing them.';
        END IF;
        EXECUTE format('SELECT count(*) FROM %s WHERE abs(quantity::text::numeric) >= 1000000000000 OR quantity::text::numeric <> round(quantity::text::numeric,12)', line_table) INTO unsafe_count;
        IF unsafe_count > 0 THEN
            RAISE EXCEPTION 'Legacy ingredient quantities exceed decimal precision; migration stopped without rounding them.';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=target_schema AND table_name='recipe_ingredients' AND column_name='quantity' AND data_type='numeric' AND numeric_precision=24 AND numeric_scale=12) THEN
            EXECUTE format('ALTER TABLE %s ALTER COLUMN quantity TYPE numeric(24,12) USING quantity::text::numeric', line_table);
        END IF;
        IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema=target_schema AND table_name='recipe_ingredients' AND column_name='unit') THEN
            EXECUTE format('ALTER TABLE %s ADD COLUMN unit varchar(30)', line_table);
            -- Copy once. Subsequent starts must preserve recipe-specific units.
            EXECUTE format('UPDATE %s line SET unit=ingredient.unit FROM %s ingredient WHERE line.ingredient_id=ingredient.id', line_table, ingredient_table);
        END IF;
    END IF;
END
$$@@
