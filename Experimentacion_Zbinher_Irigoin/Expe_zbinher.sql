USE [Staging_Ligas];
GO

SELECT data_compression_desc AS Compresion
FROM sys.partitions
WHERE object_id = OBJECT_ID(N'dbo.stg_Boletos')
  AND index_id IN (0, 1);

EXEC sys.sp_spaceused @objname = N'dbo.stg_Boletos';