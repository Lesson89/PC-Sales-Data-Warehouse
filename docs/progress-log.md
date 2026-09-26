# Progress Log

## 2026-09-24
**Goal:**

Import raw CSV sales data and save it safely into the Bronze staging table, so I can use a copy of it to transform and clean the data at the Silver layer, get it ready for analysis, then load the clean transformed copy into the Gold data warehouse table.

**Methods:**

- Created the GitHub repo for version control and to keep progress saved and structured
- Cloned the repo locally with git, using VS Code for documentation and scripts
- Created two databases (PCSalesSTG and PCSalesDW) to separate staging from the warehouse, per the medallion architecture
- Created the Bronze staging table (StagingSales) to hold the source data as-is, untouched
- Documented the DDL script (01_bronze_staging.sql) in VS Code, made re-runnable with IF NOT EXISTS guards
- Imported the raw CSV data manually via the SSMS Import Flat File wizard
- Verified the row count with SQL queries after loading

**Done:**

**Challenges:**
- Originally planned to extract and load the CSV using SSIS, following the medallion structure end to end
- Hit repeated data type mismatches between the CSV source and the Bronze table — unicode vs non-unicode strings, date parsing failures, and a discovery that some "Ship Date" values contained literal text ("N/A") instead of blank cells, since not every order had shipped yet
- Spent real time debugging these in SSIS (adjusting column types, syncing metadata, tracing exact error rows) and learned a lot about how SSIS handles type conversion
- Decided the debugging cost wasn't worth it for Bronze specifically, since Bronze is meant to be a pure, untransformed passthrough with no real logic — not where SSIS's strengths matter
- Chose to load Bronze manually via the SSMS Import Flat File wizard instead, so I could shape, clean, and transform the data properly at the Silver layer, then use SSIS for the Silver/Gold load where the transformation logic actually justifies it

**Learned:**
- SSIS is sensitive to exact type matches between source and destination — even a column that looks fine can fail if the source parser and the destination column don't agree precisely on type and length
- For raw ingestion, it can be safer to load the data first without a rigid pre-built table structure, rather than defining Bronze's structure upfront and forcing the CSV to conform to it — defining structure too early created avoidable conflicts and wasted time questioning the data before it was even safely saved
- The Import Flat File wizard is a fast, low-friction way to get raw data safely into SQL Server first, before deciding on transformations

**Next:**
- Query and profile the Bronze data — check for blanks, inconsistent text values (like "N/A"), and other anomalies across all columns, not just the ones that already caused errors
- Standardize and clean the data in the Silver layer based on what that profiling finds
- Build the Silver transformation logic, likely back in SSIS, now that the messy-data patterns are better understood
- Eventually load the cleaned Silver data into the Gold star schema


---

## 2026-09-25
**Goal:**

Profile the Bronze data for issues, plan the Silver layer table structure, load the data from Bronze into Silver, clean it, check for unnecessary spaces, trim text, fix the "N/A" Ship Date values, and check for duplicates.

**Done:**

- Ran systematic profiling queries across every Bronze column — checked NULLs, blanks, and literal "N/A" text on all 20 text columns, plus NULL/min/max checks on all 9 numeric columns
- Found only one real issue: ShipDate has 5,071 "N/A" values (orders not yet shipped) — everything else in Bronze is clean
- Designed the Silver table (CleanedSales) with proper DATE types for PurchaseDate/ShipDate, plus a LoadDateTime audit column
- Built and ran the load script (02_silver_clean.sql) — TRUNCATE + INSERT from Bronze, with a CASE statement converting "N/A" Ship Dates into real NULLs
- Verified the load: 10,000 rows, 5,071 NULL ship dates — matches Bronze exactly

**Challenges:**

- CAST(PurchaseDate AS DATE) failed on the whole column, not just a few rows — turned out every date value had a stray trailing period (e.g. "2021-03-12 00:00:00.") that SQL Server's date parser rejected
- Used TRY_CAST instead of CAST to find the exact failing values without crashing the query — a much faster way to isolate the problem than guessing
- Fixed it with CAST(LEFT(PurchaseDate, 19) AS DATE) — trims to just the clean YYYY-MM-DD HH:MI:SS portion before converting, discarding the broken trailing character
- Applied the same fix to both PurchaseDate and ShipDate

**Learned:**

- TRY_CAST is a much better diagnostic tool than CAST when you don't yet know which values are bad — it returns NULL instead of halting the whole query
- Profiling every column systematically (not just the ones that already caused errors) is worth doing before building the next layer — it turned up nothing new here, which itself was useful confirmation
- A single formatting quirk (one stray character) can break conversion for 100% of rows, not just a handful — worth checking the full distinct value list, not just a sample

**Next:**

- Check CleanedSales for duplicate rows (not yet done this session)
- Trim leading/trailing whitespace on text columns as part of the Silver load (profiling checked for it but the load script doesn't explicitly trim yet)
- Design and build the Gold star schema (FactSales + 5 dimensions) from the cleaned Silver data
- Eventually revisit SSIS for the Silver → Gold load, now that the messy-data patterns are better understood