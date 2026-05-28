-- ============================================================
-- PharmaKeep — Milestone 5: Data Population & Validation
-- Author   : Awais Qarni | BSSE | Group B
-- Date     : 17 May 2026
-- ============================================================
-- SECTION A: LOAD DATA INFILE (fastest method)
-- Adjust the path to where your CSV files reside.
-- ============================================================

USE pharmaKeep;

-- Temporarily disable FK checks during bulk load
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Staff
LOAD DATA INFILE '/var/lib/mysql-files/Staff.csv'
INTO TABLE Staff
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(StaffID, FullName, Username, PasswordHash, Role);

-- 2. Category
LOAD DATA INFILE '/var/lib/mysql-files/Category.csv'
INTO TABLE Category
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(CategoryID, CategoryName);

-- 3. Medicines
LOAD DATA INFILE '/var/lib/mysql-files/Medicines.csv'
INTO TABLE Medicines
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(MedicineID, BrandName, GenericName, CategoryID, Description);

-- 4. Suppliers
LOAD DATA INFILE '/var/lib/mysql-files/Suppliers.csv'
INTO TABLE Suppliers
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(SupplierID, SupplierName, ContactPerson, PhoneNumber, Email);

-- 5. Batches
LOAD DATA INFILE '/var/lib/mysql-files/Batches.csv'
INTO TABLE Batches
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(BatchID, BatchNumber, MedicineID, SupplierID, ExpiryDate,
 QuantityReceived, QuantityOnHand, CostPrice, SellingPrice);

-- 6. Sales
LOAD DATA INFILE '/var/lib/mysql-files/Sales.csv'
INTO TABLE Sales
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(SaleID, SaleDateTime, StaffID, TotalAmount, PaymentMethod);

-- 7. SaleItems
LOAD DATA INFILE '/var/lib/mysql-files/SaleItems.csv'
INTO TABLE SaleItems
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(SaleItemID, SaleID, BatchID, QuantitySold, UnitPrice, SubTotal);

-- Re-enable FK checks
SET FOREIGN_KEY_CHECKS = 1;


-- ============================================================
-- SECTION B: VALIDATION QUERIES
-- ============================================================

-- ── V1: Row counts per table ──────────────────────────────────
SELECT 'Staff'     AS TableName, COUNT(*) AS RowCount FROM Staff
UNION ALL
SELECT 'Category',                COUNT(*)             FROM Category
UNION ALL
SELECT 'Medicines',               COUNT(*)             FROM Medicines
UNION ALL
SELECT 'Suppliers',               COUNT(*)             FROM Suppliers
UNION ALL
SELECT 'Batches',                 COUNT(*)             FROM Batches
UNION ALL
SELECT 'Sales',                   COUNT(*)             FROM Sales
UNION ALL
SELECT 'SaleItems',               COUNT(*)             FROM SaleItems;


-- ── V2: NULL checks on all NOT NULL columns ───────────────────
SELECT 'Staff: NULLs in FullName/Username/Role' AS Check_Name,
       COUNT(*) AS Violations
FROM Staff
WHERE FullName IS NULL OR Username IS NULL OR Role IS NULL

UNION ALL
SELECT 'Medicines: NULLs in BrandName/GenericName/CategoryID',
       COUNT(*)
FROM Medicines
WHERE BrandName IS NULL OR GenericName IS NULL OR CategoryID IS NULL

UNION ALL
SELECT 'Batches: NULLs in ExpiryDate/Prices/Quantities',
       COUNT(*)
FROM Batches
WHERE ExpiryDate IS NULL OR CostPrice IS NULL
   OR SellingPrice IS NULL OR QuantityReceived IS NULL

UNION ALL
SELECT 'Sales: NULLs in SaleDateTime/StaffID/TotalAmount',
       COUNT(*)
FROM Sales
WHERE SaleDateTime IS NULL OR StaffID IS NULL OR TotalAmount IS NULL

UNION ALL
SELECT 'SaleItems: NULLs in SaleID/BatchID/QuantitySold',
       COUNT(*)
FROM SaleItems
WHERE SaleID IS NULL OR BatchID IS NULL OR QuantitySold IS NULL;


