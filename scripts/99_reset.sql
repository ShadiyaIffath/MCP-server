-- Drops every Customers.* table so the scenario can be re-run from scratch.
-- Follow up with:
--   python scripts/apply_pull_edits.py --revert
--   sqlcmd ... -i scripts/00_setup_dev.sql
--
-- Run with:
--   sqlcmd -S "127.0.0.1" -U sa -P "flywayPWD000" -d dev -i scripts/99_reset.sql

USE dev;
GO

DECLARE @sql NVARCHAR(MAX) = N'';
SELECT @sql = @sql + N'ALTER TABLE ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name)
                   + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
FROM sys.foreign_keys fk
JOIN sys.tables  t ON fk.parent_object_id = t.object_id
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'Customers';
EXEC sp_executesql @sql;

SET @sql = N'';
SELECT @sql = @sql + N'DROP TABLE ' + QUOTENAME(s.name) + N'.' + QUOTENAME(t.name) + N';'
FROM sys.tables t
JOIN sys.schemas s ON t.schema_id = s.schema_id
WHERE s.name = 'Customers';
EXEC sp_executesql @sql;
GO
