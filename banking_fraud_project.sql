/* =====================================================================
   Intelligent Banking Transaction Control, Fraud Risk Detection
   & Financial Analytics Using SQL and Power BI
   Database : MySQL 8.0+   (MySQL Workbench -> File -> Open SQL Script -> Run all)
   ===================================================================== */

DROP DATABASE IF EXISTS banking_fraud_db;
CREATE DATABASE banking_fraud_db;
USE banking_fraud_db;

-- ---------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------
CREATE TABLE branches (
    branch_id    INT PRIMARY KEY AUTO_INCREMENT,
    branch_name  VARCHAR(60) NOT NULL,
    city         VARCHAR(40) NOT NULL,
    ifsc_code    VARCHAR(15) UNIQUE
);

CREATE TABLE customers (
    customer_id  INT PRIMARY KEY AUTO_INCREMENT,
    full_name    VARCHAR(80) NOT NULL,
    gender       CHAR(1),
    dob          DATE,
    phone        VARCHAR(15),
    email        VARCHAR(80),
    city         VARCHAR(40),
    kyc_status   ENUM('VERIFIED','PENDING') DEFAULT 'PENDING',
    joined_date  DATE
);

CREATE TABLE accounts (
    account_id    INT PRIMARY KEY AUTO_INCREMENT,
    customer_id   INT NOT NULL,
    branch_id     INT NOT NULL,
    account_type  ENUM('SAVINGS','CURRENT','SALARY') NOT NULL,
    balance       DECIMAL(14,2) NOT NULL DEFAULT 0 CHECK (balance >= 0),
    status        ENUM('ACTIVE','FROZEN','CLOSED') NOT NULL DEFAULT 'ACTIVE',
    open_date     DATE,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (branch_id)   REFERENCES branches(branch_id)
);

CREATE TABLE transactions (
    txn_id               BIGINT PRIMARY KEY AUTO_INCREMENT,
    account_id           INT NOT NULL,
    txn_type             ENUM('DEPOSIT','WITHDRAWAL','TRANSFER','UPI','CARD_PAYMENT') NOT NULL,
    amount               DECIMAL(12,2) NOT NULL CHECK (amount > 0),
    txn_datetime         DATETIME NOT NULL,
    channel              ENUM('ATM','MOBILE','INTERNET','BRANCH','POS') NOT NULL,
    location             VARCHAR(40),
    txn_status           ENUM('SUCCESS','FAILED') NOT NULL DEFAULT 'SUCCESS',
    receiver_account_id  INT NULL,
    is_flagged           TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (account_id) REFERENCES accounts(account_id),
    INDEX idx_acc_time (account_id, txn_datetime),
    INDEX idx_time (txn_datetime)
);

CREATE TABLE fraud_alerts (
    alert_id     BIGINT PRIMARY KEY AUTO_INCREMENT,
    txn_id       BIGINT NOT NULL,
    account_id   INT NOT NULL,
    rule_code    VARCHAR(30) NOT NULL,
    rule_desc    VARCHAR(100),
    risk_points  INT NOT NULL,
    alert_time   DATETIME NOT NULL,
    status       ENUM('OPEN','REVIEWED','CLOSED') DEFAULT 'OPEN',
    INDEX idx_alert_txn (txn_id),
    INDEX idx_alert_acc (account_id)
);

