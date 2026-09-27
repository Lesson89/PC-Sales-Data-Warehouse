-- Validation checks: confirm row counts and key data quality
-- rules hold across the full Bronze -> Silver -> Gold pipeline.
-- Safe to re-run any time after a reload.

USE PCSalesSTG;
GO

-- Bronze: raw row count
SELECT 'Bronze - StagingSales' AS CheckName, COUNT(*) AS TotalRows
FROM dbo.StagingSales;
GO

-- Silver: row count + null ship dates
SELECT 'Silver - CleanedSales' AS CheckName,
       COUNT(*) AS TotalRows,
       SUM(CASE WHEN ShipDate IS NULL THEN 1 ELSE 0 END) AS NullShipDates
FROM dbo.CleanedSales;
GO

USE PCSalesDW;
GO

-- Gold: dimension row counts
SELECT 'DimLocation' AS TableName, COUNT(*) AS TotalRows FROM dbo.DimLocation
UNION ALL SELECT 'DimCustomer', COUNT(*) FROM dbo.DimCustomer
UNION ALL SELECT 'DimProduct', COUNT(*) FROM dbo.DimProduct
UNION ALL SELECT 'DimEmployee', COUNT(*) FROM dbo.DimEmployee
UNION ALL SELECT 'DimDate', COUNT(*) FROM dbo.DimDate;
GO

-- Gold: fact row count + null ship date FKs
SELECT 'FactSales' AS CheckName,
       COUNT(*) AS TotalRows,
       SUM(CASE WHEN ShipDateID IS NULL THEN 1 ELSE 0 END) AS NullShipDateID
FROM dbo.FactSales;
GO