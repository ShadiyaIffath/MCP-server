CREATE TABLE [Customers].[Newsletter]
(
[NewsletterID] [int] NOT NULL IDENTITY(1, 1),
[Title] [nvarchar] (100) NOT NULL,
[Body] [nvarchar] (max) NULL,
[SentDate] [datetime] NULL
)
GO
ALTER TABLE [Customers].[Newsletter] ADD CONSTRAINT [PK__Newslett__AF3A0FB1] PRIMARY KEY CLUSTERED ([NewsletterID])
GO
