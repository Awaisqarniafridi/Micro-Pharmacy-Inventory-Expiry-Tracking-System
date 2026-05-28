-- ============================================================
-- PharmaKeep — Milestone 4: DDL (Data Definition Language)
-- Author   : Awais Qarni | BSSE | Group B
-- Date     : 17 May 2026
-- Tool     : MySQL 8.x / MySQL Workbench
-- ============================================================

DROP DATABASE IF EXISTS pharmaKeep;
CREATE DATABASE pharmaKeep
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE pharmaKeep;

-- ─────────────────────────────────────────────────────────────
-- 1. Staff
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Staff (
    StaffID      INT           NOT NULL AUTO_INCREMENT,
    FullName     VARCHAR(100)  NOT NULL,
    Username     VARCHAR(50)   NOT NULL,
    PasswordHash VARCHAR(255)  NOT NULL,
    Role         ENUM('Admin','Pharmacist') NOT NULL,

    CONSTRAINT pk_Staff      PRIMARY KEY (StaffID),
    CONSTRAINT uq_Staff_User UNIQUE      (Username)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 2. Category
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Category (
    CategoryID   INT           NOT NULL AUTO_INCREMENT,
    CategoryName VARCHAR(100)  NOT NULL,

    CONSTRAINT pk_Category      PRIMARY KEY (CategoryID),
    CONSTRAINT uq_CategoryName  UNIQUE      (CategoryName)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 3. Medicines
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Medicines (
    MedicineID  INT           NOT NULL AUTO_INCREMENT,
    BrandName   VARCHAR(150)  NOT NULL,
    GenericName VARCHAR(150)  NOT NULL,
    CategoryID  INT           NOT NULL,
    Description TEXT,

    CONSTRAINT pk_Medicines         PRIMARY KEY (MedicineID),
    CONSTRAINT fk_Medicines_Cat     FOREIGN KEY (CategoryID)
        REFERENCES Category(CategoryID)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 4. Suppliers
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Suppliers (
    SupplierID    INT           NOT NULL AUTO_INCREMENT,
    SupplierName  VARCHAR(150)  NOT NULL,
    ContactPerson VARCHAR(100),
    PhoneNumber   VARCHAR(20)   NOT NULL,
    Email         VARCHAR(100),

    CONSTRAINT pk_Suppliers         PRIMARY KEY (SupplierID),
    CONSTRAINT uq_SupplierName      UNIQUE      (SupplierName)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 5. Batches  (core inventory table)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Batches (
    BatchID          INT              NOT NULL AUTO_INCREMENT,
    BatchNumber      VARCHAR(50)      NOT NULL,
    MedicineID       INT              NOT NULL,
    SupplierID       INT              NOT NULL,
    ExpiryDate       DATE             NOT NULL,
    QuantityReceived INT              NOT NULL,
    QuantityOnHand   INT              NOT NULL,
    CostPrice        DECIMAL(10,2)    NOT NULL,
    SellingPrice     DECIMAL(10,2)    NOT NULL,

    CONSTRAINT pk_Batches            PRIMARY KEY (BatchID),
    CONSTRAINT uq_BatchNumMed        UNIQUE      (BatchNumber, MedicineID),
    CONSTRAINT fk_Batches_Med        FOREIGN KEY (MedicineID)
        REFERENCES Medicines(MedicineID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_Batches_Sup        FOREIGN KEY (SupplierID)
        REFERENCES Suppliers(SupplierID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_QtyRcvd          CHECK (QuantityReceived > 0),
    CONSTRAINT chk_QtyOnHand        CHECK (QuantityOnHand  >= 0),
    CONSTRAINT chk_QtyLogical       CHECK (QuantityOnHand  <= QuantityReceived),
    CONSTRAINT chk_CostPos          CHECK (CostPrice        > 0),
    CONSTRAINT chk_SellPos          CHECK (SellingPrice     > 0)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 6. Sales
-- ─────────────────────────────────────────────────────────────
CREATE TABLE Sales (
    SaleID          INT              NOT NULL AUTO_INCREMENT,
    SaleDateTime    DATETIME         NOT NULL DEFAULT CURRENT_TIMESTAMP,
    StaffID         INT              NOT NULL,
    TotalAmount     DECIMAL(10,2)    NOT NULL,
    PaymentMethod   ENUM('Cash','Card') NOT NULL DEFAULT 'Cash',

    CONSTRAINT pk_Sales              PRIMARY KEY (SaleID),
    CONSTRAINT fk_Sales_Staff        FOREIGN KEY (StaffID)
        REFERENCES Staff(StaffID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_TotalAmt         CHECK (TotalAmount >= 0)
) ENGINE=InnoDB;

-- ─────────────────────────────────────────────────────────────
-- 7. SaleItems  (bridge / line-item table)
-- ─────────────────────────────────────────────────────────────
CREATE TABLE SaleItems (
    SaleItemID   INT              NOT NULL AUTO_INCREMENT,
    SaleID       INT              NOT NULL,
    BatchID      INT              NOT NULL,
    QuantitySold INT              NOT NULL,
    UnitPrice    DECIMAL(10,2)    NOT NULL,
    SubTotal     DECIMAL(10,2)    NOT NULL,

    CONSTRAINT pk_SaleItems          PRIMARY KEY (SaleItemID),
    CONSTRAINT fk_SaleItems_Sale     FOREIGN KEY (SaleID)
        REFERENCES Sales(SaleID)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_SaleItems_Batch    FOREIGN KEY (BatchID)
        REFERENCES Batches(BatchID)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_QtySold          CHECK (QuantitySold > 0),
    CONSTRAINT chk_UnitPrice        CHECK (UnitPrice     > 0),
    CONSTRAINT chk_SubTotal         CHECK (SubTotal      > 0)
) ENGINE=InnoDB;

-- ============================================================
-- Indexes for common query patterns
-- ============================================================
CREATE INDEX idx_Batches_Expiry  ON Batches  (ExpiryDate);
CREATE INDEX idx_Batches_Med     ON Batches  (MedicineID);
CREATE INDEX idx_SaleItems_Sale  ON SaleItems(SaleID);
CREATE INDEX idx_Sales_DateTime  ON Sales    (SaleDateTime);
CREATE INDEX idx_Sales_Staff     ON Sales    (StaffID);

-- ============================================================
-- END OF DDL
-- ============================================================
