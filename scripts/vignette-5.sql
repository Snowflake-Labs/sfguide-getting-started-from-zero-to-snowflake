/***************************************************************************************************       
Asset:        Zero to Snowflake - Apps & Collaboration
Version:      v1     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

Apps & Collaboration
1. Acquiring weather data from Snowflake Marketplace
2. Integrating Account Data with Weather Source Data 
3. Explore Safegraph POI data
4. Introduction to Streamlit in Snowflake

****************************************************************************************************/

-- First, set the session query tag
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "apps_and_collaboration"}}';

-- Now, set the Worksheet context
USE DATABASE tb_101;
USE ROLE accountadmin;
USE WAREHOUSE tb_de_wh;

/*  1. Acquiring weather data from Snowflake Marketplace
    ***********************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/data-sharing-intro
    ***********************************************************
    One of our Junior Analysts, Ben, wants to gain better insight into how the weather impacts our US food truck sales. 
    To do this, he'll use the Snowflake Marketplace to add weather data to our account and query it against our own TastyBytes 
    data to uncover some brand new insights.
    
    The Snowflake Marketplace provides a centralized hub where we can discover and access a wide variety of third-party data, 
    applications, and AI products. This secure data sharing empowers us to access live, ready-to-query data without duplication. 
    
    Steps to acquire Weather Source data:
    1. Ensure you are using accountadmin from the account level (check the bottom left corner).
    2. Navigate to the 'Data Products' page from the Navigation Menu. You can open this page in a new browser tab if preferred.
    3. In the search bar, enter: 'Weather Source frostbyte'.
    4. Select the 'Weather Source LLC: frostbyte' listing and click 'Get'.
    5. Click 'Options' to expand the options section.
    6. Change Database name to:'ZTS_WEATHERSOURCE'.
    7. Grant access to 'PUBLIC'.
    8. Press 'Done'.
    
    This process allows us to access Weather Source data almost instantly. By eliminating the need for traditional data 
    duplication and pipelines, our analysts can move directly from a business question to actionable analysis. 
    
    With the weather data now in our account, our TastyBytes analysts can immediately begin joining it with our existing location data. 
*/

-- Switch to the analyst role
USE ROLE tb_analyst;

/*  2. Integrating Account Data with Weather Source Data

    Before we start harmonizing our raw location data with data from the Weather Source share, we can query the data share
    directly to get a better sense of the data we're working with. We'll start by getting a list of all of the distinct cities available 
    in the weather data along with some weather metrics for that specific city.
*/
SELECT 
    DISTINCT city_name,
    AVG(max_wind_speed_100m_mph) AS avg_wind_speed_mph,
    AVG(avg_temperature_air_2m_f) AS avg_temp_f,
    AVG(tot_precipitation_in) AS avg_precipitation_in,
    MAX(tot_snowfall_in) AS max_snowfall_in
FROM zts_weathersource.onpoint_id.history_day
WHERE country = 'US'
GROUP BY city_name;

-- Now, let's create a view that joins our raw country data with the historical daily weather data from our Weather Source data share. 
CREATE OR REPLACE VIEW harmonized.daily_weather_v
COMMENT = 'Weather Source Daily History filtered to Tasty Bytes supported Cities'
    AS
SELECT
    hd.*,
    TO_VARCHAR(hd.date_valid_std, 'YYYY-MM') AS yyyy_mm,
    pc.city_name AS city,
    c.country AS country_desc
FROM zts_weathersource.onpoint_id.history_day hd
JOIN zts_weathersource.onpoint_id.postal_codes pc
    ON pc.postal_code = hd.postal_code
    AND pc.country = hd.country
JOIN raw_pos.country c
    ON c.iso_country = hd.country
    AND c.city = hd.city_name;

