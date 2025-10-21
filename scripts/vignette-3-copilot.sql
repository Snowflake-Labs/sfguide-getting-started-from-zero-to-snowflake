/*************************************************************************************************** 
Asset:        Zero to Snowflake - Snowflake Copilot
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************/

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "snowflake_copilot"}}';

/*
    We will assume the role of a TastyBytes data analyst with the intention of leveraging Snowflake Copilot 
    to build sophisticated queries and gain deeper business insights, so let's set our context appropriately.
*/

/* 1. Accessing Snowflake Copilot and Setting Up Context
    ***************************************************************
    Follow these steps to start using Snowflake Copilot:
    ***************************************************************/

-- before we start, we will set our context
USE ROLE tb_analyst;
USE WAREHOUSE tb_analyst_wh;
USE DATABASE tb_101;
USE SCHEMA harmonized;

/* 2. Requirement Translation with Copilot
    ***************************************************************
    To begin, let’s explore what types of analysis questions we can ask about our Tasty Bytes dataset 
    using Copilot’s natural language understanding capabilities. Type the following question in the Copilot 
    message box and click RUN to see the result of the query:
            
    Prompt 1: How do I structure a query that correlates customer review sentiment with customer loyalty metrics 
    and order behavior? I have a review sentiment data and customer loyalty metrics tables with order information. 
    I need to understand the relationship between what customers say and their actual purchasing pattern.
    ***************************************************************/

/*
    Key Inisght: 
        Copilot provides schema-aware business intelligence, directly analyzing your specific Tasty Bytes tables 
        and suggesting strategic analysis using your actual column names. This isn't generic AI; it's purpose-built 
        intelligence that profoundly understands your data structure.
*/

/* 3. Complex Query Building with Copilot
    ***************************************************************
    Now let’s use Copilot to generate complex SQL with multiple table joins from a simple business question.

    In the same Copilot panel, paste the following business question and click RUN to see the result:

    Prompt 2: Show me high-value customers who have been leaving negative reviews. I want to understand 
    which customers spend a lot of money with us but seem unhappy based on their feedback
    ***************************************************************/

/*
    Key Insight:
        Notice how Copilot transforms a simple business question into production-ready customer intelligence 
        with complex analytical logic and actionable results—all without requiring SQL expertise.
        This showcases Copilot's core value: you can ask strategic questions in plain English and instantly 
        receive the enterprise-grade analytics that typically demand data engineering skills.
*/

/*************************************************************************************************** 
    Snowflake Copilot profoundly transforms business intelligence by enabling users to effortlessly translate complex
    business questions into sophisticated SQL queries. As demonstrated with Tasty Bytes, it empowers both technical and 
    non-technical users to derive actionable insights from their data without deep SQL expertise. This LLM-powered assistant, 
    fine-tuned within Snowflake Cortex, delivers schema-aware, purpose-built intelligence, ensuring robust data governance and 
    keeping all enterprise data securely within Snowflake. Copilot isn't just generic AI; it's a strategic tool that bridges 
    operational insights with business intelligence, allowing organizations to understand not only what customers say but also 
    how it impacts loyalty and purchasing beha
****************************************************************************************************/