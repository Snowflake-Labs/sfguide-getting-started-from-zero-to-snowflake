/*************************************************************************************************** 
Asset:        Zero to Snowflake - Cortex Code
Version:      v3     
Copyright(c): 2026 Snowflake Inc. All rights reserved.
****************************************************************************************************/

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "cortex_code"}}';

/*
    We will assume the role of a TastyBytes data analyst with the intention of leveraging Cortex Code 
    to build sophisticated queries and gain deeper business insights, so let's set our context appropriately.
*/

/* 1. Accessing Cortex Code and Setting Up Context
    ***************************************************************
    Follow these steps to start using Cortex Code:
    ***************************************************************/

-- before we start, we will set our context
USE ROLE tb_analyst;
USE WAREHOUSE tb_analyst_wh;
USE DATABASE tb_101;
USE SCHEMA harmonized;

/* 2. Requirement Translation with Cortex Code
    ***************************************************************
    To begin, let’s explore what types of analysis questions we can ask about our Tasty Bytes dataset 
    using Cortex Code’s natural language understanding capabilities. Type the following question in the Cortex Code 
    message box and click RUN to see the result of the query:
            
    Prompt 1: How do I structure a query that correlates customer review sentiment with customer loyalty metrics 
    and order behavior? I have a review sentiment data and customer loyalty metrics tables with order information. 
    I need to understand the relationship between what customers say and their actual purchasing pattern.
    ***************************************************************/

/*
    Key Inisght: 
        Cortex Code provides schema-aware business intelligence, directly analyzing your specific Tasty Bytes tables 
        and suggesting strategic analysis using your actual column names. This isn't generic AI; it's purpose-built 
        intelligence that profoundly understands your data structure.
*/

/* 3. Complex Query Building with Cortex Code
    ***************************************************************
    Now let’s use Cortex Code to generate complex SQL with multiple table joins from a simple business question.

    In the same Cortex Code panel, paste the following business question and click RUN to see the result:

    Prompt 2: Show me high-value customers who have been leaving negative reviews. I want to understand 
    which customers spend a lot of money with us but seem unhappy based on their feedback
    ***************************************************************/

/*
    Key Insight:
        Notice how Cortex Code transforms a simple business question into production-ready customer intelligence 
        with complex analytical logic and actionable results—all without requiring SQL expertise.
        This showcases Cortex Code's core value: you can ask strategic questions in plain English and instantly 
        receive the enterprise-grade analytics that typically demand data engineering skills.
*/

/*************************************************************************************************** 
    Cortex Code is Snowflake's agentic development environment, bringing an AI coding assistant directly to your 
    Snowflake workflow. Rather than acting as a simple text-to-SQL box, it works agentically: it can explore your 
    databases, schemas, and tables, understand your data structure, and then plan and execute multi-step tasks such 
    as writing and running SQL, building pipelines, debugging errors, and creating apps. As demonstrated with Tasty 
    Bytes, it empowers both technical and non-technical users to translate business questions into sophisticated, 
    production-ready queries and derive actionable insights without deep SQL expertise. Because it is deeply 
    integrated with Snowflake, Cortex Code operates with your existing roles and privileges and keeps all enterprise 
    data securely governed within Snowflake, making it a strategic tool that bridges operational insights with 
    business intelligence.
****************************************************************************************************/