/*
    Using our Daily Weather History View, Ben wants to find the average daily weather temperature for
    Hamburg in February 2022 and visualize it as a Line Chart.

    In the Results pane, click 'Chart' to visualize your results graphically. In the chart view, on the left
    hand section where it says 'Chart Type' configure these settings:
    
        Chart Type: Line chart | X-Axis: DATE_VALID_STD | Y-Axis: AVERAGE_TEMP_F
*/
SELECT
    dw.country_desc,
    dw.city_name,
    dw.date_valid_std,
    AVG(dw.avg_temperature_air_2m_f) AS average_temp_f
FROM harmonized.daily_weather_v dw
WHERE dw.country_desc = 'Germany'
    AND dw.city_name = 'Hamburg'
    AND YEAR(date_valid_std) = 2022
    AND MONTH(date_valid_std) = 2 -- February
GROUP BY dw.country_desc, dw.city_name, dw.date_valid_std
ORDER BY dw.date_valid_std DESC;

/*
    The daily weather view is working great! Let's take it one step further and combine our 
    orders view with our daily weather view with a daily sales by weather view. By doing this, we can 
    discover trends and relationships between our sales and weather conditions. 
*/
CREATE OR REPLACE VIEW analytics.daily_sales_by_weather_v
COMMENT = 'Daily Weather Metrics and Orders Data'
AS
WITH daily_orders_aggregated AS (
    SELECT
        DATE(o.order_ts) AS order_date,
        o.primary_city,
        o.country,
        o.menu_item_name,
        SUM(o.price) AS total_sales
    FROM
        harmonized.orders_v o
    GROUP BY ALL
)
SELECT
    dw.date_valid_std AS date,
    dw.city_name,
    dw.country_desc,
    ZEROIFNULL(doa.total_sales) AS daily_sales,
    doa.menu_item_name,
    ROUND(dw.avg_temperature_air_2m_f, 2) AS avg_temp_fahrenheit,
    ROUND(dw.tot_precipitation_in, 2) AS avg_precipitation_inches,
    ROUND(dw.tot_snowdepth_in, 2) AS avg_snowdepth_inches,
    dw.max_wind_speed_100m_mph AS max_wind_speed_mph
FROM
    harmonized.daily_weather_v dw
LEFT JOIN
    daily_orders_aggregated doa
    ON dw.date_valid_std = doa.order_date
    AND dw.city_name = doa.primary_city
    AND dw.country_desc = doa.country
ORDER BY 
    date ASC;

/*
    Ben can now use the daily sales by weather view to uncover how weather impacts sales, a previously unexplored relationship
    and can now begin to answer questions like: How does significant precipitation impact our sales figures in the Seattle market?

    Chart Type: Bar chart | X-Axis: MENU_ITEM_NAME | Y-Axis: DAILY_SALES
*/
SELECT * EXCLUDE (city_name, country_desc, avg_snowdepth_inches, max_wind_speed_mph)
FROM analytics.daily_sales_by_weather_v
WHERE 
    country_desc = 'United States'
    AND city_name = 'Seattle'
    AND avg_precipitation_inches >= 1.0
ORDER BY date ASC;

/*  3. Explore Safegraph POI data

    Ben wants more insight to the weather conditions at our food truck locations. Luckily Safegraph provides free Point-of-Interest 
    data on the Snowflake Marketplace.
    
    To use this data listing, we'll follow a similar procedure that we did earlier for the weather data:
        1. Ensure you are using accountadmin from the account level (check the bottom left corner).
        2. Navigate to the 'Data Products' page from the Navigation Menu. You can open this page in a new browser tab if preferred.
        3. In the search bar, enter: 'safegraph frostbyte'
        4. Select the 'Safegraph: frostbyte' listing and click 'Get'
        5. Click 'Options' to expand the options section.
        6. Database name: 'ZTS_SAFEGRAPH'
        7. Grant access to 'PUBLIC'.
        8. Press 'Done'.
    
    By joining Safegraph's POI data with a weather dataset like Frostbyte's and our own internal `orders_v` table, we can identify 
    hi-risk locations and quantify the financial impact from external factors.  
*/
CREATE OR REPLACE VIEW harmonized.tastybytes_poi_v
AS 
SELECT 
    l.location_id,
    sg.postal_code,
    sg.country,
    sg.city,
    sg.iso_country_code,
    sg.location_name,
    sg.top_category,
    sg.category_tags,
    sg.includes_parking_lot,
    sg.open_hours
