COPY (
    WITH RECURSIVE
        -- 1. Агрегация данных (схлопываем месяцы)
        BOM_AGGREGATED AS (
            SELECT
                PLANT_ID,
                YEAR,
                PRODUCED_MATERIAL,
                PRODUCED_MATERIAL_RELEASE_TYPE,
                PRODUCED_MATERIAL_PRODUCTION_TYPE,
                SUM(PRODUCED_MATERIAL_QUANTITY) AS PRODUCED_QTY,
                COMPONENT_MATERIAL,
                COMPONENT_MATERIAL_RELEASE_TYPE,
                COMPONENT_MATERIAL_PRODUCTION_TYPE,
                SUM(COMPONENT_MATERIAL_QUANTITY) AS COMPONENT_QTY
            FROM
                BOM_RAW
            GROUP BY
                PLANT_ID,
                YEAR,
                PRODUCED_MATERIAL,
                PRODUCED_MATERIAL_RELEASE_TYPE,
                PRODUCED_MATERIAL_PRODUCTION_TYPE,
                COMPONENT_MATERIAL,
                COMPONENT_MATERIAL_RELEASE_TYPE,
                COMPONENT_MATERIAL_PRODUCTION_TYPE
        ),
        -- 2. Рекурсивное построение дерева
        BOM_EXPLOSION AS (
            -- ЯКОРЬ: Формируем ПЕРВЫЙ УРОВЕНЬ связи (FIN -> COMPONENT)
            SELECT
                T1.PLANT_ID,
                T1.YEAR,
                T1.PRODUCED_MATERIAL AS FIN_ID,
                T1.PRODUCED_QTY AS FIN_QTY,
                T1.COMPONENT_MATERIAL AS PROD_ID,
                T2.COMPONENT_MATERIAL AS COMP_ID,
                T2.COMPONENT_QTY,
                1 AS LEVEL,
                ARRAY[
                    T1.PRODUCED_MATERIAL::TEXT,
                    T1.COMPONENT_MATERIAL::TEXT,
                    T2.COMPONENT_MATERIAL::TEXT
                ] AS PATH_TRACK
            FROM
                BOM_AGGREGATED T1
                INNER JOIN BOM_AGGREGATED T2 ON T1.COMPONENT_MATERIAL = T2.PRODUCED_MATERIAL
                AND T1.PLANT_ID = T2.PLANT_ID
                AND T1.YEAR = T2.YEAR
            WHERE
                T1.PRODUCED_MATERIAL_RELEASE_TYPE = 'FIN'
            UNION ALL
            SELECT
                R.PLANT_ID,
                R.YEAR,
                TREE.FIN_ID,
                TREE.FIN_QTY,
                R.PRODUCED_MATERIAL AS PROD_ID,
                R.COMPONENT_MATERIAL AS COMP_ID,
                R.COMPONENT_QTY,
                TREE.LEVEL + 1,
                TREE.PATH_TRACK || R.COMPONENT_MATERIAL::TEXT
            FROM
                BOM_AGGREGATED R
                INNER JOIN BOM_EXPLOSION TREE ON R.PRODUCED_MATERIAL = TREE.COMP_ID
                AND R.PLANT_ID = TREE.PLANT_ID
                AND R.YEAR = TREE.YEAR
            WHERE
                NOT (
                    R.COMPONENT_MATERIAL::TEXT = ANY (TREE.PATH_TRACK)
                )
                AND TREE.LEVEL < 15
        )
        -- 3. Финальный SELECT
    SELECT
        TREE.PLANT_ID AS PLANT,
        TREE.FIN_ID AS FIN_MATERIAL_ID,
        F_INFO.PRODUCED_MATERIAL_RELEASE_TYPE AS FIN_MATERIAL_RELEASE_TYPE,
        F_INFO.PRODUCED_MATERIAL_PRODUCTION_TYPE AS FIN_MATERIAL_PRODUCTION_TYPE,
        TREE.FIN_QTY AS FIN_PRODUCTION_QUANTITY,
        TREE.PROD_ID AS PROD_MATERIAL_ID,
        P_INFO.PRODUCED_MATERIAL_RELEASE_TYPE AS PROD_MATERIAL_RELEASE_TYPE,
        P_INFO.PRODUCED_MATERIAL_PRODUCTION_TYPE AS PROD_MATERIAL_PRODUCTION_TYPE,
        P_INFO.PRODUCED_QTY AS PROD_MATERIAL_PRODUCTION_QUANTITY,
        TREE.COMP_ID AS COMPONENT_ID,
        C_INFO.COMPONENT_MATERIAL_RELEASE_TYPE AS COMPONENT_MATERIAL_RELEASE_TYPE,
        C_INFO.COMPONENT_MATERIAL_PRODUCTION_TYPE AS COMPONENT_MATERIAL_PRODUCTION_TYPE,
        TREE.COMPONENT_QTY AS COMPONENT_CONSUMPTION_QUANTITY,
        TREE.YEAR
    FROM
        BOM_EXPLOSION TREE
        LEFT JOIN (
            SELECT DISTINCT
                PLANT_ID,
                YEAR,
                PRODUCED_MATERIAL,
                PRODUCED_MATERIAL_RELEASE_TYPE,
                PRODUCED_MATERIAL_PRODUCTION_TYPE
            FROM
                BOM_AGGREGATED
        ) F_INFO ON TREE.FIN_ID = F_INFO.PRODUCED_MATERIAL
        AND TREE.PLANT_ID = F_INFO.PLANT_ID
        AND TREE.YEAR = F_INFO.YEAR
        LEFT JOIN (
            SELECT DISTINCT
                PLANT_ID,
                YEAR,
                PRODUCED_MATERIAL,
                PRODUCED_MATERIAL_RELEASE_TYPE,
                PRODUCED_MATERIAL_PRODUCTION_TYPE,
                PRODUCED_QTY
            FROM
                BOM_AGGREGATED
        ) P_INFO ON TREE.PROD_ID = P_INFO.PRODUCED_MATERIAL
        AND TREE.PLANT_ID = P_INFO.PLANT_ID
        AND TREE.YEAR = P_INFO.YEAR
        LEFT JOIN (
            SELECT DISTINCT
                PLANT_ID,
                YEAR,
                COMPONENT_MATERIAL,
                COMPONENT_MATERIAL_RELEASE_TYPE,
                COMPONENT_MATERIAL_PRODUCTION_TYPE
            FROM
                BOM_AGGREGATED
        ) C_INFO ON TREE.COMP_ID = C_INFO.COMPONENT_MATERIAL
        AND TREE.PLANT_ID = C_INFO.PLANT_ID
        AND TREE.YEAR = C_INFO.YEAR
    ORDER BY
        PLANT,
        YEAR,
        FIN_MATERIAL_ID,
        PATH_TRACK
) TO '/tmp/reports/bom_exploded_result_sql.csv'
WITH
    (FORMAT CSV, HEADER TRUE, DELIMITER ',');
