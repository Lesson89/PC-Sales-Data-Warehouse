-- Bronze Layer: Raw staging table for PC Sales source data

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'PCSalesSTG')
    CREATE DATABASE PCSalesSTG;
GO

USE PCSalesSTG;
GO

IF OBJECT_ID('dbo.StagingSales', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.StagingSales (
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
        PurchaseDate                 DATE,
        ShipDate                    DATE,
        FinanceAmount                DECIMAL(10,2),
        CreditScore                 INT,
        Channel                    NVARCHAR(20),
        Priority                   NVARCHAR(20),
        CostOfRepairs                DECIMAL(10,2)
    );
END
GO