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
)
GO
ALTER TABLE [Customers].[Address] ADD CONSTRAINT [PK__Address__A4AE64B8B3B6EF77] PRIMARY KEY CLUSTERED ([AddressID])
GO
ALTER TABLE [Customers].[Address] ADD CONSTRAINT [FK__Address__CustomerID__A9D10534] FOREIGN KEY ([CustomerID]) REFERENCES [Customers].[Customer]([CustomerID])
GO
