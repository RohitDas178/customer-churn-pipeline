DROP DATABASE brazil;
DROP DATABASE brazilecommerece;
create DATABASE NETFLIX;
USE NETFLIX;
-- 1. Create the Raw Users Table
CREATE TABLE raw_users (
    user_id INT,
    signup_date VARCHAR(50),      -- Messy: Stored as text, not a proper date type
    country VARCHAR(100),
    plan_type VARCHAR(50),        -- Messy: Mixed casing like 'premium', 'Premium', 'BASIC'
    status VARCHAR(50)
);

-- 2. Create the Raw Logins Table
CREATE TABLE raw_logins (
    login_id INT,
    user_id INT,
    login_timestamp VARCHAR(50),  -- Messy: Stored as text with mixed timestamps
    device_type VARCHAR(50)
);

-- 3. Create the Raw Payments Table
CREATE TABLE raw_payments (
    payment_id INT,
    user_id INT,
    payment_date VARCHAR(50),
    amount_paid DECIMAL(10, 2),
    payment_status VARCHAR(50)    -- Contains 'Success', 'Failed', and some duplicates
);

INSERT INTO raw_users (user_id, signup_date, country, plan_type, status) VALUES
(101, '2025/01/15', 'India', 'Premium', 'Active'),
(102, '2025-01-16', 'USA', 'basic', 'Active'),
(103, '17-01-2025', 'India', 'PREMIUM', 'Cancelled'),
(104, '2025/01/18', 'UK', 'Basic', 'Active'),
(105, '2025-01-19', 'USA', 'premium', 'Active');

-- Insert data into raw_logins (Simulating user activity tracking)
INSERT INTO raw_logins (login_id, user_id, login_timestamp, device_type) VALUES
(1, 101, '2025-01-15 09:30:00', 'Mobile'),
(2, 101, '2025-01-16 14:15:00', 'Mobile'),
(3, 102, '2025-01-16 18:22:00', 'Web'),
(4, 101, '2025-02-01 10:00:00', 'Desktop'),
(5, 103, '2025-01-18 21:04:00', 'Mobile'),
(6, 104, '2025-01-20 08:11:00', 'Web'),
(7, 102, '2025-02-04 19:45:00', 'Web'),
(8, 101, '2025-02-15 11:12:00', 'Mobile'),
(9, 105, '2025-01-20 13:00:00', 'Desktop');

-- Insert data into raw_payments (Simulating financial logs with failures)
INSERT INTO raw_payments (payment_id, user_id, payment_date, amount_paid, payment_status) VALUES
(501, 101, '2025-01-15', 15.00, 'Success'),
(502, 102, '2025-01-16', 9.00, 'Success'),
(503, 103, '2025-01-17', 15.00, 'Success'),
(504, 104, '2025-01-18', 9.00, 'Failed'),
(505, 104, '2025-01-19', 9.00, 'Success'), -- Retry success
(506, 101, '2025-02-15', 15.00, 'Success'),
(507, 102, '2025-02-16', 9.00, 'Failed'); -- This user might churn!

SELECT 
	user_id,LOWER(plan_type) as clean_plan_type,country,UPPER(status) as clean_status
    FROM raw_users;
SELECT 
	user_id,
    signup_date as original_date,
    CASE 
		when signup_date LIKE '%/%/%' THEN STR_TO_DATE(signup_date,'%Y/%m/%d')
        WHEN signup_date LIKE '__-__-____' THEN STR_TO_DATE(signup_date,'%d/%m/%Y')
        ELSE STR_TO_DATE(signup_date,'%Y-%m-%d')
	END AS standard_signup_date
FROM raw_users;

-- 1. Wipe out any old remnants of this table
DROP TABLE IF EXISTS dim_users;

-- 2. Create the clean production table
CREATE TABLE dim_users AS
SELECT 
    user_id,
    LOWER(plan_type) AS clean_plan_type,
    country,
    UPPER(status) AS clean_status,
    CASE 
        -- If it uses slashes, parse as YYYY/MM/DD
        WHEN signup_date LIKE '%/%/%' THEN STR_TO_DATE(signup_date, '%Y/%m/%d')
        -- If it uses dashes and ends with a 4-digit year (like 2025), parse as DD-MM-YYYY
        WHEN signup_date LIKE '%-202_' THEN STR_TO_DATE(signup_date, '%d-%m-%Y')
        -- Otherwise, parse as standard YYYY-MM-DD
        ELSE STR_TO_DATE(signup_date, '%Y-%m-%d')
    END AS standard_signup_date
FROM raw_users;

-- 3. Check your new table!
SELECT * FROM dim_users;

SELECT 
    user_id,
    DATE_FORMAT(login_timestamp, '%Y-%m') AS login_month,
    COUNT(login_id) AS total_monthly_logins
FROM raw_logins
GROUP BY user_id, DATE_FORMAT(login_timestamp, '%Y-%m')
ORDER BY user_id, login_month;

SELECT 
    user_id,
    DATE_FORMAT(payment_date, '%Y-%m') AS payment_month,
    -- Count only the successful money
    SUM(CASE WHEN payment_status = 'Success' THEN amount_paid ELSE 0 END) AS total_revenue_collected,
    -- Create a flag to show if they had any payment failures this month (1 = Yes, 0 = No)
    MAX(CASE WHEN payment_status = 'Failed' THEN 1 ELSE 0 END) AS had_payment_failure
FROM raw_payments
GROUP BY user_id, DATE_FORMAT(payment_date, '%Y-%m');

-- 1. Clean up any old versions
DROP TABLE IF EXISTS fact_monthly_engagement;

-- 2. Build the master Fact Table
CREATE TABLE fact_monthly_engagement AS
SELECT 
    u.user_id,
    u.clean_plan_type,
    u.clean_status AS account_status,
    COALESCE(l.login_month, p.payment_month) AS activity_month,
    COALESCE(l.total_monthly_logins, 0) AS total_logins,
    COALESCE(p.total_revenue_collected, 0.00) AS revenue_collected,
    COALESCE(p.had_payment_failure, 0) AS payment_failed_flag
FROM dim_users u
-- Join the monthly logins summary
LEFT JOIN (
    SELECT 
        user_id,
        DATE_FORMAT(login_timestamp, '%Y-%m') AS login_month,
        COUNT(login_id) AS total_monthly_logins
    FROM raw_logins
    GROUP BY user_id, DATE_FORMAT(login_timestamp, '%Y-%m')
) l ON u.user_id = l.user_id
-- Join the monthly payments summary
LEFT JOIN (
    SELECT 
        user_id,
        DATE_FORMAT(payment_date, '%Y-%m') AS payment_month,
        SUM(CASE WHEN payment_status = 'Success' THEN amount_paid ELSE 0 END) AS total_revenue_collected,
        MAX(CASE WHEN payment_status = 'Failed' THEN 1 ELSE 0 END) AS had_payment_failure
    FROM raw_payments
    GROUP BY user_id, DATE_FORMAT(payment_date, '%Y-%m')
) p ON u.user_id = p.user_id AND l.login_month = p.payment_month;

-- 3. View your completed project pipeline!
SELECT * FROM fact_monthly_engagement;