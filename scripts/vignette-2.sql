/***************************************************************************************************       
Asset:        Zero to Snowflake - Simple Data Pipeline
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

Simple Data Pipeline
1. Ingestion from External stage
2. Semi-Structured Data and the VARIANT data type
3. Dynamic Tables
4. Simple Pipeline with Dynamic Tables
5. Pipeline Visualization with the Directed Acyclic Graph (DAG)

****************************************************************************************************/

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "data_pipeline"}}';

/*
    We will assume the role of a TastyBytes data engineer with the intention of creating a data pipeline with raw menu data,
    so let's set our context appropriately.
*/
USE DATABASE tb_101;
USE ROLE tb_data_engineer;
USE WAREHOUSE tb_de_wh;

/*  1. Ingestion from External stage
    ***************************************************************
    SQL Reference:
    https://docs.snowflake.com/en/sql-reference/sql/copy-into-table
    ***************************************************************

    Right now our data currently sits in an Amazon S3 bucket in CSV format. We need to load this raw CSV data 
    into a stage so that we can COPY it INTO a staging table for us to work with.
    
    In Snowflake, a stage is a named database object that specifies a location where data files are stored, allowing 
    you to load or unload data into and out of tables. 

    When we create a stage we specify:
                                - The S3 bucket to pull the data from
                                - The file format to parse the data with, CSV in this case
*/

-- Create the menu stage
CREATE OR REPLACE STAGE raw_pos.menu_stage
COMMENT = 'Stage for menu data'
URL = 's3://sfquickstarts/frostbyte_tastybytes/raw_pos/menu/'
FILE_FORMAT = public.csv_ff;

CREATE OR REPLACE TABLE raw_pos.menu_staging
(
    menu_id NUMBER(19,0),
    menu_type_id NUMBER(38,0),
    menu_type VARCHAR(16777216),
    truck_brand_name VARCHAR(16777216),
    menu_item_id NUMBER(38,0),
    menu_item_name VARCHAR(16777216),
    item_category VARCHAR(16777216),
    item_subcategory VARCHAR(16777216),
    cost_of_goods_usd NUMBER(38,4),
    sale_price_usd NUMBER(38,4),
    menu_item_health_metrics_obj VARIANT
);

-- With the stage and table in place, let's now load the data from the stage into the new menu_staging table.
COPY INTO raw_pos.menu_staging
FROM @raw_pos.menu_stage;

-- Optional: Verify successful load
SELECT * FROM raw_pos.menu_staging;

/*  2. Semi-Structured data in Snowflake
    *********************************************************************
    User-Guide:
    https://docs.snowflake.com/en/sql-reference/data-types-semistructured
    *********************************************************************
    
    Snowflake excels at handling semi-structured data like JSON using its VARIANT data type. It automatically parses, optimizes, 
    and indexes this data, enabling users to query it with standard SQL and specialized functions for easy extraction and analysis.
    Snowflake supports semi-structured data types such as JSON, Avro, ORC, Parquet or XML.
    
    The VARIANT object in the menu_item_health_metrics_obj column contains two main key-value pairs:
        - menu_item_id: A number representing the item's unique identifier.
        - menu_item_health_metrics: An array that holds objects detailing health information.
        
    Each object within the menu_item_health_metrics array has:
        - An ingredients array of strings.
        - Several dietary flags with string values of 'Y' and 'N'.
*/
SELECT menu_item_health_metrics_obj FROM raw_pos.menu_staging;

/*
    This query uses special syntax to navigate the data's internal, JSON-like structure. 
    The colon operator (:) accesses data by its key name and square brackets ([]) select an element from an array by its numerical position. 
    We can then chain these operators together to extract the ingredients list from the nested object.
    
    Elements retrieved from VARIANT objects remain VARIANT type. 
    Casting these elements to their known data types improves query performance and enhances data quality.
    There are two different ways to achieve casting:
        - the CAST function
        - using the shorthand syntax: <source_expr> :: <target_data_type>

    Below is a query that combines all of these topics to get the menu item name, the menu item ID,
    and the list of ingredients needed. 
*/
SELECT
    menu_item_name,
    CAST(menu_item_health_metrics_obj:menu_item_id AS INTEGER) AS menu_item_id, -- Casting using 'AS'
    menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY AS ingredients -- Casting using double colon (::) syntax
FROM raw_pos.menu_staging;

/*
    Another powerful function we can leverage when working with semi-structured data is FLATTEN.
    FLATTEN allows us to unwrap semi-structured data like JSON and Arrays and produce
    a row for every element within the specified object.

    We can use it to get a list of all ingredients from all of the menus used by our trucks.
*/
SELECT
    i.value::STRING AS ingredient_name,
    m.menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id
