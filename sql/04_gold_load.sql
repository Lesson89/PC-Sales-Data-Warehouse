-- Gold Layer: Load DimDate, then dimensions, then FactSales, from Silver (CleanedSales)

USE PCSalesDW;
GO

-- ============================================================
-- Populate DimDate: generate every calendar date spanning the
-- full range found in Silver's PurchaseDate/ShipDate, so every
-- fact row will have a matching date.
-- ============================================================
DECLARE @StartDate DATE, @EndDate DATE;

SELECT
    @StartDate = MIN(d),
    @EndDate   = MAX(d)
FROM (
    SELECT PurchaseDate AS d FROM PCSalesSTG.dbo.CleanedSales
    UNION
    SELECT ShipDate FROM PCSalesSTG.dbo.CleanedSales WHERE ShipDate IS NOT NULL
) AllDates;

;WITH DateSequence AS (
    SELECT @StartDate AS TheDate
    UNION ALL
    SELECT DATEADD(DAY, 1, TheDate)
    FROM DateSequence
    WHERE TheDate < @EndDate
)
INSERT INTO dbo.DimDate (DateID, FullDate, DayOfMonth, MonthNumber, MonthName, Quarter, Year, WeekdayName)
SELECT
    CONVERT(INT, CONVERT(CHAR(8), TheDate, 112)) AS DateID,
    TheDate,
    DAY(TheDate),
    MONTH(TheDate),
    DATENAME(MONTH, TheDate),
    DATEPART(QUARTER, TheDate),
    YEAR(TheDate),
    DATENAME(WEEKDAY, TheDate)
FROM DateSequence
WHERE NOT EXISTS (
    SELECT 1 FROM dbo.DimDate d
    WHERE d.DateID = CONVERT(INT, CONVERT(CHAR(8), DateSequence.TheDate, 112))
)
OPTION (MAXRECURSION 0);
GO

PRINT 'DimDate populated.';
GO

-- ============================================================
-- DimLocation
-- ShopAge is noisy per shop (many different values recorded for
-- the same shop), so it's grouped and reduced with MIN() to keep
-- one row per true natural key instead of one row per ShopAge.
-- ============================================================
MERGE dbo.DimLocation AS tgt
USING (
    SELECT Continent, CountryOrState, ProvinceOrCity, ShopName, MIN(ShopAge) AS ShopAge
    FROM PCSalesSTG.dbo.CleanedSales
    GROUP BY Continent, CountryOrState, ProvinceOrCity, ShopName
) AS src
ON  tgt.Continent = src.Continent
AND tgt.CountryOrState = src.CountryOrState
AND tgt.ProvinceOrCity = src.ProvinceOrCity
AND tgt.ShopName = src.ShopName
WHEN NOT MATCHED THEN
    INSERT (Continent, CountryOrState, ProvinceOrCity, ShopName, ShopAge)
    VALUES (src.Continent, src.CountryOrState, src.ProvinceOrCity, src.ShopName, src.ShopAge);
GO

-- ============================================================
-- DimCustomer
-- ============================================================
MERGE dbo.DimCustomer AS tgt
USING (
    SELECT DISTINCT CustomerName, CustomerSurname, CustomerContactNumber, CustomerEmailAddress
    FROM PCSalesSTG.dbo.CleanedSales
) AS src
ON tgt.CustomerContactNumber = src.CustomerContactNumber
WHEN NOT MATCHED THEN
    INSERT (CustomerName, CustomerSurname, CustomerContactNumber, CustomerEmailAddress)
    VALUES (src.CustomerName, src.CustomerSurname, src.CustomerContactNumber, src.CustomerEmailAddress);
GO

-- ============================================================
-- DimProduct
-- Same noisy-attribute issue as DimLocation, on PCMarketPrice.
-- ============================================================
MERGE dbo.DimProduct AS tgt
USING (
    SELECT PCMake, PCModel, StorageType, StorageCapacity, RAM, MIN(PCMarketPrice) AS PCMarketPrice
    FROM PCSalesSTG.dbo.CleanedSales
    GROUP BY PCMake, PCModel, StorageType, StorageCapacity, RAM
) AS src
ON  tgt.PCMake = src.PCMake
AND tgt.PCModel = src.PCModel
AND tgt.StorageType = src.StorageType
AND tgt.StorageCapacity = src.StorageCapacity
AND tgt.RAM = src.RAM
WHEN NOT MATCHED THEN
    INSERT (PCMake, PCModel, StorageType, StorageCapacity, RAM, PCMarketPrice)
    VALUES (src.PCMake, src.PCModel, src.StorageType, src.StorageCapacity, src.RAM, src.PCMarketPrice);
GO

-- ============================================================
-- DimEmployee
-- Same noisy-attribute issue, on TotalSalesPerEmployee.
-- ============================================================
MERGE dbo.DimEmployee AS tgt
USING (
    SELECT SalesPersonName, SalesPersonDepartment, MIN(TotalSalesPerEmployee) AS TotalSalesPerEmployee
    FROM PCSalesSTG.dbo.CleanedSales
    GROUP BY SalesPersonName, SalesPersonDepartment
) AS src
ON  tgt.SalesPersonName = src.SalesPersonName
AND tgt.SalesPersonDepartment = src.SalesPersonDepartment
WHEN NOT MATCHED THEN
    INSERT (SalesPersonName, SalesPersonDepartment, TotalSalesPerEmployee)
    VALUES (src.SalesPersonName, src.SalesPersonDepartment, src.TotalSalesPerEmployee);
GO

PRINT 'Dimensions loaded.';
GO

-- ============================================================
-- Summary check
-- ============================================================
SELECT 'DimLocation' AS TableName, COUNT(*) AS TotalRows FROM dbo.DimLocation
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM dbo.DimCustomer
UNION ALL SELECT 'DimProduct', COUNT(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimEmployee', COUNT(*) FROM dbo.DimEmployee
UNION ALL SELECT 'DimDate', COUNT(*) FROM dbo.DimDate;

-- ============================================================
-- FactSales
-- Join Silver back to every dimension on its natural key to
-- resolve the surrogate FK. DimDate is joined TWICE (aliased
-- dd_p / dd_s) for the two role-playing date references.
-- ============================================================
INSERT INTO dbo.FactSales (
    LocationID, CustomerID, ProductID, EmployeeID,
    PurchaseDateID, ShipDateID,
    CostPrice, SalePrice, PaymentMethod, DiscountAmount,
    FinanceAmount, Channel, Priority, CostOfRepairs, CreditScore
)
SELECT
    loc.LocationID,
    cust.CustomerID,
    prod.ProductID,
    emp.EmployeeID,
    dd_p.DateID AS PurchaseDateID,
    dd_s.DateID AS ShipDateID,
    s.CostPrice,
    s.SalePrice,
    s.PaymentMethod,
    s.DiscountAmount,
    s.FinanceAmount,
    s.Channel,
    s.Priority,
    s.CostOfRepairs,
    s.CreditScore
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
GO

PRINT 'FactSales loaded.';
GO

SELECT 'FactSales' AS TableName, COUNT(*) AS TotalRows FROM dbo.FactSales;
GO