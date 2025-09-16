/***************************************************************************************************       
Asset:        Zero to Snowflake - Governance with Horizon
Version:      v1     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

Governance with Horizon
1. Introduction to Roles and Access Control
2. Tag-Based Classification with Auto Tagging
3. Column-level Security with Masking Policies
4. Row Level Security with Row Access Policies
5. Data Quality Monitoring with Data Metric Functions
6. Account Security Monitoring with the Trust Center

****************************************************************************************************/

-- Set the session query tag
ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "governance_with_horizon"}}';

-- First, let's set our Worksheet context
USE ROLE useradmin;
USE DATABASE tb_101;
USE WAREHOUSE tb_dev_wh;

/*  1. Introduction to Roles and Access Control    
    *************************************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/security-access-control-overview
    *************************************************************************
    
    Snowflake Access Control Framework is based on:
      - Role-based Access Control (RBAC): Access privileges are assigned to roles, which are in turn assigned to users.
      - Discretionary Access Control (DAC): Each object has an owner, who can in turn grant access to that object.
    
    The key concepts to understanding access control in Snowflake are:
      - Securable Object: A securable object is anything you can control who gets to use or see. If someone isn't 
        specifically given permission, they can't access it. These objects are managed by groups (Roles), not individual 
        people. Databases, tables, and functions for example are all securable objects.
      - Role: A role is like a set of permissions you can give out. You can give these roles to individual users, or even 
        to other roles, creating a chain of permissions.
      - Privilege: A privilege is a specific permission to do something with an object. You can combine many small privileges 
        to control exactly how much access someone has.
      - User: A user is simply an identity (like a username) that Snowflake recognizes. It can be a real person or a computer program.
    
      Snowflake System Defined Role Definitions:
       - ORGADMIN: Role that manages operations at the organization level.
       - ACCOUNTADMIN: This is the top-level role in the system and should be granted only to a limited/controlled number of users
          in your account.
       - SECURITYADMIN: Role that can manage any object grant globally, as well as create, monitor, and manage users and roles.
       - USERADMIN: Role that is dedicated to user and role management only.
       - SYSADMIN: Role that has privileges to create warehouses and databases in an account.
       - PUBLIC: PUBLIC is a pseudo-role automatically granted to all users and roles. It can own securable objects, 
           and anything it owns becomes available to every other user and role in the account.

                                +---------------+
                                | ACCOUNTADMIN  |
                                +---------------+
                                  ^    ^     ^
                                  |    |     |
                    +-------------+-+  |    ++-------------+
                    | SECURITYADMIN |  |    |   SYSADMIN   |<------------+
                    +---------------+  |    +--------------+             |
                            ^          |     ^        ^                  |
                            |          |     |        |                  |
                    +-------+-------+  |     |  +-----+-------+  +-------+-----+
                    |   USERADMIN   |  |     |  | CUSTOM ROLE |  | CUSTOM ROLE |
                    +---------------+  |     |  +-------------+  +-------------+
                            ^          |     |      ^              ^      ^
                            |          |     |      |              |      |
                            |          |     |      |              |    +-+-----------+
                            |          |     |      |              |    | CUSTOM ROLE |
                            |          |     |      |              |    +-------------+
                            |          |     |      |              |           ^
                            |          |     |      |              |           |
                            +----------+-----+---+--+--------------+-----------+
                                                 |
                                            +----+-----+
                                            |  PUBLIC  |
                                            +----------+

    In this section we'll look at how to create a custom data steward role and associate priveleges with it.                                 
*/
-- First, let's see which roles are already on our account.
SHOW ROLES;

-- Now we'll create our data steward role.
CREATE OR REPLACE ROLE tb_data_steward
    COMMENT = 'Custom Role';
-- With the role created we can switch to the SECURITYADMIN role and grant privileges to our new role.

