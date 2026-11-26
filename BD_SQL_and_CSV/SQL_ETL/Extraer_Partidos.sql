SELECT
    p.IDpartido AS [IDPartidoOrigen],
    t.IDtemporada AS [IDTemporadaOrigen],
    t.Anio AS [AnioTemporada],
    t.FechaInicio AS [FechaInicioTemporada],
    t.FechaFinal AS [FechaFinTemporada],
    e.IDetapa AS [IDEtapaOrigen],
    c.IDcompeticion AS [IDCompeticionOrigen],
    c.NombreCompeticion AS [NombreCompeticion],
    c.Organizador AS [Organizador],
    c.Nivelcompeticion AS [NivelCompeticion],
    e.nombreEtapa AS [NombreEtapa],
    e.nivelEtapa AS [NivelEtapa],
    CAST(e.FactorPrecio AS decimal(10,2)) AS [FactorPrecio],
    es.IDestadio AS [IDEstadioOrigen],
    es.NombreEstadio AS [NombreEstadio],
    ue.Departamento AS [DepartamentoEstadio],
    ue.Provincia AS [ProvinciaEstadio],
    ue.Distrito AS [DistritoEstadio],
    ue.Region AS [RegionEstadio],
    es.Categoria AS [CategoriaEstadio],
    es.MaxAforo AS [MaxAforo],
    l.IDclub AS [IDClubLocalOrigen],
    l.NombreClub AS [NombreClubLocal],
    ul.Departamento AS [DepartamentoClubLocal],
    ul.Provincia AS [ProvinciaClubLocal],
    l.AnioFundacion AS [AnioFundacionLocal],
    v.IDclub AS [IDClubVisitaOrigen],
    v.NombreClub AS [NombreClubVisita],
    uv.Departamento AS [DepartamentoClubVisita],
    uv.Provincia AS [ProvinciaClubVisita],
    v.AnioFundacion AS [AnioFundacionVisita],
    p.FechaHora AS [FechaHoraPartido],
    p.Jornada AS [Jornada],
    p.EstadoPartido AS [EstadoPartido]
FROM dbo.Partido AS p
JOIN dbo.temporada AS t ON t.IDtemporada = p.IDtemporada
JOIN dbo.Etapas AS e ON e.IDetapa = p.IDetapa
JOIN dbo.Competicion AS c ON c.IDcompeticion = e.IDcompeticion
JOIN dbo.Estadio AS es ON es.IDestadio = p.IDestadio
JOIN dbo.Ubicacion AS ue ON ue.IDubicacion = es.IDubicacion
JOIN dbo.Club AS l ON l.IDclub = p.IDequipoLocal
JOIN dbo.Ubicacion AS ul ON ul.IDubicacion = l.IDubicacion
JOIN dbo.Club AS v ON v.IDclub = p.IDequipoVisitante
JOIN dbo.Ubicacion AS uv ON uv.IDubicacion = v.IDubicacion;
