# customer-churn-pipeline
An end-to-end SQL data engineering pipeline to clean, standardize, and aggregate messy customer metrics into a production-ready Star Schema.
# End-to-End SaaS Customer 360 & Churn Data Pipeline

## 📌 Project Overview
This project builds an enterprise-grade data engineering pipeline that takes messy, unorganized raw logs (user profiles, app login streams, and financial transaction histories) and transforms them into a clean, production-ready *Star Schema* analytical layer. 

The final output is an aggregated monthly engagement fact table used by data science teams to predict customer churn.

## 🛠️ Tech Stack & Skills
* *Database Engine:* MySQL / MySQL Workbench
* *Data Prep Concepts:* Data Cleansing, Schema Design, Conditional Aggregation, Type Casting, Relational Joins.

## 📂 Database Architecture & Transformation

### 1. The Raw Data Layer (The Mess)
* raw_users: Contained text casing inconsistencies ('Premium' vs 'basic') and multiple, broken date formats (YYYY/MM/DD, DD-MM-YYYY, YYYY-MM-DD) stored as plain text.
* raw_logins: High-volume application logs tracking individual user sessions.
* raw_payments: Raw transaction stream containing both successful payments and failed retries.

### 2. The Transformation & Cleaning Process
* *Text Standardization:* Utilized LOWER() and UPPER() to align dirty business labels.
* *Date Parsing Pipeline:* Implemented a robust CASE WHEN conditional structure using STR_TO_DATE() to normalize multi-format strings into standard database calendar formats.
* *Granular Aggregation:* Summarized millions of row-level event timestamps into structural monthly intervals using DATE_FORMAT() and GROUP BY.
* *Conditional Financial Auditing:* Isolated true revenue from failed billing attempts using SUM(CASE WHEN...) logic to prevent financial reporting skew.

### 3. The Analytics Layer (The Output)
The raw streams were compiled using strict relational LEFT JOIN operations into:
* *dim_users*: A clean, single-source-of-truth user attribute table.
* *fact_monthly_engagement*: An optimized monthly analytical view tracking user activity metrics, active revenue, and payment risk flags.
*