/*
    With our new role created, we'll want to be able to use a warehouse to perform queries. Before moving
    on, let's get a better understanding of warehouse privileges.
     
    - MODIFY: Enables altering any properties of a warehouse, including changing its size.
    - MONITOR: Enables viewing current and past queries executed on a warehouse as well as usage
       statistics on that warehouse.
    - OPERATE: Enables changing the state of a warehouse (stop, start, suspend, resume). In addition,
       enables viewing current and past queries executed on a warehouse and aborting any executing queries.
    - USAGE: Enables using a virtual warehouse and, as a result, executing queries on the warehouse.
       If the warehouse is configured to auto-resume when a SQL statement is submitted to it, the warehouse
       resumes automatically and executes the statement.
    - ALL: Grants all privileges, except OWNERSHIP, on the warehouse.

      Now that we understand warehouse privileges, we can grant operate and usage privileges to our new role.
      First, switch to the SECURITYADMIN role.
*/
USE ROLE securityadmin;
-- First, we'll grant the role the ability to use warehouse tb_dev_wh
GRANT OPERATE, USAGE ON WAREHOUSE tb_dev_wh TO ROLE tb_data_steward;

/*
     Next, let's understand Snowflake Database and Schema Grants:
      - MODIFY: Enables altering any database settings.
      - MONITOR: Enables execution of the DESCRIBE command.
      - USAGE: Enables using a database, including returning the database details in the
         SHOW DATABASES command output. Additional privileges are required to view or take
         actions on objects in a database.
      - ALL: Grants all privileges, except OWNERSHIP, on a database.
*/

GRANT USAGE ON DATABASE tb_101 TO ROLE tb_data_steward;
GRANT USAGE ON ALL SCHEMAS IN DATABASE tb_101 TO ROLE tb_data_steward;

/*
    Access to data within Snowflake tables and views is managed through the following privileges:
        SELECT: Grants the ability to retrieve data.
        INSERT: Allows the addition of new rows.
        UPDATE: Allows the modification of existing rows.
        DELETE: Allows for the removal of rows.
        TRUNCATE: Allows for the deletion of all rows in a table.

      Next is to ensure we can run SELECT queries on the tables in the raw_customer schema.
*/

-- Grant SELECT privileges on all tables in the RAW_CUSTOMER schema
GRANT SELECT ON ALL TABLES IN SCHEMA raw_customer TO ROLE tb_data_steward;
-- Grant ALL privileges on the governance schema and all tables in the governance schema. 
GRANT ALL ON SCHEMA governance TO ROLE tb_data_steward;
GRANT ALL ON ALL TABLES IN SCHEMA governance TO ROLE tb_data_steward;

/*
    In order to use our new role, we also need to grant the role to the current user. Run the next two queries 
    to grant the current user the privilege to use the new data steward role.
*/
SET my_user = CURRENT_USER();
GRANT ROLE tb_data_steward TO USER IDENTIFIER($my_user);

/*
    Finally, run the query below use our newly created role!
    --> Alternatively, you can also use the role by clicking the 'Select role and warehouse' button in the 
        Worksheet UI, then selecting 'tb_data_steward'.
*/
USE ROLE tb_data_steward;

-- To celebrate let's get an idea of the type of data we're going to be working with.
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

/*
    We're seeing the customer loyalty data, which is great! However, upon closer inspection its 
    quite clear this table is full of sensitive, Personally Identifiable Information or, PII. 
    In the next sections we'll look further into how we can mitigate this.
*/

/*  2. Tag-Based Classification with Auto Tagging
    ******************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/classify-auto
    ******************************************************

    In the last query we noticed quite a bit of personally identifiable information (PII) stored in
    the Customer Loyalty table. We can use Snowflake's auto tagging capabilities in conjunction with 
    tag-based masking to obfuscate sensitive data in query results.

    Snowflake can automatically discover and tag sensitive information by continuously monitoring the 
    columns in your database schemas. After a data engineer assigns a classification profile to a schema, 
    all sensitive data within that schema's tables is automatically classified based on the schedule 
    in the profile.
    
    We'll now create a classification profile and designate a tag to be automatically assigned to columns 
    based on the column's semantic category. Let's start by switching to the accountadmin role. 
*/
USE ROLE accountadmin;

