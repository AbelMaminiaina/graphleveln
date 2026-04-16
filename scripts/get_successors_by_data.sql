-- ============================================
-- SCRIPT: Obtenir les successeurs d'une donnée
-- Usage: Remplacer @DataName par la donnée recherchée
-- ============================================

USE LineageGraphDB;
GO

DECLARE @DataName NVARCHAR(100) = 'DATA_1_O1';  -- << Modifier ici

PRINT '=== Successeurs de ' + @DataName + ' ===';
PRINT '';

;WITH Successors AS (
    -- Base: trouver le node source qui produit cette donnée
    SELECT
        e.target_node_id AS node_id,
        n.transformation,
        n.id_type,
        n.proprietaire,
        e.data_name,
        1 AS depth,
        CAST(CAST(e.source_node_id AS VARCHAR(10)) + ' -> ' + CAST(e.target_node_id AS VARCHAR(10)) AS VARCHAR(MAX)) AS path
    FROM dbo.Edges e
    INNER JOIN dbo.Nodes n ON e.target_node_id = n.id
    WHERE e.data_name = @DataName

    UNION ALL

    -- Récursion: successeurs des successeurs
    SELECT
        e.target_node_id,
        n.transformation,
        n.id_type,
        n.proprietaire,
        e.data_name,
        s.depth + 1,
        s.path + ' -> ' + CAST(e.target_node_id AS VARCHAR(10))
    FROM dbo.Edges e
    INNER JOIN dbo.Nodes n ON e.target_node_id = n.id
    INNER JOIN Successors s ON e.source_node_id = s.node_id
    WHERE s.depth < 10
    AND CHARINDEX(CAST(e.target_node_id AS VARCHAR(10)), s.path) = 0
)
SELECT DISTINCT
    depth AS [Depth],
    node_id AS [Node ID],
    transformation AS [Transformation],
    proprietaire AS [Proprietaire],
    data_name AS [Data],
    path AS [Chemin]
FROM Successors
ORDER BY depth, node_id
OPTION (MAXRECURSION 100);
GO