FROM
    raw_pos.menu_staging m,
    LATERAL FLATTEN(INPUT => m.menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) i;

/*  3. Dynamic Tables
    **************************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/dynamic-tables-about
    **************************************************************
    
    It would be nice to have all of the ingredients stored in a structured format to easily query, filter and
    analyze individually. However, our food truck franchises are constantly adding new and exciting menu items
    to their menu, many of which use unique ingredients not yet in our database. 
    
    For this, we can use Dynamic Tables, a powerful tool designed to simplify data transformation pipelines.
    Dynamic Tables are a perfect fit for our use case for several reasons:
        - They are created using a declarative syntax, where their data is defined by a specified query.
        - Automatic data refresh means data remains fresh without requiring manual updates or custom scheduling. 
        - Data freshness managed by Snowflake Dynamic Tables extends not only to the dynamic table 
          itself but also to any downstream data objects that depend on it.

    To see these functionalities in action, we'll create a simple Dynamic Table pipeline and then add a new 
    menu item to the staging table to demonstrate automatic refreshes.

    We will start by creating the Dynamic Table for Ingredients.
*/
CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient
    LAG = '1 minute'
    WAREHOUSE = 'TB_DE_WH'
AS
    SELECT
    ingredient_name,
    menu_ids
FROM (
    SELECT DISTINCT
        i.value::STRING AS ingredient_name, -- Distinct ingredient values 
        ARRAY_AGG(m.menu_item_id) AS menu_ids -- Array of menu IDs the ingredient is used for
    FROM
        raw_pos.menu_staging m,
        LATERAL FLATTEN(INPUT => menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients::ARRAY) i
    GROUP BY i.value::STRING
);

-- Let's verify that the ingredients Dynamic Table was successfully created
SELECT * FROM harmonized.ingredient;

/*
    One of our sandwich trucks Better Off Bread has introduced a new menu item, a Banh Mi sandwich.
    This menu item introduces a few ingredients: French Baguette, Mayonnaise, and Pickled Daikon. 
    
    Dynamic table's automatic refresh means that updating our menu_staging table with this new menu 
    item will automatically reflect in the ingredient table. 
*/
INSERT INTO raw_pos.menu_staging 
SELECT 
    10101,
    15, --truck id
    'Sandwiches',
    'Better Off Bread', -- truck brand name 
    157, --menu item id
    'Banh Mi', -- menu item name
    'Main',
    'Cold Option',
    9.0,
    12.0,
    PARSE_JSON('{
      "menu_item_health_metrics": [
        {
          "ingredients": [
            "French Baguette",
            "Mayonnaise",
            "Pickled Daikon",
            "Cucumber",
            "Pork Belly"
          ],
          "is_dairy_free_flag": "N",
          "is_gluten_free_flag": "N",
          "is_healthy_flag": "Y",
          "is_nut_free_flag": "Y"
        }
      ],
      "menu_item_id": 157
    }'
);

/*
    Verify French Baguette, Pickled Daikon are showing in the ingredients table.
    You may see 'Query produced no results". This means the dynamic table hasn't refreshed yet.
    Allow at most 1 minute for the Dynamic Table lag setting to catch up
*/

SELECT * FROM harmonized.ingredient 
WHERE ingredient_name IN ('French Baguette', 'Pickled Daikon');

/* 4. Simple Pipeline with Dynamic Tables

    Now let's create an ingredient to menu lookup dynamic table. This will let us see which menu items 
    use specific ingredients. Then we can determine which trucks need which ingredients and how many.
    Since this table is also a dynamic table, it will automatically refresh should any new ingredients be used 
    in any menu item that is added to the menu staging table.
*/
CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient_to_menu_lookup
    LAG = '1 minute'
    WAREHOUSE = 'TB_DE_WH'    
AS
SELECT
    i.ingredient_name,
    m.menu_item_health_metrics_obj:menu_item_id::INTEGER AS menu_item_id
FROM
    raw_pos.menu_staging m,
    LATERAL FLATTEN(INPUT => m.menu_item_health_metrics_obj:menu_item_health_metrics[0]:ingredients) f
JOIN harmonized.ingredient i ON f.value::STRING = i.ingredient_name;

-- Verify ingredient to menu lookup created successfully
SELECT * 
FROM harmonized.ingredient_to_menu_lookup
ORDER BY menu_item_id;

