-- ============================================
-- CRÉATION DE LA BASE DE DONNÉES
-- ============================================
USE master;
GO

IF EXISTS (SELECT name FROM sys.databases WHERE name = N'LineageGraphDB')
BEGIN
    ALTER DATABASE LineageGraphDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LineageGraphDB;
END
GO

CREATE DATABASE LineageGraphDB;
GO

USE LineageGraphDB;
GO

-- ============================================
-- CRÉATION DE LA TABLE UNIQUE
-- ============================================
CREATE TABLE dbo.GrapheTransformation (
    id INT PRIMARY KEY IDENTITY(1,1),
    id_type INT NOT NULL,
    input1 NVARCHAR(100),
    input2 NVARCHAR(100),
    input3 NVARCHAR(100),
    input4 NVARCHAR(100),
    transformation NVARCHAR(255) NOT NULL,
    output1 NVARCHAR(100),
    output2 NVARCHAR(100),
    output3 NVARCHAR(100),
    output4 NVARCHAR(100),
    proprietaire NVARCHAR(100),
    date_creation DATETIME2 DEFAULT GETDATE()
);
GO

PRINT 'Table GrapheTransformation créée avec succès';
GO

-- ============================================
-- GÉNÉRATION DE 10 000 ENREGISTREMENTS
-- ============================================
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

PRINT 'Début de la génération des données...';

-- Génération par lots de 1000 pour performance
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
        -- Inputs : référencent des outputs de nœuds précédents (créent le graphe)
        CASE WHEN @i > 1 THEN 'DATA_' + CAST(@i - 1 AS VARCHAR(10)) + '_O1' ELSE NULL END,
        CASE WHEN @i > 2 AND @i % 3 = 0 THEN 'DATA_' + CAST(@i - 2 AS VARCHAR(10)) + '_O2' ELSE NULL END,
        CASE WHEN @i > 5 AND @i % 5 = 0 THEN 'DATA_' + CAST(@i - 5 AS VARCHAR(10)) + '_O1' ELSE NULL END,
        CASE WHEN @i > 10 AND @i % 10 = 0 THEN 'DATA_' + CAST(@i - 10 AS VARCHAR(10)) + '_O3' ELSE NULL END,
        -- Transformation
        t.nom + '_' + CAST(@i AS VARCHAR(10)),
        -- Outputs : seront référencés par des nœuds suivants
        'DATA_' + CAST(@i AS VARCHAR(10)) + '_O1',
        CASE WHEN @i % 2 = 0 THEN 'DATA_' + CAST(@i AS VARCHAR(10)) + '_O2' ELSE NULL END,
        CASE WHEN @i % 3 = 0 THEN 'DATA_' + CAST(@i AS VARCHAR(10)) + '_O3' ELSE NULL END,
        CASE WHEN @i % 4 = 0 THEN 'DATA_' + CAST(@i AS VARCHAR(10)) + '_O4' ELSE NULL END,
        -- Propriétaire
        p.nom
    FROM @TypesTransfo t
    CROSS JOIN @Proprietaires p
    WHERE t.id = @idType AND p.id = @proprio;

    -- Afficher progression tous les 1000
    IF @i % 1000 = 0
        PRINT 'Enregistrements créés: ' + CAST(@i AS VARCHAR(10));

    SET @i = @i + 1;
END

PRINT 'Génération terminée: ' + CAST(@MaxRecords AS VARCHAR(10)) + ' enregistrements';
GO

-- ============================================
-- CRÉATION DES INDEX
-- ============================================
PRINT 'Création des index...';

CREATE INDEX IX_Input1 ON dbo.GrapheTransformation(input1) WHERE input1 IS NOT NULL;
CREATE INDEX IX_Input2 ON dbo.GrapheTransformation(input2) WHERE input2 IS NOT NULL;
CREATE INDEX IX_Input3 ON dbo.GrapheTransformation(input3) WHERE input3 IS NOT NULL;
CREATE INDEX IX_Input4 ON dbo.GrapheTransformation(input4) WHERE input4 IS NOT NULL;
CREATE INDEX IX_Output1 ON dbo.GrapheTransformation(output1) WHERE output1 IS NOT NULL;
CREATE INDEX IX_Output2 ON dbo.GrapheTransformation(output2) WHERE output2 IS NOT NULL;
CREATE INDEX IX_Output3 ON dbo.GrapheTransformation(output3) WHERE output3 IS NOT NULL;
CREATE INDEX IX_Output4 ON dbo.GrapheTransformation(output4) WHERE output4 IS NOT NULL;
CREATE INDEX IX_Proprietaire ON dbo.GrapheTransformation(proprietaire);
CREATE INDEX IX_Type ON dbo.GrapheTransformation(id_type);

PRINT 'Index créés avec succès';
GO

-- ============================================
-- STATISTIQUES
-- ============================================
PRINT '';
PRINT '========== STATISTIQUES ==========';

SELECT 'Total enregistrements' AS Info, COUNT(*) AS Valeur FROM dbo.GrapheTransformation
UNION ALL
SELECT 'Nœuds avec input1', COUNT(*) FROM dbo.GrapheTransformation WHERE input1 IS NOT NULL
UNION ALL
SELECT 'Nœuds avec input2', COUNT(*) FROM dbo.GrapheTransformation WHERE input2 IS NOT NULL
UNION ALL
SELECT 'Nœuds avec input3', COUNT(*) FROM dbo.GrapheTransformation WHERE input3 IS NOT NULL
UNION ALL
SELECT 'Nœuds avec input4', COUNT(*) FROM dbo.GrapheTransformation WHERE input4 IS NOT NULL
UNION ALL
SELECT 'Nœuds avec output2', COUNT(*) FROM dbo.GrapheTransformation WHERE output2 IS NOT NULL
UNION ALL
SELECT 'Nœuds avec output3', COUNT(*) FROM dbo.GrapheTransformation WHERE output3 IS NOT NULL
UNION ALL
SELECT 'Nœuds avec output4', COUNT(*) FROM dbo.GrapheTransformation WHERE output4 IS NOT NULL;

PRINT '';
PRINT '========== CONNEXIONS DU GRAPHE ==========';

SELECT 'Connexions output1->input1' AS TypeConnexion, COUNT(*) AS Nombre
FROM dbo.GrapheTransformation g1
JOIN dbo.GrapheTransformation g2 ON g1.output1 = g2.input1
UNION ALL
SELECT 'Connexions output2->input2', COUNT(*)
FROM dbo.GrapheTransformation g1
JOIN dbo.GrapheTransformation g2 ON g1.output2 = g2.input2
WHERE g1.output2 IS NOT NULL;

PRINT '';
PRINT '========== APERÇU DES DONNÉES ==========';
SELECT TOP 15
    id,
    id_type,
    input1,
    input2,
    transformation,
    output1,
    output2,
    proprietaire
FROM dbo.GrapheTransformation
ORDER BY id;

PRINT '';
PRINT 'Base de données LineageGraphDB créée avec succès!';
GO
