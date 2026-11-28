EXEC sys.sp_releaseapplock
    @Resource = N'ETL_LigasAscenso.Staging', @LockOwner = 'Session';
