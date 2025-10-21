/***************************************************************************************************       
Asset:        Zero to Snowflake - Getting Started with Snowflake
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

Getting Started with Snowflake
1. Virtual Warehouses & Settings
2. Using Persisted Query Results
3. Basic Data Transformation Techniques
4. Data Recovery with UNDROP
5. Resource Monitors
6. Budgets
7. Universal Search

****************************************************************************************************/

-- Before we start, run this query to set the session query tag.
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "getting_started_with_snowflake"}}';

-- We'll begin by setting our Worksheet context. We will set our database, schema and role.

USE DATABASE tb_101;
USE ROLE accountadmin;

/*   1. Virtual Warehouses & Settings 
    **************************************************************
     User-Guide:
     https://docs.snowflake.com/en/user-guide/warehouses-overview
    **************************************************************
    
    Virtual Warehouses are the dynamic, scalable, and cost-effective computing power that lets you 
    perform analysis on your Snowflake data. Their purpose is to handle all your data processing needs 
    without you having to worry about the underlying technical details.

    Warehouse parameters:
      > WAREHOUSE_SIZE: 
            Size specifies the amount of compute resources available per cluster 
            in a warehouse. The available sizes range from X-Small to 6X-Large.
            Default: 'XSmall'
      > WAREHOUSE_TYPE:
            Defines the type of virtual warehouse, which dictates its architecture and behavior
            Types:
                'STANDARD' for general purpose workloads
                'SNOWPARK_OPTIMIZED' for memory-intensive workloads
            Default: 'STANDARD'
      > AUTO_SUSPEND:
            Specifies the period of inactivity after which the warehouse will automatically suspend itself.
            Default: 600s
      > INITIALLY_SUSPENDED:
            Determines whether the warehouse starts in a suspended state immediately after it is created.
            Default: TRUE
      > AUTO_RESUME:
            Determines whether the warehouse automatically resumes from a suspended state when a query is directed to it.
            Default: TRUE

        With that, let's create our first warehouse!
*/

-- Let's first look at the warehouses that already exist on our account that you have access privileges for
SHOW WAREHOUSES;

/*
    This returns the list of warehouses and their attributes: name, state (running or suspended), type, and size 
    among many others. 
    
    We can also view and manage all warehouses in Snowsight. To access the warehouse page, click the Admin button
    on the Navigation Menu, then click the 'Warehouses' link in the now expanded Admin category.
    
    Back on the warehouse page, we see a list of the warehouses on this account and their attributes.
*/

-- You can easily create a warehouse with a simple SQL command
CREATE OR REPLACE WAREHOUSE my_wh
    COMMENT = 'My TastyBytes warehouse'
    WAREHOUSE_TYPE = 'standard'
    WAREHOUSE_SIZE = 'xsmall'
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'standard'
    AUTO_SUSPEND = 60
    INITIALLY_SUSPENDED = true
    AUTO_RESUME = false;

/*
    Now that we have a warehouse, we should specify that this Worksheet uses this warehouse. We can
    do this either with a SQL command, or in the UI.
*/

-- Use the warehouse
USE WAREHOUSE my_wh;

/*
    We can try running a simple query, however, you will see an error message in the results pane, informing
    us that our warehouse MY_WH is suspended. Try it now.
*/
SELECT * FROM raw_pos.truck_details;

/*    
    An active warehouse is required for running queries, as well as all DML operations, so we'll 
    need to resume our warehouse if we want to get insights from our data.
    
    The error message also came with a suggestion to run the SQL command:
    'ALTER warehouse MY_WH resume'. Let's do just that!
*/
ALTER WAREHOUSE my_wh RESUME;

/* 
    We'll also set AUTO_RESUME to TRUE so we can avoid having to manually 
    resume the warehouse should it suspend again.
 */
ALTER WAREHOUSE my_wh SET AUTO_RESUME = TRUE;

--The warehouse is now running, so lets try to run the query from before 
SELECT * FROM raw_pos.truck_details;

-- Now we are able to start running queries on our data

/* 
    Next, let's take a look at the power of warehouse scalability in Snowflake.
    
    Warehouses in Snowflake are designed for scalability and elasticity, giving you the power
    to adjust compute resources up or down based on workload needs.
    
    We can easily scale up our warehouses on the fly with a simple ALTER WAREHOUSE statement.
*/
ALTER WAREHOUSE my_wh SET warehouse_size = 'XLarge';

--Let's now take a look at the sales per truck.
SELECT
    o.truck_brand_name,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM(o.price) AS total_sales
