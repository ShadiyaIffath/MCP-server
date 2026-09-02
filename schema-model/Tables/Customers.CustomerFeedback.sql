CREATE TABLE [Customers].[CustomerFeedback]
(
[FeedbackID] [int] NOT NULL IDENTITY(1, 1),
[CustomerID] [int] NULL,
[FeedbackDate] [datetime] NULL CONSTRAINT [DF__CustomerF__Feedb__3E52440B] DEFAULT (getdate()),
[Rating] [int] NULL,
[Comments] [nvarchar] (500) NULL
)
GO
ALTER TABLE [Customers].[CustomerFeedback] ADD CONSTRAINT [CK__CustomerF__Ratin__3F466844] CHECK (([Rating]>=(1) AND [Rating]<=(5)))
GO
ALTER TABLE [Customers].[CustomerFeedback] ADD CONSTRAINT [PK__Customer__6A4BEDF6FBDF0B79] PRIMARY KEY CLUSTERED ([FeedbackID])
GO
ALTER TABLE [Customers].[CustomerFeedback] ADD CONSTRAINT [FK__CustomerF__Custo__3D5E1FD2] FOREIGN KEY ([CustomerID]) REFERENCES [Customers].[Customer] ([CustomerID])
GO
