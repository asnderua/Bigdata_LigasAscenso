SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @LockResult int;
EXEC @LockResult = sys.sp_getapplock
    @Resource = N'ETL_LigasAscenso.Staging', @LockMode = 'Exclusive',
    @LockOwner = 'Session', @LockTimeout = 60000;
IF @LockResult < 0 THROW 51000, 'No se consiguió el bloqueo de staging.', 1;
BEGIN TRANSACTION;
DELETE FROM dbo.stg_Asistencia;
DELETE FROM dbo.stg_Boletos;
DELETE FROM dbo.stg_Partidos;
COMMIT TRANSACTION;