-- ── V3: Foreign Key Integrity ─────────────────────────────────
-- Medicines referencing non-existent Category
SELECT 'Medicines → Category orphans' AS FK_Check, COUNT(*) AS Violations
FROM Medicines m
LEFT JOIN Category c ON m.CategoryID = c.CategoryID
WHERE c.CategoryID IS NULL

UNION ALL
-- Batches referencing non-existent Medicine
SELECT 'Batches → Medicines orphans', COUNT(*)
FROM Batches b
LEFT JOIN Medicines m ON b.MedicineID = m.MedicineID
WHERE m.MedicineID IS NULL

UNION ALL
-- Batches referencing non-existent Supplier
SELECT 'Batches → Suppliers orphans', COUNT(*)
FROM Batches b
LEFT JOIN Suppliers s ON b.SupplierID = s.SupplierID
WHERE s.SupplierID IS NULL

UNION ALL
-- Sales referencing non-existent Staff
SELECT 'Sales → Staff orphans', COUNT(*)
FROM Sales sl
LEFT JOIN Staff st ON sl.StaffID = st.StaffID
WHERE st.StaffID IS NULL

UNION ALL
-- SaleItems referencing non-existent Sale
SELECT 'SaleItems → Sales orphans', COUNT(*)
FROM SaleItems si
LEFT JOIN Sales sl ON si.SaleID = sl.SaleID
WHERE sl.SaleID IS NULL

UNION ALL
-- SaleItems referencing non-existent Batch
SELECT 'SaleItems → Batches orphans', COUNT(*)
FROM SaleItems si
LEFT JOIN Batches b ON si.BatchID = b.BatchID
WHERE b.BatchID IS NULL;


-- ── V4: Business-Logic Checks ─────────────────────────────────
-- Batches where QuantityOnHand > QuantityReceived (should be 0)
SELECT 'Batches: OnHand > Received (impossible)' AS BusinessCheck,
       COUNT(*) AS Violations
FROM Batches WHERE QuantityOnHand > QuantityReceived

UNION ALL
-- SaleItems where SubTotal != QuantitySold * UnitPrice
SELECT 'SaleItems: SubTotal mismatch', COUNT(*)
FROM SaleItems
WHERE ABS(SubTotal - (QuantitySold * UnitPrice)) > 0.01

UNION ALL
-- Sales where TotalAmount != SUM of its SaleItems
SELECT 'Sales: TotalAmount mismatch', COUNT(*)
FROM Sales s
WHERE ABS(s.TotalAmount - (
    SELECT COALESCE(SUM(si.SubTotal),0)
    FROM SaleItems si WHERE si.SaleID = s.SaleID
)) > 0.01;


-- ── V5: Expiry Monitoring Queries (business use-case) ─────────
-- Medicines expiring within the next 90 days
SELECT
    m.BrandName,
    b.BatchNumber,
    b.ExpiryDate,
    DATEDIFF(b.ExpiryDate, CURDATE()) AS DaysLeft,
    b.QuantityOnHand
FROM Batches b
JOIN Medicines m ON b.MedicineID = m.MedicineID
WHERE b.ExpiryDate BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 90 DAY)
  AND b.QuantityOnHand > 0
ORDER BY b.ExpiryDate ASC;

-- Already-expired batches still showing stock
SELECT
    m.BrandName,
    b.BatchNumber,
    b.ExpiryDate,
    b.QuantityOnHand AS StrandedStock
FROM Batches b
JOIN Medicines m ON b.MedicineID = m.MedicineID
WHERE b.ExpiryDate < CURDATE()
  AND b.QuantityOnHand > 0
ORDER BY b.ExpiryDate ASC;


-- ── V6: Sales Summary ─────────────────────────────────────────
SELECT
    st.FullName                         AS StaffName,
    COUNT(DISTINCT s.SaleID)            AS TotalSales,
    SUM(s.TotalAmount)                  AS TotalRevenue,
    ROUND(AVG(s.TotalAmount), 2)        AS AvgSaleValue
FROM Sales s
JOIN Staff st ON s.StaffID = st.StaffID
GROUP BY st.StaffID, st.FullName
ORDER BY TotalRevenue DESC;

-- ============================================================
-- END OF MILESTONE 5
-- ============================================================
