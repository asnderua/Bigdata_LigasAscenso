USE [LigasdeAscenso];
GO

DECLARE @Boleto int = 2; -- Escribe el ID anotado.
DECLARE @EstadoEsperado varchar(50) = 'Pagado';
DECLARE @EstadoNuevo varchar(50) = 'Anulado';

UPDATE dbo.Boleto
SET EstadoPago = @EstadoNuevo
OUTPUT
    inserted.IDboleto AS IDBoleto,
    deleted.EstadoPago AS EstadoAnterior,
    inserted.EstadoPago AS EstadoNuevo
WHERE IDboleto = @Boleto
  AND EstadoPago = @EstadoEsperado;

IF @@ROWCOUNT = 0
    THROW 51000, N'Revisa el ID del boleto y su estado actual.', 1;