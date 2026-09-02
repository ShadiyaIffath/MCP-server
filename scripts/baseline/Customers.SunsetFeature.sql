CREATE TABLE [Customers].[SunsetFeature]
(
[SunsetFeatureID] [int] NOT NULL IDENTITY(1, 1),
[Description] [nvarchar] (200) NULL
)
GO
ALTER TABLE [Customers].[SunsetFeature] ADD CONSTRAINT [PK__SunsetFe__CAFE5678] PRIMARY KEY CLUSTERED ([SunsetFeatureID])
GO
