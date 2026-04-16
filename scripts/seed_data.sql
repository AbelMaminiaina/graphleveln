-- ============================================
-- SCRIPT: Génération des données de test (SEED)
-- Base: LineageGraphDB
-- Génère 10 000 enregistrements
-- ============================================

USE LineageGraphDB;
GO

SET NOCOUNT ON;

DECLARE @i INT = 1;
DECLARE @MaxRecords INT = 10000;

-- Tables temporaires pour les référentiels
DECLARE @TypesTransfo TABLE (id INT, nom NVARCHAR(50));
DECLARE @Proprietaires TABLE (id INT, nom NVARCHAR(50));

-- Types de transformation
INSERT INTO @TypesTransfo VALUES
(1, 'ETL_Extract'), (2, 'ETL_Transform'), (3, 'ETL_Load'),
(4, 'Filter'), (5, 'Aggregate'), (6, 'Join'),
(7, 'Split'), (8, 'Merge'), (9, 'Calculate'), (10, 'Validate');

-- Propriétaires
INSERT INTO @Proprietaires VALUES
(1, 'Finance'), (2, 'RH'), (3, 'IT'), (4, 'Marketing'),
(5, 'Production'), (6, 'Logistique'), (7, 'Commercial'), (8, 'Direction');

PRINT 'Debut de la generation des donnees...';

-- Génération des enregistrements
WHILE @i <= @MaxRecords
BEGIN
    DECLARE @idType INT = ((@i - 1) % 10) + 1;
    DECLARE @proprio INT = ((@i - 1) % 8) + 1;

    INSERT INTO dbo.GrapheTransformation (
        id_type,
        input1, input2, input3, input4,
        transformation,
        output1, output2, output3, output4,
        proprietaire
    )
    SELECT
        @idType,
        -- Inputs : référencent des outputs de noeuds précédents
        CASE WHEN @i > 1 THEN 'DATA_' + CAST(@i - 1 AS VARCHAR(10)) + '_O1' ELSE NULL END,
        CASE WHEN @i > 2 AND @i % 3 = 0 THEN 'DATA_' + CAST(@i - 2 AS VARCHAR(10)) + '_O2' ELSE NULL END,
        CASE WHEN @i > 5 AND @i % 5 = 0 THEN 'DATA_' + CAST(@i - 5 AS VARCHAR(10)) + '_O1' ELSE NULL END,
        CASE WHEN @i > 10 AND @i % 10 = 0 THEN 'DATA_' + CAST(@i - 10 AS VARCHAR(10)) + '_O3' ELSE NULL END,
        -- Transformation
        t.nom + '_' + CAST(@i AS VARCHAR(10)),
        -- Outputs
        'DATA_' + CAST(@i AS VARCHAR(10)) + '_O1',
        CASE WHEN @i % 2 = 0 THEN 'DATA_' + CAST(@i AS VARCHAR(10)) + '_O2' ELSE NULL END,
        CASE WHEN @i % 3 = 0 THEN 'DATA_' + CAST(@i AS VARCHAR(10)) + '_O3' ELSE NULL END,
        CASE WHEN @i % 4 = 0 THEN 'DATA_' + CAST(@i AS VARCHAR(10)) + '_O4' ELSE NULL END,
        -- Propriétaire
        p.nom
    FROM @TypesTransfo t
    CROSS JOIN @Proprietaires p
    WHERE t.id = @idType AND p.id = @proprio;

    IF @i % 1000 = 0
        PRINT 'Enregistrements crees: ' + CAST(@i AS VARCHAR(10));

    SET @i = @i + 1;
END

PRINT 'Generation terminee: ' + CAST(@MaxRecords AS VARCHAR(10)) + ' enregistrements';
GO

-- Statistiques
SELECT 'Total' AS Info, COUNT(*) AS Valeur FROM dbo.GrapheTransformation;
GO
