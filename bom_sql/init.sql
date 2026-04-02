-- 1. Создаем основную таблицу с правильными типами
DROP TABLE IF EXISTS bom_raw;
CREATE TABLE bom_raw (
    year                                INTEGER,
    month                               INTEGER,
    produced_material                   TEXT,
    produced_material_production_type   TEXT,
    produced_material_release_type      TEXT,
    produced_material_quantity          NUMERIC,
    component_material                  TEXT,
    component_material_production_type  TEXT,
    component_material_release_type     TEXT,
    component_material_quantity         NUMERIC,
    plant_id                            TEXT
);

-- 2. Создаем ВРЕМЕННУЮ таблицу, где всё — TEXT
CREATE TEMP TABLE bom_stage (
    year TEXT, month TEXT, 
    prod_mat TEXT, prod_type TEXT, prod_rel TEXT, prod_qty TEXT, 
    comp_mat TEXT, comp_type TEXT, comp_rel TEXT, comp_qty TEXT, 
    plant TEXT
);

-- 3. Загружаем CSV во временную таблицу (здесь ошибки не будет)
COPY bom_stage FROM '/tmp/task_2_data_ex.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');

-- 4. Переносим данные в основную таблицу, очищая числа от запятых
INSERT INTO bom_raw
SELECT 
    year::INTEGER,
    month::INTEGER,
    prod_mat,
    prod_type,
    prod_rel,
    REPLACE(prod_qty, ',', '')::NUMERIC, -- Удаляем запятую и конвертируем
    comp_mat,
    comp_type,
    comp_rel,
    REPLACE(comp_qty, ',', '')::NUMERIC, -- Удаляем запятую и конвертируем
    plant
FROM bom_stage;

-- 5. Удаляем временную таблицу
DROP TABLE bom_stage;

-- Сообщение в лог о завершении
DO $$ BEGIN RAISE NOTICE 'Импорт завершен успешно!'; END $$;