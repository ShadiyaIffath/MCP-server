CREATE TABLE [Customers].[OldFeature]
(
[OldFeatureID] [int] NOT NULL IDENTITY(1, 1),
[Description] [nvarchar] (200) NULL
)
GO
ALTER TABLE [Customers].[OldFeature] ADD CONSTRAINT [PK__OldFeat__BEEF1234] PRIMARY KEY CLUSTERED ([OldFeatureID])
GO