FROM analytics.orders_v o
GROUP BY o.truck_brand_name
ORDER BY total_sales DESC;

/*
    With the Results panel open, take a quick look at the toolbar in the top right. Here we see options to search, 
    select columns, view query details and duration stats, view column stats, and download results. 
    
    Search - Use search terms to filter the results
    Column selection - Enable/disable columns to display in the results
      Query details - Contains information related to the query like the SQL text, rows returned, query ID, the 
      role and warehouse it was executed with.
    Query duration - Breaks down how long it took for the query to run by compilation, provisioning and execution times.
    Column stats - Displays data relating to the distributions of the columns on the results panel.
    Download results - Export and download the results as csv.
*/

/*  2. Using Persisted Query Results
    *******************************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/querying-persisted-results
    *******************************************************************
    
    Before we proceed, this is a great place to demonstrate another powerful feature in Snowflake: 
    the Query Result Cache.
    
    When we first ran the above query it took several seconds to complete, even with an XL warehouse.

    Run the same 'sales per truck' query above and note the total run time in the Query Duration pane.
    You'll notice that it took several seconds the first time you ran it to only a few hundred milliseconds 
    the next time. This is the query result cache in action.

    Open the Query History panel and compare the run times between the first time the query was run for the second time.
    
    Query Result Cache overview:
    - Results are retained for any query for 24 hours, however the timer is reset any time the query is executed.
    - Hitting the result cache requires almost no compute resources, ideal for frequently run reports or dashboards
      and managing credit consumption.
    - The cache resides in the Cloud Services Layer, meaning it is logically separated from individual warehouses. 
      This makes it globally accessible to all virtual warehouses & users within the same account.
*/

-- We'll now start working with a smaller dataset, so we can scale the warehouse back down
ALTER WAREHOUSE my_wh SET warehouse_size = 'XSmall';

/*  3. Basic Transformation Techniques

    Now that our warehouse is configured and running, the plan is to get an understanding of the distribution 
    of our trucks' manufacturers, however, this information is embedded in another column 'truck_build' that stores
    information about the year, make and model in a VARIANT data type. 

    VARIANT data types are examples of semi-structured data. They can store any type of data including OBJECT, 
    ARRAY and other VARIANT values. In our case, the truck_build stores a single OBJECT which contains three distinct 
    VARCHAR values for year, make and model.
    
    We'll now isolate all three properties into their own respective columns to allow for simpler and easier analytics. 
*/
SELECT truck_build FROM raw_pos.truck_details;

/*  Zero Copy Cloning

    The truck_build column data consistently follows the same format. We'll need a separate column for 'make'
    to more easily perform quality analysis on it. The plan is to create a development copy of the truck table, add new columns 
    for year, make, and model, then extract and store each property from the truck build VARIANT object into these new columns.
 
    Snowflake's powerful Zero Copy Cloning lets us create identical, fully functional and separate copies of database 
    objects instantly, without using any additional storage space. 

    Zero Copy Cloning leverages Snowflake's unique micropartition architecture to share data between the cloned object and original copy.
    Any changes to either table will result in new micropartitions created for only the modified data. These new micro-partitions are
    now owned exclusively by the owner, whether its the clone or original cloned object. Basically, any changes made to one table,
    will not be to either the original or cloned copy.
*/

-- Create the truck_dev table as a Zero Copy clone of the truck table
CREATE OR REPLACE TABLE raw_pos.truck_dev CLONE raw_pos.truck_details;

-- Verify successful truck table clone into truck_dev 
SELECT TOP 15 * 
FROM raw_pos.truck_dev
ORDER BY truck_id;

/*
    Now that we have a development copy of the truck table, we can start by adding the new columns.
    Note: To run all three statements at once, select them and click the blue 'Run' button at the top right of the screen, or use your keyboard.
    
        Mac: command + return
        Windows: Ctrl + Enter
*/

ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS year NUMBER;
ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS make VARCHAR(255);
ALTER TABLE raw_pos.truck_dev ADD COLUMN IF NOT EXISTS model VARCHAR(255);

/*
    Now let's update the new columns with the data extracted from the truck_build column.
    We will use the colon (:) operator to access the value of each key in the truck_build 
    column, then set that value to its respective column.
*/
UPDATE raw_pos.truck_dev
SET 
    year = truck_build:year::NUMBER,
    make = truck_build:make::VARCHAR,
    model = truck_build:model::VARCHAR;

