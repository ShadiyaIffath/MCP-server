CREATE TABLE [Customers].[CustomerPreference]
(
[PreferenceID] [int] NOT NULL IDENTITY(1, 1),
[CustomerID] [int] NOT NULL,
[Channel] [nvarchar] (50) NOT NULL,
[OptIn] [bit] NOT NULL
)
GO
ALTER TABLE [Customers].[CustomerPreference] ADD CONSTRAINT [PK__CustPref__A4AE64B811223344] PRIMARY KEY CLUSTERED ([PreferenceID])
GO
ALTER TABLE [Customers].[CustomerPreference] ADD CONSTRAINT [FK__CustPref__Cust__11223345] FOREIGN KEY ([CustomerID]) REFERENCES [Customers].[Customer]([CustomerID])
GO
