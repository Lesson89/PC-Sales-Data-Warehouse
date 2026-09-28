-- Gold Layer: reload-safe stored procedures for SSIS orchestration.
-- Order matters: clear fact first (it holds the FKs), then dimensions.

USE PCSalesDW;
GO

-- ============================================================
-- 1) Clear Gold (fact first, then dimensions, because of FKs)
-- DELETE instead of TRUNCATE: tables referenced by FKs can't be
-- truncated. RESEED restarts the surrogate keys at 1 each reload.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_ClearGold
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DELETE FROM dbo.FactSales;
    DELETE FROM dbo.DimLocation;
    DELETE FROM dbo.DimCustomer;
    DELETE FROM dbo.DimProduct;
    DELETE FROM dbo.DimEmployee;
    DELETE FROM dbo.DimDate;

    DBCC CHECKIDENT ('dbo.FactSales',   RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.DimLocation', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.DimCustomer', RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.DimProduct',  RESEED, 0) WITH NO_INFOMSGS;
    DBCC CHECKIDENT ('dbo.DimEmployee', RESEED, 0) WITH NO_INFOMSGS;
END
GO

-- ============================================================
-- 2) Load all five dimensions from Silver
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_LoadDimensions
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- DimDate: full calendar range spanning Purchase and Ship dates
    DECLARE @StartDate DATE, @EndDate DATE;

    SELECT @StartDate = MIN(d), @EndDate = MAX(d)
    FROM (
        SELECT PurchaseDate AS d FROM PCSalesSTG.dbo.CleanedSales
        UNION
        SELECT ShipDate FROM PCSalesSTG.dbo.CleanedSales WHERE ShipDate IS NOT NULL
    ) AllDates;

    ;WITH DateSequence AS (
        SELECT @StartDate AS TheDate
        UNION ALL
        SELECT DATEADD(DAY, 1, TheDate) FROM DateSequence WHERE TheDate < @EndDate
    )
    INSERT INTO dbo.DimDate (DateID, FullDate, DayOfMonth, MonthNumber, MonthName, Quarter, Year, WeekdayName)
    SELECT
        CONVERT(INT, CONVERT(CHAR(8), TheDate, 112)),
        TheDate,
        DAY(TheDate),
        MONTH(TheDate),
        DATENAME(MONTH, TheDate),
        DATEPART(QUARTER, TheDate),
        YEAR(TheDate),
        DATENAME(WEEKDAY, TheDate)
    FROM DateSequence
    OPTION (MAXRECURSION 0);

    -- DimLocation (ShopAge is noisy, reduced with MIN)
    INSERT INTO dbo.DimLocation (Continent, CountryOrState, ProvinceOrCity, ShopName, ShopAge)
    SELECT Continent, CountryOrState, ProvinceOrCity, ShopName, MIN(ShopAge)
    FROM PCSalesSTG.dbo.CleanedSales
    GROUP BY Continent, CountryOrState, ProvinceOrCity, ShopName;

    -- DimCustomer
    INSERT INTO dbo.DimCustomer (CustomerName, CustomerSurname, CustomerContactNumber, CustomerEmailAddress)
    SELECT DISTINCT CustomerName, CustomerSurname, CustomerContactNumber, CustomerEmailAddress
    FROM PCSalesSTG.dbo.CleanedSales;

    -- DimProduct (PCMarketPrice is noisy, reduced with MIN)
    INSERT INTO dbo.DimProduct (PCMake, PCModel, StorageType, StorageCapacity, RAM, PCMarketPrice)
    SELECT PCMake, PCModel, StorageType, StorageCapacity, RAM, MIN(PCMarketPrice)
    FROM PCSalesSTG.dbo.CleanedSales
    GROUP BY PCMake, PCModel, StorageType, StorageCapacity, RAM;

    -- DimEmployee (TotalSalesPerEmployee is noisy, reduced with MIN)
    INSERT INTO dbo.DimEmployee (SalesPersonName, SalesPersonDepartment, TotalSalesPerEmployee)
    SELECT SalesPersonName, SalesPersonDepartment, MIN(TotalSalesPerEmployee)
    FROM PCSalesSTG.dbo.CleanedSales
    GROUP BY SalesPersonName, SalesPersonDepartment;
END
GO

-- ============================================================
-- 3) Load FactSales (LEFT JOIN on ship date keeps unshipped orders)
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.usp_LoadFactSales
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    INSERT INTO dbo.FactSales (
        LocationID, CustomerID, ProductID, EmployeeID,
        PurchaseDateID, ShipDateID,
        CostPrice, SalePrice, PaymentMethod, DiscountAmount,
        FinanceAmount, Channel, Priority, CostOfRepairs, CreditScore
    )
    SELECT
        loc.LocationID, cust.CustomerID, prod.ProductID, emp.EmployeeID,
        dd_p.DateID, dd_s.DateID,
        s.CostPrice, s.SalePrice, s.PaymentMethod, s.DiscountAmount,
        s.FinanceAmount, s.Channel, s.Priority, s.CostOfRepairs, s.CreditScore
    FROM PCSalesSTG.dbo.CleanedSales s
    JOIN dbo.DimLocation loc
        ON loc.Continent = s.Continent
       AND loc.CountryOrState = s.CountryOrState
       AND loc.ProvinceOrCity = s.ProvinceOrCity
       AND loc.ShopName = s.ShopName
    JOIN dbo.DimCustomer cust
        ON cust.CustomerContactNumber = s.CustomerContactNumber
    JOIN dbo.DimProduct prod
        ON prod.PCMake = s.PCMake
       AND prod.PCModel = s.PCModel
       AND prod.StorageType = s.StorageType
       AND prod.StorageCapacity = s.StorageCapacity
       AND prod.RAM = s.RAM
    JOIN dbo.DimEmployee emp
        ON emp.SalesPersonName = s.SalesPersonName
       AND emp.SalesPersonDepartment = s.SalesPersonDepartment
    JOIN dbo.DimDate dd_p
        ON dd_p.DateID = CONVERT(INT, CONVERT(CHAR(8), s.PurchaseDate, 112))
    LEFT JOIN dbo.DimDate dd_s
        ON dd_s.DateID = CONVERT(INT, CONVERT(CHAR(8), s.ShipDate, 112));
END
GO

PRINT 'Gold load procedures created.';
GO