CREATE TABLE audit_log (
    log_id      INT PRIMARY KEY AUTO_INCREMENT,
    account_id  INT,
    action      VARCHAR(100),
    old_value   VARCHAR(30),
    new_value   VARCHAR(30),
    changed_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 2. TRIGGERS  (transaction control + audit)
-- ---------------------------------------------------------------------
DELIMITER $$

-- Auto-flag very high value transactions at insert time
CREATE TRIGGER trg_flag_high_value
BEFORE INSERT ON transactions
FOR EACH ROW
BEGIN
    IF NEW.amount >= 200000 THEN
        SET NEW.is_flagged = 1;
    END IF;
END$$

-- Audit every account status change (freeze / unfreeze / close)
CREATE TRIGGER trg_audit_account_status
AFTER UPDATE ON accounts
FOR EACH ROW
BEGIN
    IF OLD.status <> NEW.status THEN
        INSERT INTO audit_log(account_id, action, old_value, new_value)
        VALUES (NEW.account_id, 'ACCOUNT STATUS CHANGED', OLD.status, NEW.status);
    END IF;
END$$

DELIMITER ;

-- ---------------------------------------------------------------------
-- 3. SAMPLE DATA  (generated purely with SQL - no external files)
-- ---------------------------------------------------------------------
SET SESSION cte_max_recursion_depth = 50000;

INSERT INTO branches(branch_name, city, ifsc_code) VALUES
('Anna Nagar Branch','Chennai','BANK0001001'),
('T Nagar Branch','Chennai','BANK0001002'),
('Gandhipuram Branch','Coimbatore','BANK0002001'),
('Anna Salai Branch','Madurai','BANK0003001'),
('Srirangam Branch','Tiruchirappalli','BANK0004001'),
('Fort Branch','Salem','BANK0005001'),
('Palayamkottai Branch','Tirunelveli','BANK0006001'),
('Koramangala Branch','Bengaluru','BANK0007001');

-- 500 customers
INSERT INTO customers(full_name, gender, dob, phone, email, city, kyc_status, joined_date)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i+1 FROM n WHERE i < 500)
SELECT
    CONCAT(
      ELT(1+FLOOR(RAND()*15),'Arun','Karthik','Priya','Divya','Suresh','Meena','Vignesh','Lakshmi',
          'Ramesh','Kavitha','Saravanan','Deepa','Manoj','Anitha','Harish'),' ',
      ELT(1+FLOOR(RAND()*10),'Kumar','Raj','Subramanian','Krishnan','Selvam','Murugan','Natarajan',
          'Iyer','Pandian','Venkatesh')),
    ELT(1+FLOOR(RAND()*2),'M','F'),
    DATE('1960-01-01') + INTERVAL FLOOR(RAND()*15000) DAY,
    CONCAT('9', LPAD(FLOOR(RAND()*1000000000),9,'0')),
    CONCAT('customer', i, '@examplebank.com'),
    ELT(1+FLOOR(RAND()*8),'Chennai','Coimbatore','Madurai','Tiruchirappalli','Salem','Tirunelveli','Erode','Vellore'),
    IF(RAND() < 0.9,'VERIFIED','PENDING'),
    DATE('2018-01-01') + INTERVAL FLOOR(RAND()*2000) DAY
FROM n;

-- 600 accounts (some customers hold 2 accounts)
INSERT INTO accounts(customer_id, branch_id, account_type, balance, status, open_date)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i+1 FROM n WHERE i < 600)
SELECT
    ((i-1) % 500) + 1,
    1 + FLOOR(RAND()*8),
    ELT(1+FLOOR(RAND()*3),'SAVINGS','CURRENT','SALARY'),
    ROUND(5000 + RAND()*495000, 2),
    IF(RAND() < 0.97,'ACTIVE','FROZEN'),
    DATE('2019-01-01') + INTERVAL FLOOR(RAND()*2000) DAY
FROM n;

-- 20,000 normal-looking transactions (Jan 2025 - Sep 2026)
INSERT INTO transactions(account_id, txn_type, amount, txn_datetime, channel, location, txn_status, receiver_account_id)
WITH RECURSIVE n AS (SELECT 1 AS i UNION ALL SELECT i+1 FROM n WHERE i < 20000)
SELECT
    1 + FLOOR(RAND()*600),
    ELT(1+FLOOR(RAND()*5),'DEPOSIT','WITHDRAWAL','TRANSFER','UPI','CARD_PAYMENT'),
    IF(RAND() < 0.015, ROUND(200000 + RAND()*300000,2), ROUND(100 + POW(RAND(),3)*60000,2)),
    TIMESTAMP('2025-01-01 00:00:00') + INTERVAL FLOOR(RAND()*630) DAY + INTERVAL FLOOR(RAND()*86400) SECOND,
    ELT(1+FLOOR(RAND()*5),'ATM','MOBILE','INTERNET','BRANCH','POS'),
    IF(RAND() < 0.03,
       ELT(1+FLOOR(RAND()*4),'Dubai','Singapore','London','New York'),
       ELT(1+FLOOR(RAND()*8),'Chennai','Coimbatore','Madurai','Tiruchirappalli','Salem','Tirunelveli','Erode','Bengaluru')),
    IF(RAND() < 0.04,'FAILED','SUCCESS'),
    IF(RAND() < 0.5, 1 + FLOOR(RAND()*600), NULL)