/*
    We'll create a governance schema, then a tag for PII within it, then give our new role permissions to 
    apply the tag on database objects.
*/
CREATE OR REPLACE TAG governance.pii;
GRANT APPLY TAG ON ACCOUNT TO ROLE tb_data_steward;

/*
    First we need to grant our role tb_data_steward the appropriate privileges to execute data classifications and 
    create classification profiles on our raw_customer schema.
*/
GRANT EXECUTE AUTO CLASSIFICATION ON SCHEMA raw_customer TO ROLE tb_data_steward;
GRANT DATABASE ROLE SNOWFLAKE.CLASSIFICATION_ADMIN TO ROLE tb_data_steward;
GRANT CREATE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE ON SCHEMA governance TO ROLE tb_data_steward;

-- Switch back to the data steward role.
USE ROLE tb_data_steward;

/*
    Create the classification profile. Objects added to the schema are classified immediately, valid for 30 days
    and are tagged automatically.
*/
CREATE OR REPLACE SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE
  governance.tb_classification_profile(
    {
      'minimum_object_age_for_classification_days': 0,
      'maximum_classification_validity_days': 30,
      'auto_tag': true
    });

/*
    Create a tag map to automatically tag columns given the specified semantic categories. This means any column 
    classified with any of the values in the semantic_categories array will be automatically tagged with the PII tag.
*/
CALL governance.tb_classification_profile!SET_TAG_MAP(
  {'column_tag_map':[
    {
      'tag_name':'tb_101.governance.pii',
      'tag_value':'pii',
      'semantic_categories':['NAME', 'PHONE_NUMBER', 'POSTAL_CODE', 'DATE_OF_BIRTH', 'CITY', 'EMAIL']
    }]});

-- Now call SYSTEM$CLASSIFY to automatically classify the customer_loyalty table with our classification profile.
CALL SYSTEM$CLASSIFY('tb_101.raw_customer.customer_loyalty', 'tb_101.governance.tb_classification_profile');

/*
    Run the next query to see the results of the auto classification and tagging. We'll pull metadata from the 
    automatically generated INFORMATION_SCHEMA, available on every Snowflake account. Take a minute to look
    through how each column was tagged and how it relates to the classification profile we created in earlier 
    steps. 
    
    You'll see all columns are tagged with PRIVACY_CATEGORY and SEMANTIC_CATEGORY tags each with its own purpose. 
    PRIVACY_CATEGORY denotes the level of sensitivity of the personal data in the column, while 
    SEMANTIC_CATEGORY describes the real-world concept the data represents. 
    
    Finally, note that columns tagged with the semantic category we specified in the classification tag map 
    array are tagged with our custom 'PII' tag.
*/
SELECT 
    column_name,
    tag_database,
    tag_schema,
    tag_name,
    tag_value,
    apply_method
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS('raw_customer.customer_loyalty', 'table'));

/*  3. Column-level Security with Masking Policies
    **************************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/security-column-intro
    **************************************************************

    Snowflake's Column-level Security lets us protect data in columns using masking policies. It offers 
    two main features: Dynamic Data Masking, which can hide or transforms sensitive data at query time, and 
    External Tokenization, which allows you to tokenize data before it enters Snowflake and then detokenize 
    it when queried.

    Now that our sensitive columns are tagged as PII, we'll create a couple of masking policies to associate
    with that tag. The first will be for sensitive string data like first and last names, emails and phone numbers. The
    second will be for sensitive DATE values like birthday. 

    The masking logic is similar for both: If the current role queries a PII-tagged column and isn't the account admin or a
    TastyBytes admin, string values will show 'MASKED'. Date values will display only the original year, with month and day as 01-01.
*/

-- Create the masking policy for sensitive string data
CREATE OR REPLACE MASKING POLICY governance.mask_string_pii AS (original_value STRING)
RETURNS STRING ->
  CASE WHEN
    -- If the user's current role is NOT one of the privileged roles, the mask the column.
    CURRENT_ROLE() NOT IN ('ACCOUNTADMIN', 'TB_ADMIN')
    THEN '****MASKED****'
    -- Otherwise (if the tag is not sensitive OR the role is privileged), show the original value.
    ELSE original_value
  END;