-- Verify the 3 columns were successfully added to the table and populated with the extracted data from truck_build
SELECT year, make, model FROM raw_pos.truck_dev;

-- Now we can count the different makes and get a sense of the distribution in our TastyBytes food truck fleet.
SELECT 
    make,
    COUNT(*) AS count
FROM raw_pos.truck_dev
GROUP BY make
ORDER BY make ASC;

/*
    After running the query above, we notice a problem in our dataset. Some trucks' makes are 'Ford' and some are 'Ford_',
    giving us two different counts for the same truck manufacturer.
*/

-- First we'll use UPDATE to change any occurrence of 'Ford_' to 'Ford'
UPDATE raw_pos.truck_dev
    SET make = 'Ford'
    WHERE make = 'Ford_';

-- Verify the make column has been successfully updated 
SELECT truck_id, make 
FROM raw_pos.truck_dev
ORDER BY truck_id;

/*
    The make column looks good now so let's SWAP the truck table with the truck_dev table
    This command atomically swaps the metadata and data between two tables, instantly promoting the truck_dev table 
    to become the new production truck table.
*/
ALTER TABLE raw_pos.truck_details SWAP WITH raw_pos.truck_dev; 

-- Run the query from before to get an accurate make count
SELECT 
    make,
    COUNT(*) AS count
FROM raw_pos.truck_details
GROUP BY
    make
ORDER BY count DESC;
/*
    The changes look great. We'll perform some cleanup on our dataset by first dropping the truck_build 
    column from the production database now that we have split that data into three separate columns.
    Then we can drop the truck_dev table since we no longer need it.
*/

-- We can drop the old truck build column with a simple ALTER TABLE ... DROP COLUMN command
ALTER TABLE raw_pos.truck_details DROP COLUMN truck_build;

-- Now we can drop the truck_dev table
DROP TABLE raw_pos.truck_details;

/*  4. Data Recovery with UNDROP
	
    Oh no! We accidentally dropped the production truck table. 😱

    Luckily we can use the UNDROP command to restore the table back to its state before being dropped. 
    UNDROP is part of Snowflake's powerful Time Travel feature and allows for the restoration of dropped
    database objects within a configured data retention period (default 24 hours).

    Let's restore the production 'truck' table ASAP using UNDROP!
*/

-- Optional: run this query to verify the 'truck' table no longer exists
    -- Note: The error 'Table TRUCK does not exist or not authorized.' means the table was dropped.
DESCRIBE TABLE raw_pos.truck_details;

--Run UNDROP on the production 'truck' table to restore it to the exact state it was in before being dropped
UNDROP TABLE raw_pos.truck_details;

--Verify the table was successfully restored
SELECT * from raw_pos.truck_details;

-- Now drop the real truck_dev table
DROP TABLE raw_pos.truck_dev;

/*  5. Resource Monitors
    ***********************************************************
    User-Guide:                                   
    https://docs.snowflake.com/en/user-guide/resource-monitors
    ***********************************************************

    Monitoring compute usage and spend is critical to any cloud-based workflow. Snowflake provides a simple 
    and straightforward way to track warehouse credit usage with Resource Monitors.

    With Resource Monitors you define credit quotas and then trigger certain actions on 
    associated warehouses upon reaching defined usage thresholds.

    Actions the resource monitor can take:
    -NOTIFY: Sends an email notification to specified users or roles.
    -SUSPEND: Suspends the associated warehouses when a threshold is reached.
              NOTE: Running queries are allowed to complete. 
    -SUSPEND_IMMEDIATE: Suspends the associated warehouses when a threshold is reached and
                        cancels all running queries.

    Now, we'll create a Resource Monitor for our warehouse my_wh

    Let's quickly set our account level role in Snowsight to accountadmin;
    To do so:
    - Click the User Icon in the bottom left of the screen
    - Hover over 'Switch Role'
    - Select 'ACCOUNTADMIN' in the role list panel

   Next we will use the accountadmin role in our Worksheet
*/
USE ROLE accountadmin;

-- Run the query below to create the resource monitor via SQL
CREATE OR REPLACE RESOURCE MONITOR my_resource_monitor
    WITH CREDIT_QUOTA = 100
    FREQUENCY = MONTHLY -- Can also be DAILY, WEEKLY, YEARLY, or NEVER (for a one-time quota)
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS ON 75 PERCENT DO NOTIFY
             ON 90 PERCENT DO SUSPEND
             ON 100 PERCENT DO SUSPEND_IMMEDIATE;