FROM n;

-- Injected FRAUD PATTERN 1: velocity burst (6 UPI txns in 30 minutes) - accounts 1..20
INSERT INTO transactions(account_id, txn_type, amount, txn_datetime, channel, location, txn_status)
WITH RECURSIVE k AS (SELECT 1 AS j UNION ALL SELECT j+1 FROM k WHERE j < 6)
SELECT a.account_id, 'UPI', ROUND(4000 + RAND()*5000,2),
       TIMESTAMP('2026-03-10 14:00:00') + INTERVAL ((a.account_id*13) % 200) DAY + INTERVAL (k.j*5) MINUTE,
       'MOBILE', 'Chennai', 'SUCCESS'
FROM accounts a JOIN k
WHERE a.account_id BETWEEN 1 AND 20;

-- Injected FRAUD PATTERN 2: impossible travel (Chennai then Dubai in 40 min) - accounts 21..40
INSERT INTO transactions(account_id, txn_type, amount, txn_datetime, channel, location, txn_status)
SELECT account_id, 'CARD_PAYMENT', 8500,
       TIMESTAMP('2026-05-05 10:00:00') + INTERVAL ((account_id*7) % 120) DAY, 'POS', 'Chennai', 'SUCCESS'
FROM accounts WHERE account_id BETWEEN 21 AND 40
UNION ALL
SELECT account_id, 'CARD_PAYMENT', 45000,
       TIMESTAMP('2026-05-05 10:40:00') + INTERVAL ((account_id*7) % 120) DAY, 'POS', 'Dubai', 'SUCCESS'
FROM accounts WHERE account_id BETWEEN 21 AND 40;

-- Injected FRAUD PATTERN 3: repeated failed attempts (4 failed ATM withdrawals in a day) - accounts 41..60
INSERT INTO transactions(account_id, txn_type, amount, txn_datetime, channel, location, txn_status)
WITH RECURSIVE k AS (SELECT 1 AS j UNION ALL SELECT j+1 FROM k WHERE j < 4)
SELECT a.account_id, 'WITHDRAWAL', 20000,
       TIMESTAMP('2026-06-15 02:00:00') + INTERVAL ((a.account_id*5) % 90) DAY + INTERVAL (k.j*3) MINUTE,
       'ATM', 'Salem', 'FAILED'
FROM accounts a JOIN k
WHERE a.account_id BETWEEN 41 AND 60;