-- Now create the masking policy for sensitive DATE data
CREATE OR REPLACE MASKING POLICY governance.mask_date_pii AS (original_value DATE)
RETURNS DATE ->
  CASE WHEN
    CURRENT_ROLE() NOT IN ('ACCOUNTADMIN', 'TB_ADMIN')
    THEN DATE_TRUNC('year', original_value) -- When masked, only the year is unchanged, the month and day will be 01-01
    ELSE original_value
  END;

-- Attach both of the masking policies to the tag that was applied automatically to the customer loyalty table
ALTER TAG governance.pii SET
    MASKING POLICY governance.mask_string_pii,
    MASKING POLICY governance.mask_date_pii;

/*
    Switch to the public role, query the first 100 rows from the customer loyalty table to observe 
    how the masking policy obfuscates sensitive data.
*/
USE ROLE public;
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

-- Now, switch to the TB_ADMIN role to observe the masking policy is not applied to admin roles
USE ROLE tb_admin;
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

/*  4. Row Level Security with Row Access Policies
    ***********************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/security-row-intro
    ***********************************************************

    Snowflake supports row-level security using row access policies to determine which rows are returned in query results.
    The policy is attached to a table and works by evaluating each row against rules that you define. These rules often use 
    attributes of the user running the query, such as their current role.

    For example, we can use a row access policy to ensure that users in the United States only see data for customers 
    within the United States.

    First, let's switch our role to our data steward role.
*/
USE ROLE tb_data_steward;

-- Before creating the row access policy, we'll create a row policy map.
CREATE OR REPLACE TABLE governance.row_policy_map
    (role STRING, country_permission STRING);

/*
    The row policy map associates roles with the allowed access row value.
    For example, if we associate our role tb_data_engineer with the country value 'United States', 
    tb_data_engineer will only see rows where the country value is 'United States'.
*/
INSERT INTO governance.row_policy_map
    VALUES('tb_data_engineer', 'United States');

/*
    With the row policy map in place, we'll create the Row Access Policy. 
    
    This policy states that administrators have unrestricted row access, while other roles in the policy map can 
    only see rows matching their associated country.
*/
CREATE OR REPLACE ROW ACCESS POLICY governance.customer_loyalty_policy
    AS (country STRING) RETURNS BOOLEAN ->
        CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN') 
        OR EXISTS 
            (
            SELECT 1
                FROM governance.row_policy_map rp
            WHERE
                UPPER(rp.role) = CURRENT_ROLE()
                AND rp.country_permission = country
            );

-- Apply the row access policy to the customer loyalty table on the 'country' column.
ALTER TABLE raw_customer.customer_loyalty
    ADD ROW ACCESS POLICY governance.customer_loyalty_policy ON (country);

/*
    Now, switch to the role we associated with 'United States' in the row policy map and observe the outcome of 
    querying a table with our row access policy.
*/
USE ROLE tb_data_engineer;

-- We should only see customers from the United States. 
SELECT TOP 100 * FROM raw_customer.customer_loyalty;

/*
    Well done! You should now have a better understanding of how to govern and secure your data with 
    Snowflake's column and row level security strategies. You learned how to create tags to use in 
    conjunction with masking policies to secure columns with Personally Identifiable Information as well as 
    row access policies to ensure roles have access to only certain specific column values.
*/

/*  5. Data Quality Monitoring with Data Metric Functions
    ***********************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/data-quality-intro
    ***********************************************************

    Snowflake maintains data consistency and reliability using Data Metric Functions (DMFs), a powerful feature 
    for automating quality checks directly within the platform. By scheduling these checks on any table or view, 
    users gain a clear understanding of their data's integrity, which leads to more reliable, data-informed decisions.
    
    Snowflake offers both pre-built system DMFs for immediate use and the flexibility to create custom ones for 
    unique business logic, ensuring comprehensive quality monitoring.

    Let's take a look at some of the System DMFs!
*/

