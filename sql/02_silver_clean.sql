-- Silver Layer: Cleaned, typed version of the Bronze staging data

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'PCSalesSTG')
    CREATE DATABASE PCSalesSTG;
GO

USE PCSalesSTG;
GO

IF OBJECT_ID('dbo.CleanedSales', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.CleanedSales (
        -- Location
        Continent               NVARCHAR(50),
        CountryOrState          NVARCHAR(100),
        ProvinceOrCity          NVARCHAR(100),
        ShopName                NVARCHAR(150),
        ShopAge                 INT,

        -- Product
        PCMake                  NVARCHAR(50),
        PCModel                 NVARCHAR(100),
        StorageType              NVARCHAR(20),
        StorageCapacity          NVARCHAR(20),
        RAM                     NVARCHAR(20),
        PCMarketPrice             DECIMAL(10,2),

        -- Customer
        CustomerName              NVARCHAR(100),
        CustomerSurname            NVARCHAR(100),
        CustomerContactNumber       NVARCHAR(50),
        CustomerEmailAddress        NVARCHAR(200),

        -- Employee
        SalesPersonName             NVARCHAR(100),
        SalesPersonDepartment        NVARCHAR(100),
        TotalSalesPerEmployee         INT,

        -- Transaction
        CostPrice                  DECIMAL(10,2),
        SalePrice                  DECIMAL(10,2),
        PaymentMethod               NVARCHAR(30),
        DiscountAmount               DECIMAL(10,2),
        PurchaseDate                 DATE,           -- cleaned to real DATE (Bronze had this as NVARCHAR)
        ShipDate                    DATE NULL,       -- cleaned to real DATE, NULL = not yet shipped (was "N/A" text in Bronze)
        FinanceAmount                DECIMAL(10,2),
        CreditScore                 INT,
        Channel                    NVARCHAR(20),
        Priority                   NVARCHAR(20),
        CostOfRepairs                DECIMAL(10,2),

        -- Audit
        LoadDateTime                DATETIME NOT NULL DEFAULT GETDATE()
    );
END
GO

PRINT 'Silver table created: CleanedSales';
GO

-- ============================================================
-- Load Silver from Bronze, applying cleaning rules
-- ============================================================
TRUNCATE TABLE dbo.CleanedSales;
GO

INSERT INTO dbo.CleanedSales (
    Continent, CountryOrState, ProvinceOrCity, ShopName, ShopAge,
    PCMake, PCModel, StorageType, StorageCapacity, RAM, PCMarketPrice,
    CustomerName, CustomerSurname, CustomerContactNumber, CustomerEmailAddress,
    SalesPersonName, SalesPersonDepartment, TotalSalesPerEmployee,
    CostPrice, SalePrice, PaymentMethod, DiscountAmount,
    PurchaseDate, ShipDate, FinanceAmount, CreditScore,
    Channel, Priority, CostOfRepairs
    
)SELECT
    Continent, CountryOrState, ProvinceOrCity, ShopName, ShopAge,
    PCMake, PCModel, StorageType, StorageCapacity, RAM, PCMarketPrice,
    CustomerName, CustomerSurname, CustomerContactNumber, CustomerEmailAddress,
    SalesPersonName, SalesPersonDepartment, TotalSalesPerEmployee,
    CostPrice, SalePrice, PaymentMethod, DiscountAmount,
    CAST(LEFT(PurchaseDate, 19) AS DATE),
    CASE
        WHEN LTRIM(RTRIM(ShipDate)) = 'N/A' OR LTRIM(RTRIM(ShipDate)) = ''
            THEN NULL
        ELSE CAST(LEFT(ShipDate, 19) AS DATE)
    END,
    FinanceAmount, CreditScore,
    Channel, Priority, CostOfRepairs
FROM dbo.StagingSales;
GO