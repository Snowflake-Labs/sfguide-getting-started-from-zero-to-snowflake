/*************************************************************************************************** 
Asset:        Zero to Snowflake - AISQL Functions
Version:      v2     
Copyright(c): 2025 Snowflake Inc. All rights reserved.
****************************************************************************************************

AISQL Functions
1. USE SENTIMENT() to score and label truck customer reviews as Positive, Negative, or Neutral
2. Use AI_CLASSIFY() to categorized reviews by themes like Food Quality or Service Experience
3. Use EXTRACT_ANSWER() to pull specific complaints or praise from review text
4. Use AI_SUMMARIZE_AGG() to generate quick summaries of customer sentiment per truck brand name

****************************************************************************************************/

ALTER SESSION SET query_tag = '{"origin":"sf_sit-is","name":"tb_zts","version":{"major":1, "minor":1},"attributes":{"is_quickstart":1, "source":"tastybytes", "vignette": "aisql_functions"}}';

/*
    We will assume the role of a TastyBytes data analyst with the intention of leveraging AISQL functions 
    to gain insights from customer reviews, so let's set our context appropriately.
*/

USE ROLE tb_analyst;
USE DATABASE tb_101;
USE WAREHOUSE tb_analyst_wh;

/* 1. Sentiment Analysis at Scale
    ***************************************************************
    Analyze customer sentiment across all food truck brands to identify which trucks are 
    performing best and create fleet-wide customer satisfaction metrics.
    In Cortex Playground, we analyzed individual reviews manually. Now we’ll use the 
    SENTIMENT() function to automatically score customer reviews from -1 (negative) to +1 (positive),
    following Snowflake's official sentiment ranges.
    ***************************************************************/

-- Business Question: “How do customers feel about each of our truck brands overall?”
-- Please execute this query to analyze customer sentiment across our food truck network and categorize feedback

SELECT
    truck_brand_name,
    COUNT(*) AS total_reviews,
    AVG(CASE WHEN sentiment >= 0.5 THEN sentiment END) AS avg_positive_score,
    AVG(CASE WHEN sentiment BETWEEN -0.5 AND 0.5 THEN sentiment END) AS avg_neutral_score,
    AVG(CASE WHEN sentiment <= -0.5 THEN sentiment END) AS avg_negative_score
FROM (
    SELECT
        truck_brand_name,
        SNOWFLAKE.CORTEX.SENTIMENT (review) AS sentiment
    FROM harmonized.truck_reviews_v
    WHERE
        language ILIKE '%en%'
        AND review IS NOT NULL
    LIMIT 10000
)
GROUP BY
    truck_brand_name
ORDER BY total_reviews DESC;

/*
    Key Insight:
        Notice how we transitioned from analyzing reviews one at a time in Cortex Playground to 
        systematically processing thousands. The SENTIMENT() function automatically                       
        scored every review and categorized them into Positive, Negative, and Neutral - giving 
        us instant fleet-wide customer satisfaction metrics.
    Sentiment Score Ranges:
        Positive:   0.5 to 1
        Neutral:   -0.5 to 0.5
        Negative:  -0.5 to -1
*/

/* 2. Categorize Customer Feedback
    ***************************************************************
    Now, let’s categorize all reviews to understand what aspects of our service customers 
    are talking about most. We'll use the AI_CLASSIFY() function, which automatically 
    categorizes reviews into user-defined categories based on AI understanding, rather than 
    simple keyword matching. In this step, we will categorize customer feedback into 
    business-relevant operational areas and analyze their distribution patterns.
    ***************************************************************/

-- Business Question: “What are customers are primarily commenting on - food quality, service, or delivery experience?
-- Execute the Classification Query:

WITH classified_reviews AS (
  SELECT
    truck_brand_name,
    AI_CLASSIFY(
      review,
      ['Food Quality', 'Pricing', 'Service Experience', 'Staff Behavior']
    ):labels[0] AS feedback_category
  FROM
    harmonized.truck_reviews_v
  WHERE
    language ILIKE '%en%'
    AND review IS NOT NULL
    AND LENGTH(review) > 30
  LIMIT
    10000
)
SELECT
  truck_brand_name,
  feedback_category,
  COUNT(*) AS number_of_reviews
FROM
  classified_reviews
GROUP BY
  truck_brand_name,
  feedback_category
ORDER BY
  truck_brand_name,
  number_of_reviews DESC;
                
/*
    Key Insight:
        Observe how AI_CLASSIFY() automatically categorized thousands of reviews into business-relevant 
        themes such as Food Quality, Service Experience, and more. We can instantly see that Food Quality is 
        the most discussed topic across our truck brands, providing the operations team with clear, actionable 
        insight into customer priorities.
*/

/* 3. Extract Specific Operational Insights
    ***************************************************************
    Next, to gain precise answers from unstructured text, we'll utilize the EXTRACT_ANSWER() 
    function. This powerful function enables us to ask specific business questions about customer 
    feedback and receive direct answers. In this step, our goal is to identify precise operational 
    issues mentioned in customer reviews, highlighting specific problems that require immediate attention.
    ***************************************************************/

--Business question: “What specific operational issues or positive mentions are found within each customer review?”
-- Lets execute the next query:

  SELECT
    truck_brand_name,
    primary_city,
    LEFT(review, 100) || '...' AS review_preview,
    SNOWFLAKE.CORTEX.EXTRACT_ANSWER(
        review,
        'What specific improvement or complaint is mentioned in this review?'
    ) AS specific_feedback
FROM 
    harmonized.truck_reviews_v
WHERE 
    language = 'en'
    AND review IS NOT NULL
    AND LENGTH(review) > 50
ORDER BY truck_brand_name, primary_city ASC
LIMIT 10000;

/*
    Key Insight:
        Notice how EXTRACT_ANSWER() distills specific, actionable insights from long customer reviews. 
        Rather than manual review, this function automatically identifies concrete feedback like 
        "friendly staff was saving grace" and "hot dogs are cooked to perfection." The result is a 
        transformation of dense text into specific, quotable feedback that the operations team can leverage instantly.
*/

/* 4. Generate Executive Summaries
    ***************************************************************
    Finally, to create concise summaries of customer feedback, we'll use the SUMMARIZE() function. 
    This powerful function generates short, coherent summaries from lengthy unstructured text. 
    In this step, our goal is to distill the essence of customer reviews for each truck brand into 
    digestible summaries, providing quick overviews of overall sentiment and key points.
    ***************************************************************/

-- Business Question: “What are the key themes and overall sentiment for each truck brand?”
-- Execute the Summarization Query:

SELECT
  truck_brand_name,
  AI_SUMMARIZE_AGG (review) AS review_summary
FROM
  (
    SELECT
      truck_brand_name,
      review
    FROM
      harmonized.truck_reviews_v
    LIMIT
      100
  )
GROUP BY
  truck_brand_name;


/*
  Key Insight:
      The AI_SUMMARIZE_AGG() function condenses lengthy reviews into clear, brand-level summaries.
      These summaries highlight recurring themes and sentiment trends, providing decision-makers
      with quick overviews of each food truck's performance and enabling faster understanding of
      customer perception without reading individual reviews.
*/

/*************************************************************************************************** 
    We've successfully demonstrated the transformative power of AI SQL functions, shifting customer feedback 
    analysis from individual review processing to systemic, production-scale intelligence. Our journey through 
    these four core functions clearly illustrates how each serves a distinct analytical purpose, transforming raw 
    customer voices into comprehensive business intelligence—systematic, scalable, and immediately actionable. 
    What once required individual review analysis now processes thousands of reviews in seconds, providing both the 
    emotional context and specific details crucial for data-driven operational improvements.
****************************************************************************************************/