-- ---------------------------------------------------------------------
-- 4. STORED PROCEDURE : SECURE FUND TRANSFER (ACID transaction control)
-- ---------------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE sp_transfer_funds(
    IN  p_from    INT,
    IN  p_to      INT,
    IN  p_amount  DECIMAL(12,2),
    IN  p_channel VARCHAR(20),
    OUT p_msg     VARCHAR(100)
)
proc: BEGIN
    DECLARE v_bal      DECIMAL(14,2);
    DECLARE v_status   VARCHAR(10);
    DECLARE v_to_stat  VARCHAR(10);
    DECLARE v_today    DECIMAL(14,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_msg = 'ERROR: Transaction rolled back';
    END;

    IF p_amount <= 0 OR p_from = p_to THEN
        SET p_msg = 'REJECTED: Invalid amount or same account';
        LEAVE proc;
    END IF;

    START TRANSACTION;

    SELECT balance, status INTO v_bal, v_status
      FROM accounts WHERE account_id = p_from FOR UPDATE;
    SELECT status INTO v_to_stat
      FROM accounts WHERE account_id = p_to FOR UPDATE;

    IF v_status IS NULL OR v_to_stat IS NULL THEN
        ROLLBACK; SET p_msg = 'REJECTED: Account not found'; LEAVE proc;
    END IF;

    IF v_status <> 'ACTIVE' OR v_to_stat <> 'ACTIVE' THEN
        ROLLBACK;
        INSERT INTO transactions(account_id,txn_type,amount,txn_datetime,channel,location,txn_status,receiver_account_id)
        VALUES (p_from,'TRANSFER',p_amount,NOW(),p_channel,'Chennai','FAILED',p_to);
        SET p_msg = 'REJECTED: Account is not active'; LEAVE proc;
    END IF;

    IF v_bal < p_amount THEN
        ROLLBACK;
        INSERT INTO transactions(account_id,txn_type,amount,txn_datetime,channel,location,txn_status,receiver_account_id)
        VALUES (p_from,'TRANSFER',p_amount,NOW(),p_channel,'Chennai','FAILED',p_to);
        SET p_msg = 'REJECTED: Insufficient balance'; LEAVE proc;
    END IF;

    -- Daily transfer limit = 2,00,000
    SELECT IFNULL(SUM(amount),0) INTO v_today
      FROM transactions
     WHERE account_id = p_from AND txn_status='SUCCESS'
       AND txn_type IN ('TRANSFER','UPI') AND DATE(txn_datetime) = CURDATE();

    IF v_today + p_amount > 200000 THEN
        ROLLBACK;
        INSERT INTO transactions(account_id,txn_type,amount,txn_datetime,channel,location,txn_status,receiver_account_id)
        VALUES (p_from,'TRANSFER',p_amount,NOW(),p_channel,'Chennai','FAILED',p_to);
        SET p_msg = 'REJECTED: Daily limit exceeded'; LEAVE proc;
    END IF;

    UPDATE accounts SET balance = balance - p_amount WHERE account_id = p_from;
    UPDATE accounts SET balance = balance + p_amount WHERE account_id = p_to;

    INSERT INTO transactions(account_id,txn_type,amount,txn_datetime,channel,location,txn_status,receiver_account_id)
    VALUES (p_from,'TRANSFER',p_amount,NOW(),p_channel,'Chennai','SUCCESS',p_to);

    COMMIT;
    SET p_msg = 'SUCCESS: Transfer completed';
END$$

-- Freeze an account (audit trigger records it automatically)
CREATE PROCEDURE sp_freeze_account(IN p_account INT)
BEGIN
    UPDATE accounts SET status = 'FROZEN' WHERE account_id = p_account;
END$$

-- ---------------------------------------------------------------------
-- 5. FRAUD DETECTION ENGINE (rule based risk scoring)
-- ---------------------------------------------------------------------
CREATE PROCEDURE sp_run_fraud_detection()
BEGIN
    TRUNCATE TABLE fraud_alerts;

    -- R1 : High value transaction (>= 2,00,000)                      -> 40 pts
    INSERT INTO fraud_alerts(txn_id,account_id,rule_code,rule_desc,risk_points,alert_time)
    SELECT txn_id, account_id, 'R1_HIGH_VALUE', 'Transaction amount >= 2,00,000', 40, txn_datetime
      FROM transactions WHERE amount >= 200000 AND txn_status='SUCCESS';

    -- R2 : Night-time (12AM-5AM) transaction of >= 50,000             -> 25 pts
    INSERT INTO fraud_alerts(txn_id,account_id,rule_code,rule_desc,risk_points,alert_time)
    SELECT txn_id, account_id, 'R2_NIGHT_HIGH', 'Night transaction >= 50,000', 25, txn_datetime
      FROM transactions
     WHERE HOUR(txn_datetime) BETWEEN 0 AND 4 AND amount >= 50000 AND txn_status='SUCCESS';

    -- R3 : Foreign / high-risk location                               -> 30 pts
    INSERT INTO fraud_alerts(txn_id,account_id,rule_code,rule_desc,risk_points,alert_time)
    SELECT txn_id, account_id, 'R3_FOREIGN_LOC', 'Transaction from foreign location', 30, txn_datetime
      FROM transactions
     WHERE location IN ('Dubai','Singapore','London','New York') AND txn_status='SUCCESS';

    -- R4 : Velocity - 5 or more transactions within 1 hour            -> 35 pts
    INSERT INTO fraud_alerts(txn_id,account_id,rule_code,rule_desc,risk_points,alert_time)
    SELECT txn_id, account_id, 'R4_VELOCITY', '5+ transactions within 1 hour', 35, txn_datetime
      FROM (
        SELECT txn_id, account_id, txn_datetime,
               COUNT(*) OVER (PARTITION BY account_id ORDER BY txn_datetime
                              RANGE BETWEEN INTERVAL 1 HOUR PRECEDING AND CURRENT ROW) AS cnt
          FROM transactions WHERE txn_status='SUCCESS'
      ) x WHERE cnt >= 5;

    -- R5 : 3 or more failed attempts on the same day                  -> 20 pts
    INSERT INTO fraud_alerts(txn_id,account_id,rule_code,rule_desc,risk_points,alert_time)
    SELECT MIN(txn_id), account_id, 'R5_FAILED_ATTEMPTS', '3+ failed attempts in a day', 20, MIN(txn_datetime)
      FROM transactions WHERE txn_status='FAILED'
     GROUP BY account_id, DATE(txn_datetime)
    HAVING COUNT(*) >= 3;

    -- R6 : Impossible travel - city changed within 2 hours            -> 45 pts
    INSERT INTO fraud_alerts(txn_id,account_id,rule_code,rule_desc,risk_points,alert_time)
    SELECT txn_id, account_id, 'R6_IMPOSSIBLE_TRAVEL', 'Location changed within 2 hours', 45, txn_datetime
      FROM (
        SELECT txn_id, account_id, txn_datetime, location,
               LAG(location)     OVER (PARTITION BY account_id ORDER BY txn_datetime) AS prev_loc,
               LAG(txn_datetime) OVER (PARTITION BY account_id ORDER BY txn_datetime) AS prev_time
          FROM transactions WHERE txn_status='SUCCESS'
      ) t
     WHERE prev_loc IS NOT NULL AND location <> prev_loc
       AND TIMESTAMPDIFF(MINUTE, prev_time, txn_datetime) <= 120;

    -- Mark transactions that triggered any rule
    UPDATE transactions t
      JOIN (SELECT DISTINCT txn_id FROM fraud_alerts) f ON f.txn_id = t.txn_id
       SET t.is_flagged = 1;
END$$

DELIMITER ;

CALL sp_run_fraud_detection();

-- ---------------------------------------------------------------------
-- 6. VIEWS FOR POWER BI
-- ---------------------------------------------------------------------

-- Main fact view (one row per transaction, fully flattened)
CREATE OR REPLACE VIEW vw_txn_detail AS
SELECT
    t.txn_id,
    t.txn_datetime,
    DATE(t.txn_datetime)                       AS txn_date,
    HOUR(t.txn_datetime)                       AS txn_hour,
    DATE_FORMAT(t.txn_datetime,'%Y-%m')        AS txn_month,
    DAYNAME(t.txn_datetime)                    AS txn_day,
    t.txn_type,
    t.channel,
    t.location,
    t.amount,
    CASE WHEN t.amount < 5000   THEN '1. Below 5K'
         WHEN t.amount < 25000  THEN '2. 5K - 25K'
         WHEN t.amount < 100000 THEN '3. 25K - 1L'
         ELSE '4. Above 1L' END                AS amount_band,
    CASE WHEN t.txn_type='DEPOSIT' THEN 'CREDIT' ELSE 'DEBIT' END AS direction,
    t.txn_status,
    t.is_flagged,
    a.account_id,
    a.account_type,
    a.status                                   AS account_status,
    b.branch_name,
    b.city                                     AS branch_city,
    c.customer_id,
    c.full_name                                AS customer_name,
    c.city                                     AS customer_city,
    c.kyc_status,
    IFNULL(f.pts,0)                            AS txn_risk_points,
    IFNULL(f.rules,'None')                     AS rules_triggered,
    CASE WHEN IFNULL(f.pts,0) >= 60 THEN 'High Risk'
         WHEN IFNULL(f.pts,0) >= 30 THEN 'Medium Risk'
         WHEN IFNULL(f.pts,0) >  0  THEN 'Low Risk'
         ELSE 'Normal' END                     AS txn_risk_level
FROM transactions t
JOIN accounts  a ON a.account_id  = t.account_id
JOIN branches  b ON b.branch_id   = a.branch_id
JOIN customers c ON c.customer_id = a.customer_id
LEFT JOIN (
    SELECT txn_id, SUM(risk_points) AS pts, GROUP_CONCAT(rule_code SEPARATOR ', ') AS rules
      FROM fraud_alerts GROUP BY txn_id
) f ON f.txn_id = t.txn_id;

-- Account level risk score
CREATE OR REPLACE VIEW vw_account_risk AS
SELECT
    a.account_id,
    c.full_name AS customer_name,
    b.branch_name,
    a.account_type,
    a.status,
    a.balance,
    COUNT(fa.alert_id)               AS total_alerts,
    IFNULL(SUM(fa.risk_points),0)    AS risk_score,
    CASE WHEN IFNULL(SUM(fa.risk_points),0) >= 150 THEN 'CRITICAL'
         WHEN IFNULL(SUM(fa.risk_points),0) >= 80  THEN 'HIGH'
         WHEN IFNULL(SUM(fa.risk_points),0) >= 30  THEN 'MEDIUM'
         ELSE 'LOW' END             AS risk_category
FROM accounts a
JOIN customers c ON c.customer_id = a.customer_id
JOIN branches  b ON b.branch_id   = a.branch_id
LEFT JOIN fraud_alerts fa ON fa.account_id = a.account_id
GROUP BY a.account_id, c.full_name, b.branch_name, a.account_type, a.status, a.balance;

-- Monthly financial summary
CREATE OR REPLACE VIEW vw_monthly_summary AS
SELECT
    DATE_FORMAT(txn_datetime,'%Y-%m') AS txn_month,
    COUNT(*)                                                         AS total_txns,
    SUM(txn_status='SUCCESS')                                        AS success_txns,
    SUM(txn_status='FAILED')                                         AS failed_txns,
    SUM(CASE WHEN txn_type='DEPOSIT'  AND txn_status='SUCCESS' THEN amount ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN txn_type<>'DEPOSIT' AND txn_status='SUCCESS' THEN amount ELSE 0 END) AS total_debits,
    SUM(is_flagged)                                                  AS flagged_txns
FROM transactions
GROUP BY DATE_FORMAT(txn_datetime,'%Y-%m');

-- Branch performance
CREATE OR REPLACE VIEW vw_branch_performance AS
SELECT
    b.branch_name, b.city,
    COUNT(DISTINCT a.account_id)               AS total_accounts,
    SUM(a.balance) / COUNT(t.txn_id)           AS avg_balance_per_txn,
    COUNT(t.txn_id)                            AS total_txns,
    SUM(CASE WHEN t.txn_status='SUCCESS' THEN t.amount ELSE 0 END) AS txn_value,
    SUM(t.is_flagged)                          AS flagged_txns
FROM branches b
JOIN accounts a ON a.branch_id = b.branch_id
LEFT JOIN transactions t ON t.account_id = a.account_id
GROUP BY b.branch_name, b.city;

-- ---------------------------------------------------------------------
-- 7. ANALYTICAL QUERIES (for viva / report screenshots)
-- ---------------------------------------------------------------------

-- Q1. Fraud alerts by rule
SELECT rule_code, COUNT(*) AS alerts, SUM(risk_points) AS total_points
  FROM fraud_alerts GROUP BY rule_code ORDER BY alerts DESC;

-- Q2. Top 10 riskiest accounts
SELECT * FROM vw_account_risk ORDER BY risk_score DESC LIMIT 10;

-- Q3. Month-over-month transaction value growth
SELECT txn_month, total_debits,
       ROUND((total_debits - LAG(total_debits) OVER (ORDER BY txn_month))
             / LAG(total_debits) OVER (ORDER BY txn_month) * 100, 2) AS mom_growth_pct
  FROM vw_monthly_summary;

-- Q4. Channel-wise failure rate
SELECT channel, COUNT(*) AS total,
       ROUND(SUM(txn_status='FAILED')/COUNT(*)*100,2) AS failure_pct
  FROM transactions GROUP BY channel ORDER BY failure_pct DESC;

-- Q5. Hour-wise flagged transactions (shows night-time risk)
SELECT HOUR(txn_datetime) AS hr, COUNT(*) AS flagged
  FROM transactions WHERE is_flagged=1 GROUP BY hr ORDER BY hr;

-- Q6. Rank branches by transaction value
SELECT branch_name, txn_value, RANK() OVER (ORDER BY txn_value DESC) AS rnk
  FROM vw_branch_performance;

-- ---------------------------------------------------------------------
-- 8. DEMO : test the secure transfer + freeze + audit
-- ---------------------------------------------------------------------
-- CALL sp_transfer_funds(1, 2, 5000, 'MOBILE', @msg);   SELECT @msg;
-- CALL sp_transfer_funds(1, 2, 99999999, 'MOBILE', @msg); SELECT @msg;   -- insufficient balance
-- CALL sp_freeze_account(5);  SELECT * FROM audit_log;
-- CALL sp_run_fraud_detection();   -- re-run after new transactions, then Refresh in Power BI