/*
    Run the next two insert queries to simulate an order of 2 Banh Mi sandwiches at truck #15 on
    January 27th 2022. After that we'll create another downstream dynamic table that shows us 
    ingredient usage by truck.
*/
INSERT INTO raw_pos.order_header
SELECT 
    459520441, -- order_id
    15, -- truck_id
    1030, -- location id
    101565,
    null,
    200322900,
    TO_TIMESTAMP_NTZ('08:00:00', 'hh:mi:ss'),
    TO_TIMESTAMP_NTZ('14:00:00', 'hh:mi:ss'),
    null,
    TO_TIMESTAMP_NTZ('2022-01-27 08:21:08.000'), -- order timestamp
    null,
    'USD',
    14.00,
    null,
    null,
    14.00;
    
INSERT INTO raw_pos.order_detail
SELECT
    904745311, -- order_detail_id
    459520441, -- order_id
    157, -- menu_item_id
    null,
    0,
    2, -- quantity ordered
    14.00,
    28.00,
    null;

/*
    Next, we'll create another dynamic table that summarizes the monthly usage of each ingredient by individual food trucks in the United States. 
    This allows our business to track ingredient consumption, which is crucial for optimizing inventory, controlling 
    costs, and making informed decisions about menu planning and supplier relationships.
    
    Note the two different methods used to extract parts of the date from our order timestamp:
      -> EXTRACT(<date part> FROM <datetime>) will isolate the specified date part from the given timestamp. There are several 
      date and time parts that can be used with EXTRACT function with the most common being YEAR, MONTH, DAY, HOUR, MINUTE, SECOND.
      -> MONTH(<datetime>) returns the month's index from 1-12. YEAR(<datetime>) and DAY(<datetime>) will do the same but for the year
      and day respectively.
*/

-- Next create the table
CREATE OR REPLACE DYNAMIC TABLE harmonized.ingredient_usage_by_truck 
    LAG = '2 minute'
    WAREHOUSE = 'TB_DE_WH'  
    AS 
    SELECT
        oh.truck_id,
        EXTRACT(YEAR FROM oh.order_ts) AS order_year,
        MONTH(oh.order_ts) AS order_month,
        i.ingredient_name,
        SUM(od.quantity) AS total_ingredients_used
    FROM
        raw_pos.order_detail od
        JOIN raw_pos.order_header oh ON od.order_id = oh.order_id
        JOIN harmonized.ingredient_to_menu_lookup iml ON od.menu_item_id = iml.menu_item_id
        JOIN harmonized.ingredient i ON iml.ingredient_name = i.ingredient_name
        JOIN raw_pos.location l ON l.location_id = oh.location_id
    WHERE l.country = 'United States'
    GROUP BY
        oh.truck_id,
        order_year,
        order_month,
        i.ingredient_name
    ORDER BY
        oh.truck_id,
        total_ingredients_used DESC;
/*
    Now, let's view the ingredient usage for truck #15 in January 2022 using our newly created
    ingredient_usage_by_truck view. 
*/
SELECT
    truck_id,
    ingredient_name,
    SUM(total_ingredients_used) AS total_ingredients_used,
FROM
    harmonized.ingredient_usage_by_truck
WHERE
    order_month = 1 -- Months are represented numerically 1-12
    AND truck_id = 15
GROUP BY truck_id, ingredient_name
ORDER BY total_ingredients_used DESC;

/*  5. Pipeline Visualization with the Directed Acyclic Graph (DAG)

    Finally, let's understand our pipeline's Directed Acyclic Graph, or DAG. 
    The DAG serves as a visualization of our data pipeline. You can use it to visually orchestrate complex data workflows, ensuring 
    tasks run in the correct order. You can use it to view lag metrics and configuration for each dynamic table in the pipeline and 
    also manually refresh tables if needed.

    To access the DAG:
    - Click the 'Data' button in the Navigation Menu to open the database screen
    - Click the arrow '>' next to 'TB_101' to expand the database 
    - Expand 'HARMONIZED' then expand 'Dynamic Tables'
    - Click the 'INGREDIENT' table
*/

-------------------------------------------------------------------------
--RESET--
-------------------------------------------------------------------------
USE ROLE accountadmin;
--Drop Dynamic Tables
DROP TABLE IF EXISTS raw_pos.menu_staging;
DROP TABLE IF EXISTS harmonized.ingredient;
DROP TABLE IF EXISTS harmonized.ingredient_to_menu_lookup;
DROP TABLE IF EXISTS harmonized.ingredient_usage_by_truck;

--Delete inserts
DELETE FROM raw_pos.order_detail
WHERE order_detail_id = 904745311;
DELETE FROM raw_pos.order_header
WHERE order_id = 459520441;

-- Unset Query Tag
ALTER SESSION UNSET query_tag;
-- Suspend warehouse
ALTER WAREHOUSE tb_de_wh SUSPEND;