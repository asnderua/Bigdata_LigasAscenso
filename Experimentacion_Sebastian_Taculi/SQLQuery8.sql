USE [LigasdeAscenso];
GO

DECLARE @Boleto int = NULL; -- Después, reemplaza NULL por el ID anotado.

IF @Boleto IS NULL
BEGIN
    SELECT TOP (1) @Boleto = MIN(IDboleto)
    FROM dbo.Boleto
    WHERE EstadoPago = 'Pagado'
    GROUP BY IDpartido, IDtipoEntrada
    HAVING COUNT_BIG(*) = 1
    ORDER BY MIN(IDboleto);
END;

SELECT
    b.IDboleto AS IDBoleto,
    b.IDpartido AS IDPartido,
    b.IDtipoEntrada AS IDTipoEntrada,
    b.EstadoPago AS EstadoOrigen,
    s.EstadoPago AS EstadoStaging,
    CASE WHEN f.IDPartido IS NULL THEN N'No' ELSE N'Sí' END AS ExisteFilaEnDW
FROM dbo.Boleto AS b
LEFT JOIN [Staging_Ligas].dbo.stg_Boletos AS s
    ON s.IDBoletoOrigen = b.IDboleto
LEFT JOIN [DW_LigasdeAscenso].dbo.FactVentas AS f
    ON f.IDPartido = b.IDpartido
   AND f.IDTipoEntrada = b.IDtipoEntrada
WHERE b.IDboleto = @Boleto;