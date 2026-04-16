-- ============================================
-- SCRIPT: Obtenir les prédécesseurs d'une donnée
-- Usage: Remplacer @DataName par la donnée recherchée
-- ============================================

USE LineageGraphDB;
GO

DECLARE @DataName NVARCHAR(100) = 'DATA_10_O1';  -- << Modifier ici

PRINT '=== Predecesseurs de ' + @DataName + ' ===';
PRINT '';

;WITH Predecessors AS (
    -- Base: trouver le node qui produit cette donnée
    SELECT
        e.source_node_id AS node_id,
        n.transformation,
        n.id_type,
        n.proprietaire,
        e.data_name,
        1 AS depth,
        CAST(CAST(e.source_node_id AS VARCHAR(10)) + ' -> ' + CAST(e.target_node_id AS VARCHAR(10)) AS VARCHAR(MAX)) AS path
    FROM dbo.Edges e
    INNER JOIN dbo.Nodes n ON e.source_node_id = n.id
    WHERE e.data_name = @DataName

    UNION ALL

    -- Récursion: prédécesseurs des prédécesseurs
    SELECT
        e.source_node_id,
        n.transformation,
        n.id_type,
        n.proprietaire,
        e.data_name,
        p.depth + 1,
        CAST(e.source_node_id AS VARCHAR(10)) + ' -> ' + p.path
    FROM dbo.Edges e
    INNER JOIN dbo.Nodes n ON e.source_node_id = n.id
    INNER JOIN Predecessors p ON e.target_node_id = p.node_id
    WHERE p.depth < 10
    AND CHARINDEX(CAST(e.source_node_id AS VARCHAR(10)), p.path) = 0
)
SELECT DISTINCT
    depth AS [Depth],
    node_id AS [Node ID],
    transformation AS [Transformation],
    proprietaire AS [Proprietaire],
    data_name AS [Data],
    path AS [Chemin]
FROM Predecessors
ORDER BY depth, node_id
OPTION (MAXRECURSION 100);
GO