FROM raw_pos.location l
JOIN zts_safegraph.public.frostbyte_tb_safegraph_s sg 
    ON l.location_id = sg.location_id
    AND l.iso_country_code = sg.iso_country_code;

-- Now let's query our point of interest data against our weather data to find our top 3 windiest locations on average in the US in 2022.
SELECT TOP 3
    p.location_id,
    p.city,
    p.postal_code,
    AVG(hd.max_wind_speed_100m_mph) AS average_wind_speed
FROM harmonized.tastybytes_poi_v AS p
JOIN
    zts_weathersource.onpoint_id.history_day AS hd
    ON p.postal_code = hd.postal_code
WHERE
    p.country = 'United States'
    AND YEAR(hd.date_valid_std) = 2022
GROUP BY p.location_id, p.city, p.postal_code
ORDER BY average_wind_speed DESC;

/*
    We want to use the location_ids from the last query to directly compare sales performance under different weather conditions.
    Using a Common Table Expression (CTE) we can use the query above as a subquery to find the top 3 locations with the highest 
    average wind speed and then analyze the sales data for those specific locations. Common Table Expressions help split up complex
    queries into different, smaller queries for improved readability and performance.
    
    We will split sales data for each truck brand into two buckets: 'calm' days, where the day's maximum wind speed was 20 mph or 
    less, and 'windy' days, where it exceeded 20 mph.

    The business impact of this is to identify a brand's weather resilience. By seeing these sales figures side-by-side,
    we can instantly spot which brands are 'weather-proof' and which see sales drop significantly in high winds.
    This allows for better informed operational decisions like running 'Windy Day' promotions for vulnerable brands,
    adjusting inventory, or informing future truck deployment strategy to better match a brand's menu to a
    location's typical weather.    
*/
WITH TopWindiestLocations AS (
    SELECT TOP 3
        p.location_id
    FROM harmonized.tastybytes_poi_v AS p
    JOIN
        zts_weathersource.onpoint_id.history_day AS hd
        ON p.postal_code = hd.postal_code
    WHERE
        p.country = 'United States'
        AND YEAR(hd.date_valid_std) = 2022
    GROUP BY p.location_id, p.city, p.postal_code
    ORDER BY AVG(hd.max_wind_speed_100m_mph) DESC
)
SELECT
    o.truck_brand_name,
    ROUND(
        AVG(CASE WHEN hd.max_wind_speed_100m_mph <= 20 THEN o.order_total END),
    2) AS avg_sales_calm_days,
    ZEROIFNULL(ROUND(
        AVG(CASE WHEN hd.max_wind_speed_100m_mph > 20 THEN o.order_total END),
    2)) AS avg_sales_windy_days
FROM analytics.orders_v AS o
JOIN
    zts_weathersource.onpoint_id.history_day AS hd
    ON o.primary_city = hd.city_name
    AND DATE(o.order_ts) = hd.date_valid_std
WHERE o.location_id IN (SELECT location_id FROM TopWindiestLocations)
GROUP BY o.truck_brand_name
ORDER BY o.truck_brand_name;

/*----------------------------------------------------------------------------------
 Reset Script
----------------------------------------------------------------------------------*/
USE ROLE accountadmin;

-- Drop views
DROP VIEW IF EXISTS harmonized.daily_weather_v;
DROP VIEW IF EXISTS analytics.daily_sales_by_weather_v;
DROP VIEW IF EXISTS harmonized.tastybytes_poi_v;

-- Unset Query Tag
ALTER SESSION UNSET query_tag;
-- Suspend the warehouse
ALTER WAREHOUSE tb_de_wh SUSPEND;