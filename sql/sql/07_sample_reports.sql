-- Sample reporting queries against the Gold star schema.
-- Each one demonstrates a typical BI question the model supports.

USE PCSalesDW;
GO

-- ============================================================
-- 1) Total revenue and order count by continent
-- Demonstrates: joining Fact to a dimension, basic aggregation.
-- ============================================================
SELECT
    loc.Continent,
    COUNT(*) AS OrderCount,
    SUM(f.SalePrice) AS TotalRevenue,
    AVG(f.SalePrice) AS AvgOrderValue
FROM dbo.FactSales f
JOIN dbo.DimLocation loc ON loc.LocationID = f.LocationID
GROUP BY loc.Continent
ORDER BY TotalRevenue DESC;
GO

-- ============================================================
-- 2) Monthly sales trend
-- Demonstrates: using DimDate's role-played PurchaseDateID to
-- build a time series, without touching FactSales' raw dates.
-- ============================================================
SELECT
    d.Year,
    d.MonthNumber,
    d.MonthName,
    COUNT(*) AS OrderCount,
    SUM(f.SalePrice) AS TotalRevenue
FROM dbo.FactSales f
JOIN dbo.DimDate d ON d.DateID = f.PurchaseDateID
GROUP BY d.Year, d.MonthNumber, d.MonthName
ORDER BY d.Year, d.MonthNumber;
GO

-- ============================================================
-- 3) Top 10 products by revenue
-- Demonstrates: joining to DimProduct, ranking.
-- ============================================================
SELECT TOP 10
    p.PCMake,
    p.PCModel,
    p.StorageCapacity,
    p.RAM,
    COUNT(*) AS UnitsSold,
    SUM(f.SalePrice) AS TotalRevenue
FROM dbo.FactSales f
JOIN dbo.DimProduct p ON p.ProductID = f.ProductID
GROUP BY p.PCMake, p.PCModel, p.StorageCapacity, p.RAM
ORDER BY TotalRevenue DESC;
GO

-- ============================================================
-- 4) Revenue by sales department
-- Demonstrates: joining to DimEmployee.
-- ============================================================
SELECT
    e.SalesPersonDepartment,
    COUNT(*) AS OrderCount,
    SUM(f.SalePrice) AS TotalRevenue
FROM dbo.FactSales f
JOIN dbo.DimEmployee e ON e.EmployeeID = f.EmployeeID
GROUP BY e.SalesPersonDepartment
ORDER BY TotalRevenue DESC;
GO

-- ============================================================
-- 5) Shipped vs unshipped orders
-- Demonstrates: the role-playing DimDate design in action.
-- ShipDateID IS NULL identifies orders that have not shipped yet,
-- a distinction only possible because of the LEFT JOIN used when
-- loading FactSales.
-- ============================================================
SELECT
    CASE WHEN f.ShipDateID IS NULL THEN 'Not Yet Shipped' ELSE 'Shipped' END AS ShipmentStatus,
    COUNT(*) AS OrderCount,
    SUM(f.SalePrice) AS TotalRevenue
FROM dbo.FactSales f
GROUP BY CASE WHEN f.ShipDateID IS NULL THEN 'Not Yet Shipped' ELSE 'Shipped' END;
GO

-- ============================================================
-- 6) Average days from purchase to ship, for shipped orders only
-- Demonstrates: joining DimDate TWICE (the role-playing pattern)
-- to compute a derived metric that spans both date roles.
-- ============================================================
SELECT
    AVG(DATEDIFF(DAY, dd_p.FullDate, dd_s.FullDate)) AS AvgDaysToShip
FROM dbo.FactSales f
JOIN dbo.DimDate dd_p ON dd_p.DateID = f.PurchaseDateID
JOIN dbo.DimDate dd_s ON dd_s.DateID = f.ShipDateID
WHERE f.ShipDateID IS NOT NULL;
GO