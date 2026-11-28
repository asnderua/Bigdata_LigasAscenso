SELECT
    b.IDboleto AS [IDBoletoOrigen],
    b.IDpartido AS [IDPartidoOrigen],
    t.IDtipoEntrada AS [IDTipoEntradaOrigen],
    t.nombreTE AS [NombreTipoEntrada],
    CAST(t.PrecioBase AS decimal(10,2)) AS [PrecioBase],
    b.FechaVenta AS [FechaVenta],
    b.CanalVenta AS [CanalVenta],
    b.MetodoPago AS [MetodoPago],
    b.EstadoPago AS [EstadoPago],
    CAST(b.PrecioPagado AS decimal(10,2)) AS [PrecioPagado]
FROM dbo.Boleto AS b
JOIN dbo.TipoEntrada AS t ON t.IDtipoEntrada = b.IDtipoEntrada;