-- Now switch back to the TastyBytes data steward role to begin using DMFs
USE ROLE tb_data_steward;

-- This will return the percentage of null customer IDs from the order header table.
SELECT SNOWFLAKE.CORE.NULL_PERCENT(SELECT customer_id FROM raw_pos.order_header);

-- We can use DUPLICATE_COUNT to check for duplicate order IDs.
SELECT SNOWFLAKE.CORE.DUPLICATE_COUNT(SELECT order_id FROM raw_pos.order_header); 

-- Average order total amount for all orders
SELECT SNOWFLAKE.CORE.AVG(SELECT order_total FROM raw_pos.order_header);

/*
    We can also create our own custom Data Metric Functions to monitor data quality according to specific business rules.
    We'll create a custom DMF that checks for order totals that are not equal to the unit price multiplied by the quantity.
*/

-- Create custom Data Metric Function
CREATE OR REPLACE DATA METRIC FUNCTION governance.invalid_order_total_count(
    order_prices_t table(
        order_total NUMBER,
        unit_price NUMBER,
        quantity INTEGER
    )
)
RETURNS NUMBER
AS
'SELECT COUNT(*)
 FROM order_prices_t
 WHERE order_total != unit_price * quantity';

-- Simulates a new order where the total doesn't equal the unit price * quantity
INSERT INTO raw_pos.order_detail
SELECT
    904745311,
    459520442,
    52,
    null,
    0,
    2, -- Quantity
    5.0, -- Unit Price
    5.0, -- Total Price (purposefully incorrect)
    null;

-- Call the custom DMF on the order detail table.
SELECT governance.invalid_order_total_count(
    SELECT 
        price, 
        unit_price, 
        quantity 
    FROM raw_pos.order_detail
) AS num_orders_with_incorrect_price;

-- Set Data Metric Schedule on order detail table to trigger on changes
ALTER TABLE raw_pos.order_detail
    SET DATA_METRIC_SCHEDULE = 'TRIGGER_ON_CHANGES';

-- Assign custom DMF to table 
ALTER TABLE raw_pos.order_detail
    ADD DATA METRIC FUNCTION governance.invalid_order_total_count
    ON (price, unit_price, quantity);

/*  6. Account Security Monitoring with the Trust Center
    **************************************************************
    User-Guide:
    https://docs.snowflake.com/en/user-guide/trust-center/overview
    **************************************************************

    The Trust Center enables automatic checks to evaluate and monitor security risks on your account with the use 
    of scanners. Scanners are scheduled background processes that check your account for security risks and violations, 
    then provide recommended actions based on its findings. They are often grouped together into scanner packages. 
    
    Common use cases for the Trust Center are:
        - Ensuring Multi-Factor Authentication is enabled for users
        - Finding over-priveleged roles
        - Finding inactive users who have not logged in for at least 90 days
        - Find and mitigate risky users

    Before we begin we'll need to grant our admin role the permissions needed to be an administrator for
    the Trust Center.
*/
USE ROLE accountadmin;
GRANT APPLICATION ROLE SNOWFLAKE.TRUST_CENTER_ADMIN TO ROLE tb_admin;
USE ROLE tb_admin; -- Switch back to the TastyBytes admin role

