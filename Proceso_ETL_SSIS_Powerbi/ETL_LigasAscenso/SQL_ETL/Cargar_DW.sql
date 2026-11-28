USE [DW_LigasdeAscenso];
GO
-- Carga manual desde staging en la misma instancia.
-- En uso normal, ejecute Package.dtsx. Use este script solo para
-- probar la fase DW después de llenar staging con los tres flujos.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    IF OBJECT_ID(N'dbo.FactVentas', N'U') IS NULL
        OR OBJECT_ID(N'dbo.FactAsistencia', N'U') IS NULL
        THROW 51008, 'El DW debe tener dbo.FactVentas y dbo.FactAsistencia. Revise BaseDW y el script DW_ligasdeAscenso_new.sql.', 1;
    IF @@TRANCOUNT <> 0
        THROW 51007, 'Ejecute esta carga en una sesión sin una transacción activa.', 1;

    BEGIN TRANSACTION;
    DECLARE @StagingLockResult int;
    EXEC @StagingLockResult = [Staging_Ligas].sys.sp_getapplock
        @Resource = N'ETL_LigasAscenso.Staging', @LockMode = 'Shared',
        @LockOwner = 'Transaction', @LockTimeout = 60000;
    IF @StagingLockResult < 0
        THROW 51009, 'No se pudo bloquear la lectura de staging.', 1;

    -- Cargar DimTiempo
    SET LANGUAGE Spanish;
    SET DATEFIRST 1;
    DECLARE @LockResult int;
        EXEC @LockResult = sys.sp_getapplock
            @Resource = N'ETL_LigasAscenso.DW', @LockMode = 'Exclusive',
            @LockOwner = 'Transaction', @LockTimeout = 60000;
        IF @LockResult < 0 THROW 51001, 'No se consiguió el bloqueo del DW.', 1;

        IF EXISTS (SELECT 1 FROM [Staging_Ligas].dbo.stg_Boletos AS b
                   WHERE NOT EXISTS (SELECT 1 FROM [Staging_Ligas].dbo.stg_Partidos AS p WHERE p.IDPartidoOrigen = b.IDPartidoOrigen))
           OR EXISTS (SELECT 1 FROM [Staging_Ligas].dbo.stg_Asistencia AS a
                      WHERE NOT EXISTS (SELECT 1 FROM [Staging_Ligas].dbo.stg_Partidos AS p WHERE p.IDPartidoOrigen = a.IDPartidoOrigen))
            THROW 51002, 'Staging contiene boletos o asistencia sin partido. Reintente con el origen estable.', 1;

    SELECT DISTINCT IDTiempo, Fecha, Anio, Mes, NombreMes, Dia, DiaSemana, NombreDiaSemana, EsFinDeSemana
    INTO #DimTiempo
    FROM (
        SELECT CONVERT(int, CONVERT(char(8), f.Fecha, 112)), f.Fecha,
               YEAR(f.Fecha), MONTH(f.Fecha), DATENAME(month, f.Fecha),
               DAY(f.Fecha), DATEPART(weekday, f.Fecha), DATENAME(weekday, f.Fecha),
               CONVERT(bit, CASE WHEN DATEPART(weekday, f.Fecha) IN (6, 7) THEN 1 ELSE 0 END)
        FROM [Staging_Ligas].dbo.stg_Partidos AS p
        CROSS APPLY (VALUES (CONVERT(date, p.FechaHoraPartido))) AS f (Fecha)
    ) AS d (IDTiempo, Fecha, Anio, Mes, NombreMes, Dia, DiaSemana, NombreDiaSemana, EsFinDeSemana);
    CREATE UNIQUE CLUSTERED INDEX IX_DimTiempo ON #DimTiempo (IDTiempo);

    UPDATE dst SET
        Fecha = src.Fecha,
        Anio = src.Anio,
        Mes = src.Mes,
        NombreMes = src.NombreMes,
        Dia = src.Dia,
        DiaSemana = src.DiaSemana,
        NombreDiaSemana = src.NombreDiaSemana,
        EsFinDeSemana = src.EsFinDeSemana
    FROM dbo.DimTiempo AS dst
    JOIN #DimTiempo AS src ON src.IDTiempo = dst.IDTiempo
    WHERE EXISTS (
        SELECT src.Fecha, src.Anio, src.Mes, src.NombreMes, src.Dia, src.DiaSemana, src.NombreDiaSemana, src.EsFinDeSemana
        EXCEPT
        SELECT dst.Fecha, dst.Anio, dst.Mes, dst.NombreMes, dst.Dia, dst.DiaSemana, dst.NombreDiaSemana, dst.EsFinDeSemana
    );

    INSERT INTO dbo.DimTiempo (IDTiempo, Fecha, Anio, Mes, NombreMes, Dia, DiaSemana, NombreDiaSemana, EsFinDeSemana)
    SELECT IDTiempo, Fecha, Anio, Mes, NombreMes, Dia, DiaSemana, NombreDiaSemana, EsFinDeSemana FROM #DimTiempo AS src
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimTiempo AS dst WHERE dst.IDTiempo = src.IDTiempo);

    -- Cargar DimTemporada
    SELECT DISTINCT IDTemporada, Anio, FechaInicio, FechaFinal
    INTO #DimTemporada
    FROM (
        SELECT IDTemporadaOrigen, AnioTemporada, FechaInicioTemporada, FechaFinTemporada
        FROM [Staging_Ligas].dbo.stg_Partidos
    ) AS d (IDTemporada, Anio, FechaInicio, FechaFinal);
    CREATE UNIQUE CLUSTERED INDEX IX_DimTemporada ON #DimTemporada (IDTemporada);

    UPDATE dst SET
        Anio = src.Anio,
        FechaInicio = src.FechaInicio,
        FechaFinal = src.FechaFinal
    FROM dbo.DimTemporada AS dst
    JOIN #DimTemporada AS src ON src.IDTemporada = dst.IDTemporada
    WHERE EXISTS (
        SELECT src.Anio, src.FechaInicio, src.FechaFinal
        EXCEPT
        SELECT dst.Anio, dst.FechaInicio, dst.FechaFinal
    );

    INSERT INTO dbo.DimTemporada (IDTemporada, Anio, FechaInicio, FechaFinal)
    SELECT IDTemporada, Anio, FechaInicio, FechaFinal FROM #DimTemporada AS src
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimTemporada AS dst WHERE dst.IDTemporada = src.IDTemporada);

    -- Cargar DimEstadio
    SELECT DISTINCT IDEstadio, NombreEstadio, Departamento, Provincia, Distrito, Region, Categoria, MaxAforo
    INTO #DimEstadio
    FROM (
        SELECT IDEstadioOrigen, NombreEstadio, DepartamentoEstadio, ProvinciaEstadio,
               DistritoEstadio, RegionEstadio, CategoriaEstadio, MaxAforo
        FROM [Staging_Ligas].dbo.stg_Partidos
    ) AS d (IDEstadio, NombreEstadio, Departamento, Provincia, Distrito, Region, Categoria, MaxAforo);
    CREATE UNIQUE CLUSTERED INDEX IX_DimEstadio ON #DimEstadio (IDEstadio);

    UPDATE dst SET
        NombreEstadio = src.NombreEstadio,
        Departamento = src.Departamento,
        Provincia = src.Provincia,
        Distrito = src.Distrito,
        Region = src.Region,
        Categoria = src.Categoria,
        MaxAforo = src.MaxAforo
    FROM dbo.DimEstadio AS dst
    JOIN #DimEstadio AS src ON src.IDEstadio = dst.IDEstadio
    WHERE EXISTS (
        SELECT src.NombreEstadio, src.Departamento, src.Provincia, src.Distrito, src.Region, src.Categoria, src.MaxAforo
        EXCEPT
        SELECT dst.NombreEstadio, dst.Departamento, dst.Provincia, dst.Distrito, dst.Region, dst.Categoria, dst.MaxAforo
    );

    INSERT INTO dbo.DimEstadio (IDEstadio, NombreEstadio, Departamento, Provincia, Distrito, Region, Categoria, MaxAforo)
    SELECT IDEstadio, NombreEstadio, Departamento, Provincia, Distrito, Region, Categoria, MaxAforo FROM #DimEstadio AS src
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimEstadio AS dst WHERE dst.IDEstadio = src.IDEstadio);

    -- Cargar DimCompeticion
    SELECT DISTINCT IDEtapa, IDCompeticionOrigen, NombreCompeticion, Organizador, NivelCompeticion, NombreEtapa, NivelEtapa, FactorPrecio
    INTO #DimCompeticion
    FROM (
        SELECT IDEtapaOrigen, IDCompeticionOrigen, NombreCompeticion, Organizador,
               NivelCompeticion, NombreEtapa, NivelEtapa, FactorPrecio
        FROM [Staging_Ligas].dbo.stg_Partidos
    ) AS d (IDEtapa, IDCompeticionOrigen, NombreCompeticion, Organizador, NivelCompeticion, NombreEtapa, NivelEtapa, FactorPrecio);
    CREATE UNIQUE CLUSTERED INDEX IX_DimCompeticion ON #DimCompeticion (IDEtapa);

    UPDATE dst SET
        IDCompeticionOrigen = src.IDCompeticionOrigen,
        NombreCompeticion = src.NombreCompeticion,
        Organizador = src.Organizador,
        NivelCompeticion = src.NivelCompeticion,
        NombreEtapa = src.NombreEtapa,
        NivelEtapa = src.NivelEtapa,
        FactorPrecio = src.FactorPrecio
    FROM dbo.DimCompeticion AS dst
    JOIN #DimCompeticion AS src ON src.IDEtapa = dst.IDEtapa
    WHERE EXISTS (
        SELECT src.IDCompeticionOrigen, src.NombreCompeticion, src.Organizador, src.NivelCompeticion, src.NombreEtapa, src.NivelEtapa, src.FactorPrecio
        EXCEPT
        SELECT dst.IDCompeticionOrigen, dst.NombreCompeticion, dst.Organizador, dst.NivelCompeticion, dst.NombreEtapa, dst.NivelEtapa, dst.FactorPrecio
    );

    INSERT INTO dbo.DimCompeticion (IDEtapa, IDCompeticionOrigen, NombreCompeticion, Organizador, NivelCompeticion, NombreEtapa, NivelEtapa, FactorPrecio)
    SELECT IDEtapa, IDCompeticionOrigen, NombreCompeticion, Organizador, NivelCompeticion, NombreEtapa, NivelEtapa, FactorPrecio FROM #DimCompeticion AS src
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimCompeticion AS dst WHERE dst.IDEtapa = src.IDEtapa);

    -- Cargar DimTipoEntrada
    SELECT DISTINCT IDTipoEntrada, NombreTE, PrecioBase
    INTO #DimTipoEntrada
    FROM (
        SELECT IDTipoEntradaOrigen, NombreTipoEntrada, PrecioBase FROM [Staging_Ligas].dbo.stg_Boletos
    ) AS d (IDTipoEntrada, NombreTE, PrecioBase);
    CREATE UNIQUE CLUSTERED INDEX IX_DimTipoEntrada ON #DimTipoEntrada (IDTipoEntrada);

    UPDATE dst SET
        NombreTE = src.NombreTE,
        PrecioBase = src.PrecioBase
    FROM dbo.DimTipoEntrada AS dst
    JOIN #DimTipoEntrada AS src ON src.IDTipoEntrada = dst.IDTipoEntrada
    WHERE EXISTS (
        SELECT src.NombreTE, src.PrecioBase
        EXCEPT
        SELECT dst.NombreTE, dst.PrecioBase
    );

    INSERT INTO dbo.DimTipoEntrada (IDTipoEntrada, NombreTE, PrecioBase)
    SELECT IDTipoEntrada, NombreTE, PrecioBase FROM #DimTipoEntrada AS src
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimTipoEntrada AS dst WHERE dst.IDTipoEntrada = src.IDTipoEntrada);

    -- Cargar DimClub
    SELECT DISTINCT IDClub, NombreClub, Departamento, Provincia, AnioFundacion
    INTO #DimClub
    FROM (
        SELECT IDClubLocalOrigen, NombreClubLocal, DepartamentoClubLocal, ProvinciaClubLocal, AnioFundacionLocal FROM [Staging_Ligas].dbo.stg_Partidos
        UNION ALL
        SELECT IDClubVisitaOrigen, NombreClubVisita, DepartamentoClubVisita, ProvinciaClubVisita, AnioFundacionVisita FROM [Staging_Ligas].dbo.stg_Partidos
    ) AS d (IDClub, NombreClub, Departamento, Provincia, AnioFundacion);
    CREATE UNIQUE CLUSTERED INDEX IX_DimClub ON #DimClub (IDClub);

    UPDATE dst SET
        NombreClub = src.NombreClub,
        Departamento = src.Departamento,
        Provincia = src.Provincia,
        AnioFundacion = src.AnioFundacion
    FROM dbo.DimClub AS dst
    JOIN #DimClub AS src ON src.IDClub = dst.IDClub
    WHERE EXISTS (
        SELECT src.NombreClub, src.Departamento, src.Provincia, src.AnioFundacion
        EXCEPT
        SELECT dst.NombreClub, dst.Departamento, dst.Provincia, dst.AnioFundacion
    );

    INSERT INTO dbo.DimClub (IDClub, NombreClub, Departamento, Provincia, AnioFundacion)
    SELECT IDClub, NombreClub, Departamento, Provincia, AnioFundacion FROM #DimClub AS src
    WHERE NOT EXISTS (SELECT 1 FROM dbo.DimClub AS dst WHERE dst.IDClub = src.IDClub);

    -- Cargar FactVentas
    DELETE f
    FROM dbo.FactVentas AS f
    JOIN [Staging_Ligas].dbo.stg_Partidos AS p ON p.IDPartidoOrigen = f.IDPartido;

    ;WITH Ventas AS (
        SELECT IDPartidoOrigen, IDTipoEntradaOrigen, COUNT(*) AS BoletosVendidos,
               SUM(COALESCE(PrecioPagado, CONVERT(decimal(10,2), 0))) AS IngresosTaquilla
        FROM [Staging_Ligas].dbo.stg_Boletos
        WHERE EstadoPago = 'Pagado'
        GROUP BY IDPartidoOrigen, IDTipoEntradaOrigen
    )
    INSERT INTO dbo.FactVentas (
        IDPartido, IDTipoEntrada, IDTiempoPartido, IDTemporada, IDEstadio, IDEtapa,
        IDClubLocal, IDClubVisita, BoletosVendidos, IngresosTaquilla
    )
    SELECT p.IDPartidoOrigen, v.IDTipoEntradaOrigen, CONVERT(int, CONVERT(char(8), p.FechaHoraPartido, 112)),
           p.IDTemporadaOrigen, p.IDEstadioOrigen, p.IDEtapaOrigen, p.IDClubLocalOrigen,
           p.IDClubVisitaOrigen, v.BoletosVendidos, v.IngresosTaquilla
    FROM Ventas AS v
    JOIN [Staging_Ligas].dbo.stg_Partidos AS p ON p.IDPartidoOrigen = v.IDPartidoOrigen;

    -- Cargar FactAsistencia
    DELETE f
    FROM dbo.FactAsistencia AS f
    JOIN [Staging_Ligas].dbo.stg_Partidos AS p ON p.IDPartidoOrigen = f.IDPartido;

    INSERT INTO dbo.FactAsistencia (
        IDPartido, IDTiempoPartido, IDTemporada, IDEstadio, IDEtapa,
        IDClubLocal, IDClubVisita, EstadoPartido, AsistenciaRegistrada, AforoEstadio
    )
    SELECT p.IDPartidoOrigen, CONVERT(int, CONVERT(char(8), p.FechaHoraPartido, 112)),
           p.IDTemporadaOrigen, p.IDEstadioOrigen, p.IDEtapaOrigen, p.IDClubLocalOrigen,
           p.IDClubVisitaOrigen, p.EstadoPartido, a.AsistenciaRegistrada, a.AforoEstadio
    FROM [Staging_Ligas].dbo.stg_Partidos AS p
    LEFT JOIN [Staging_Ligas].dbo.stg_Asistencia AS a ON a.IDPartidoOrigen = p.IDPartidoOrigen;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