-- With the Resource Monitor created, apply it to my_wh
ALTER WAREHOUSE my_wh 
    SET RESOURCE_MONITOR = my_resource_monitor;

/*  6. Budgets
    ****************************************************
      User-Guide:                                   
      https://docs.snowflake.com/en/user-guide/budgets 
    ****************************************************
      
    In the previous step we configured a Resource Monitor that allows for monitoring
    credit usage for Warehouses. In this step we will create a Budget for a more holistic 
    and flexible approach to managing costs in Snowflake. 
    
    While Resource Monitors are tied specifically to warehouse and compute usage, Budgets can be used 
    to track costs and impose spending limits on any Snowflake object or service and notify users 
    when the dollar amount reaches a specified threshold.
*/

-- Let's first create our budget
CREATE OR REPLACE SNOWFLAKE.CORE.BUDGET my_budget()
    COMMENT = 'My Tasty Bytes Budget';

/*
    Before we can configure our Budget we need to verify an email address on the account.

    To verify your email address:
    - Click the User Icon in the bottom left of the screen
    - Click Settings 
    - Enter your email address in the email field
    - Click 'Save'
    - Check your email and follow instructions to verify email
        NOTE: if you don't receive an email after a few minutes, click 'Resend Verification'
     
    With our new budget now in place, our email verified and our account-level role set to accountadmin, 
    lets head over to the Budgets page in Snowsight to add some resources to our Budget.

    To get to the Budgets page in Snowsight:
    - Click the Admin button on the Navigation Menu
    - Click the first item 'Cost Management'
    - Click the 'Budgets' tab
    
    If prompted to select a warehouse, select tb_dev_wh, otherwise, ensure your warehouse is set to 
    tb_dev_wh from the warehouse panel at the top right of the screen.
    
    On the budgets page we see metrics about our spend for the current period.
    In the middle of the screen shows a graph of the current spend with forecasted spend.
    At the bottom of the screen we see our 'MY_BUDGET' budget we created earlier. Click
    that to view the Budget page
    
    Clicking the '<- Budget Details' at the top right of the screen reveals the
    Budget Details panel. Here we can view information about our budget and all 
    of the resources attached to it. We see there are no resources monitored so let's add some now.
    Click the 'Edit' button to open the Edit Budget panel;
    
    - Keep budget name the same
    - Set the spending limit to 100
    - Enter the email you verified earlier
    - Click the '+ Tags & Resources' button to add a couple of resources
    - Expand Databases, then TB_101, then check the box next to the ANALYTICS schema
    - Scroll down to and expand 'Warehouses'
    - Check the box for 'TB_DE_WH'
    - Click 'Done'
    - Back in the Edit Budget menu, click 'Save Changes'
*/

/*  7. Universal Search
    **************************************************************************
      User-Guide                                                             
      https://docs.snowflake.com/en/user-guide/ui-snowsight-universal-search  
    **************************************************************************

    Universal Search allows you to easily find any object in your account, plus explore data products in the Marketplace, 
    relevant Snowflake Documentation, and Community Knowledge Base articles.

    Let's try it now.
    - To use Universal Search, begin by clicking 'Search' in the Navigation Menu
    - Here we see the Universal Search UI. Let's put in our first search term.
    - Enter 'truck' into the search bar and observe the results. The top sections are categories 
      of relevant objects on your account, like databases, tables, views, stages, etc. Below your
      database objects you can see sections for relevant marketplace listings and documentation.

    - You may also provide search terms in natural language to describe what you're looking for. If we wanted to
    know where to start looking to answer which truck franchise has the most return customers, we could search
    something like 'Which truck franchise has the most loyal customer base?' Clicking 'View all >' button next to 
    the 'Tables & Views' section will allow us to view all of the relevant tables and views relevant to our query.

    Universal Search returns several tables and views from different schemas. Note also how the relevant columns
    are listed for each object. These are all excellent starting points for data-driven answers about return customers.
*/

-------------------------------------------------------------------------
--RESET--
-------------------------------------------------------------------------
-- Drop created objects
DROP RESOURCE MONITOR IF EXISTS my_resource_monitor;
DROP TABLE IF EXISTS raw_pos.truck_dev;

-- Reset truck details
CREATE OR REPLACE TABLE raw_pos.truck_details
AS 
SELECT * EXCLUDE (year, make, model)
FROM raw_pos.truck;

DROP WAREHOUSE IF EXISTS my_wh;
-- Unset Query Tag
ALTER SESSION UNSET query_tag;