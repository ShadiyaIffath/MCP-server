-- Rebuilds the `dev` database to match the pre-pull schema-model,
-- then applies the local drift that the 3-sided diff scenario relies on.
--
-- Constraint names MUST match schema-model/Tables/*.sql exactly, otherwise
-- the diff will surface spurious constraint-rename differences.
--
-- WARNING: this drops every table in the Customers schema.
-- Run with:
--   sqlcmd -S "127.0.0.1" -U sa -P "flywayPWD000" -d dev -i scripts/00_setup_dev.sql

USE dev;
GO

IF SCHEMA_ID('Customers') IS NULL EXEC('CREATE SCHEMA Customers');
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

-- Baseline: mirrors schema-model/Tables/Customers.*.sql byte-for-byte on
-- column types AND constraint names.
CREATE TABLE [Customers].[Customer]
(
[CustomerID] [int] NOT NULL IDENTITY(1, 1),
[Name] [nvarchar] (50) NOT NULL,
[Email] [nvarchar] (100) NOT NULL,
[DateOfBirth] [date] NULL,
[Phone] [nvarchar] (20) NULL,
[Address] [nvarchar] (200) NULL
);
GO
ALTER TABLE [Customers].[Customer] ADD CONSTRAINT [PK__Customer__A4AE64B8B3B6EF77] PRIMARY KEY CLUSTERED ([CustomerID]);
GO
ALTER TABLE [Customers].[Customer] ADD CONSTRAINT [UQ__Customer__A9D10534666A42F2] UNIQUE NONCLUSTERED ([Email]);
GO

CREATE TABLE [Customers].[Address]
(
[AddressID] [int] NOT NULL IDENTITY(1, 1),
[CustomerID] [int] NOT NULL,
[Street] [nvarchar] (100) NOT NULL,
[City] [nvarchar] (50) NOT NULL,
[State] [nvarchar] (50) NOT NULL,
[PostalCode] [nvarchar] (20) NOT NULL,
[Country] [nvarchar] (50) NOT NULL,
[Phone] [nvarchar] (20) NULL,
[Address] [nvarchar] (200) NULL
);
GO
ALTER TABLE [Customers].[Address] ADD CONSTRAINT [PK__Address__A4AE64B8B3B6EF77] PRIMARY KEY CLUSTERED ([AddressID]);
GO
ALTER TABLE [Customers].[Address] ADD CONSTRAINT [FK__Address__CustomerID__A9D10534] FOREIGN KEY ([CustomerID]) REFERENCES [Customers].[Customer]([CustomerID]);
GO

CREATE TABLE [Customers].[CustomerFeedback]
(
[FeedbackID] [int] NOT NULL IDENTITY(1, 1),
[CustomerID] [int] NULL,
[FeedbackDate] [datetime] NULL CONSTRAINT [DF__CustomerF__Feedb__3E52440B] DEFAULT (getdate()),
[Rating] [int] NULL,
[Comments] [nvarchar] (500) NULL
);
GO
ALTER TABLE [Customers].[CustomerFeedback] ADD CONSTRAINT [CK__CustomerF__Ratin__3F466844] CHECK (([Rating]>=(1) AND [Rating]<=(5)));
GO
ALTER TABLE [Customers].[CustomerFeedback] ADD CONSTRAINT [PK__Customer__6A4BEDF6FBDF0B79] PRIMARY KEY CLUSTERED ([FeedbackID]);
GO
ALTER TABLE [Customers].[CustomerFeedback] ADD CONSTRAINT [FK__CustomerF__Custo__3D5E1FD2] FOREIGN KEY ([CustomerID]) REFERENCES [Customers].[Customer] ([CustomerID]);
GO

-- Newsletter is intentionally FK-free so it can be deployed in isolation
-- without Flyway pulling related tables in as dependencies. This is the
-- object the 5a "EXISTING-only" scope test targets.
CREATE TABLE [Customers].[Newsletter]
(
[NewsletterID] [int] NOT NULL IDENTITY(1, 1),
[Title] [nvarchar] (100) NOT NULL,
[Body] [nvarchar] (max) NULL,
[SentDate] [datetime] NULL
);
GO
ALTER TABLE [Customers].[Newsletter] ADD CONSTRAINT [PK__Newslett__AF3A0FB1] PRIMARY KEY CLUSTERED ([NewsletterID]);
GO

-- OldFeature exists in the pre-pull baseline (schema-model + dev). The pull
-- removes it from schema-model. It's the decisive object for 5d wildcard:
-- if wildcard applies the whole after-pull leg, OldFeature is dropped from dev;
-- if wildcard applies "additions only", OldFeature is left alone.
CREATE TABLE [Customers].[OldFeature]
(
[OldFeatureID] [int] NOT NULL IDENTITY(1, 1),
[Description] [nvarchar] (200) NULL
);
GO
ALTER TABLE [Customers].[OldFeature] ADD CONSTRAINT [PK__OldFeat__BEEF1234] PRIMARY KEY CLUSTERED ([OldFeatureID]);
GO

-- SunsetFeature exists in the pre-pull baseline. Both the drift block below
-- and the pull remove it — so post-pull, dev and schema-model already agree
-- it's gone. Snapshot still has it. That's the `Add missing` category:
-- present in snapshot only, no action needed on either leg.
CREATE TABLE [Customers].[SunsetFeature]
(
[SunsetFeatureID] [int] NOT NULL IDENTITY(1, 1),
[Description] [nvarchar] (200) NULL
);
GO
ALTER TABLE [Customers].[SunsetFeature] ADD CONSTRAINT [PK__SunsetFe__CAFE5678] PRIMARY KEY CLUSTERED ([SunsetFeatureID]);
GO

-- Drift: local edits made directly on dev that schema-model doesn't know about.
-- These are the changes we expect to appear as EXISTING-* in the 3-sided diff.
ALTER TABLE [Customers].[Customer] ADD [LoyaltyPoints] [int] NULL;
GO
ALTER TABLE [Customers].[Newsletter] ALTER COLUMN [Title] [nvarchar](200) NOT NULL;
GO
DROP TABLE [Customers].[SunsetFeature];
GO