/*
    In the navigation menu, hover over 'Governance & security', and then click 
    'Trust Center'. You can open the Trust Center in a seperate browser tab if preferred.
    When we first load the Trust Center we can see several panes and sections:
        1. Tabs: Findings, Scanner Packages
        2. Password Readiness pane
        3. Open Security Violations
        4. Violations list with filter

    You may see a message under the tabs encouraging you to enable the CIS Benchmarks Scanner Package. 
    We'll do that next.

    Click the 'Scanner Packages' tab. Here we see a list of scanner packages. These are groups of 
    scanners, or scheduled background processes that check for account security risks. For each 
    scanner package we can see its name, the provider, the number of active and inactive scanners,
    and the status. All scanner packages are disabled by default except for the Security Essentials 
    scanner package.
    
    Click on 'CIS Benchmarks' to see more details about the scanner package. Here you'll see the 
    name and description of the scanner package with an option to enable the package. Underneath that
    is the list of scanners in the scanner package. You can click any of these scanners for more detail
    about it like the schedule, the time and day it was last run and description.

    Let's now enable it by clicking the 'Enable Package' button. This will pop up an 'Enable Scanner Package' 
    modal where we can set the schedule for the scanner package. Let's configure this package to run on a 
    monthly schedule.

    Click the dropdown for 'Frequency' and select the option for 'Monthly'. Leave all other values as is. Note 
    that packages are run automatically when enabled and on their configured schedule.
    
    Optionally, we can configure notification settings. We can keep the default values where the minimum 
    severity trigger level is 'Critical' and under Receipients, 'Admin users' is selected. 
    Press 'continue'.
    It may take a few moments for the scanner package to be fully enabled.

    Let's repeat this one more time for the 'Threat Intelligence' scanner package on our account. Use the same 
    configuration settings from the last scanner package. 
    
    Once both packages are enabled, we'll navigate back to the 'Findings' tab to review the violations 
    our scanner packages discovered.

    You should see many more entries in the violation list alongside a graph of the number of violations at 
    each severity level. In the Violation list we can see more information about every violation including a
    short description, the severity and the scanner package. There is also an option to mark the violation as 
    resolved. 
    Furthermore, clicking any of the individual violations will bring up detail pane with more in-depth information
    about the violation, like a summary and options for remediation.

    The violations list can be filtered by status, severity and scanner package by using the dropdown options.
    Clicking a severity category in the violations graph will also apply a filter of that type. 
    
    Cancel out a filter by clicking the 'X' next to the currently active filter category. 
*/

-------------------------------------------------------------------------
--RESET--
-------------------------------------------------------------------------
USE ROLE accountadmin;

-- Drop data steward role
DROP ROLE IF EXISTS tb_data_steward;

-- Masking Policy
ALTER TAG IF EXISTS governance.pii UNSET
    MASKING POLICY governance.mask_string_pii,
    MASKING POLICY governance.mask_date_pii;
DROP MASKING POLICY IF EXISTS governance.mask_string_pii;
DROP MASKING POLICY IF EXISTS governance.mask_date_pii;

-- Auto classification
ALTER SCHEMA raw_customer UNSET CLASSIFICATION_PROFILE;
DROP SNOWFLAKE.DATA_PRIVACY.CLASSIFICATION_PROFILE IF EXISTS tb_classification_profile;

-- row access policies
ALTER TABLE raw_customer.customer_loyalty 
    DROP ROW ACCESS POLICY governance.customer_loyalty_policy;
DROP ROW ACCESS POLICY IF EXISTS governance.customer_loyalty_policy;

-- Data metric functions
DELETE FROM raw_pos.order_detail WHERE order_detail_id = 904745311;
ALTER TABLE raw_pos.order_detail
    DROP DATA METRIC FUNCTION governance.invalid_order_total_count ON (price, unit_price, quantity);
DROP FUNCTION governance.invalid_order_total_count(TABLE(NUMBER, NUMBER, INTEGER));
ALTER TABLE raw_pos.order_detail UNSET DATA_METRIC_SCHEDULE;

-- Unset tags
ALTER TABLE raw_customer.customer_loyalty
  MODIFY
    COLUMN first_name UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN last_name UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN e_mail UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN phone_number UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN postal_code UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN marital_status UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN gender UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN birthday_date UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN country UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY,
    COLUMN city UNSET TAG governance.pii, SNOWFLAKE.CORE.PRIVACY_CATEGORY, SNOWFLAKE.CORE.SEMANTIC_CATEGORY;

-- Drop PII tag
DROP TAG IF EXISTS governance.pii;
-- Unset Query Tag
ALTER SESSION UNSET query_tag;
ALTER WAREHOUSE tb_dev_wh SUSPEND;