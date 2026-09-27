-- Gold Layer: Star schema (FactSales + 5 dimensions) for reporting

IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'PCSalesDW')
    CREATE DATABASE PCSalesDW;
GO

USE PCSalesDW;
GO

-- ============================================================
-- DIM: Location
-- ============================================================
IF OBJECT_ID('dbo.DimLocation', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimLocation (
        LocationID      INT IDENTITY(1,1) PRIMARY KEY,
        Continent       NVARCHAR(50)  NOT NULL,
        CountryOrState  NVARCHAR(100) NOT NULL,
        ProvinceOrCity  NVARCHAR(100) NOT NULL,
        ShopName        NVARCHAR(150) NOT NULL,
        ShopAge         INT           NULL,
        CONSTRAINT UQ_DimLocation_NaturalKey
            UNIQUE (Continent, CountryOrState, ProvinceOrCity, ShopName)
    );
END
GO

-- ============================================================
-- DIM: Customer
-- ============================================================
IF OBJECT_ID('dbo.DimCustomer', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimCustomer (
        CustomerID              INT IDENTITY(1,1) PRIMARY KEY,
        CustomerName            NVARCHAR(100) NOT NULL,
        CustomerSurname         NVARCHAR(100) NOT NULL,
        CustomerContactNumber   NVARCHAR(50)  NOT NULL,
        CustomerEmailAddress    NVARCHAR(200) NULL,
        CONSTRAINT UQ_DimCustomer_NaturalKey
            UNIQUE (CustomerContactNumber)
    );
END
GO

-- ============================================================
-- DIM: Product
-- ============================================================
IF OBJECT_ID('dbo.DimProduct', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimProduct (
        ProductID       INT IDENTITY(1,1) PRIMARY KEY,
        PCMake          NVARCHAR(50)  NOT NULL,
        PCModel         NVARCHAR(100) NOT NULL,
        StorageType     NVARCHAR(20)  NOT NULL,
        StorageCapacity NVARCHAR(20)  NOT NULL,
        RAM             NVARCHAR(20)  NOT NULL,
        PCMarketPrice   DECIMAL(10,2) NULL,
        CONSTRAINT UQ_DimProduct_NaturalKey
            UNIQUE (PCMake, PCModel, StorageType, StorageCapacity, RAM)
    );
END
GO

-- ============================================================
-- DIM: Employee
-- ============================================================
IF OBJECT_ID('dbo.DimEmployee', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimEmployee (
        EmployeeID              INT IDENTITY(1,1) PRIMARY KEY,
        SalesPersonName          NVARCHAR(100) NOT NULL,
        SalesPersonDepartment    NVARCHAR(100) NOT NULL,
        TotalSalesPerEmployee    INT           NULL,
        CONSTRAINT UQ_DimEmployee_NaturalKey
            UNIQUE (SalesPersonName, SalesPersonDepartment)
    );
END
GO

-- ============================================================
-- DIM: Date
-- Smart key (YYYYMMDD as INT). Populated separately with a full
-- calendar range, not derived row-by-row from Silver.
-- ============================================================
IF OBJECT_ID('dbo.DimDate', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimDate (
        DateID      INT PRIMARY KEY,       -- e.g. 20230717
        FullDate    DATE NOT NULL,
        DayOfMonth  TINYINT NOT NULL,
        MonthNumber TINYINT NOT NULL,
        MonthName   NVARCHAR(20) NOT NULL,
        Quarter     TINYINT NOT NULL,
        Year        SMALLINT NOT NULL,
        WeekdayName NVARCHAR(20) NOT NULL
    );
END
GO

-- ============================================================
-- FACT: Sales
-- Grain = one row per sale. PurchaseDateID/ShipDateID both
-- reference DimDate — a role-playing dimension (one physical
-- table, two FK roles).
-- ============================================================
IF OBJECT_ID('dbo.FactSales', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactSales (
        SaleID            INT IDENTITY(1,1) PRIMARY KEY,
        LocationID         INT NOT NULL,
        CustomerID         INT NOT NULL,
        ProductID          INT NOT NULL,
        EmployeeID         INT NOT NULL,
        PurchaseDateID      INT NOT NULL,
        ShipDateID          INT NULL,          -- nullable: not every sale has shipped
        CostPrice          DECIMAL(10,2) NOT NULL,
        SalePrice          DECIMAL(10,2) NOT NULL,
        PaymentMethod      NVARCHAR(30)  NOT NULL,
        DiscountAmount     DECIMAL(10,2) NOT NULL DEFAULT 0,
        FinanceAmount      DECIMAL(10,2) NOT NULL DEFAULT 0,
        Channel            NVARCHAR(20)  NOT NULL,
        Priority           NVARCHAR(20)  NOT NULL,
        CostOfRepairs      DECIMAL(10,2) NOT NULL DEFAULT 0,
        CreditScore        INT NULL,

        CONSTRAINT FK_FactSales_Location  FOREIGN KEY (LocationID)     REFERENCES dbo.DimLocation(LocationID),
        CONSTRAINT FK_FactSales_Customer  FOREIGN KEY (CustomerID)     REFERENCES dbo.DimCustomer(CustomerID),
        CONSTRAINT FK_FactSales_Product   FOREIGN KEY (ProductID)      REFERENCES dbo.DimProduct(ProductID),
        CONSTRAINT FK_FactSales_Employee  FOREIGN KEY (EmployeeID)     REFERENCES dbo.DimEmployee(EmployeeID),
        CONSTRAINT FK_FactSales_PurchDate FOREIGN KEY (PurchaseDateID) REFERENCES dbo.DimDate(DateID),
        CONSTRAINT FK_FactSales_ShipDate  FOREIGN KEY (ShipDateID)     REFERENCES dbo.DimDate(DateID)
    );
END
GO

PRINT 'Gold star schema created: DimLocation, DimCustomer, DimProduct, DimEmployee, DimDate, FactSales';
GO