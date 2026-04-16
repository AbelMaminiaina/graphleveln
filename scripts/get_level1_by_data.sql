-- ============================================
-- SCRIPT: Obtenir les successeurs et prédécesseurs NIVEAU 1
-- Usage: Remplacer @DataName par la donnée recherchée
-- ============================================

USE LineageGraphDB;
GO

DECLARE @DataName NVARCHAR(100) = 'DATA_5_O1';  -- << Modifier ici

-- ============================================
-- SUCCESSEURS NIVEAU 1 (directs)
-- Nodes qui consomment cette donnée en input
-- ============================================
PRINT '=== Successeurs NIVEAU 1 de ' + @DataName + ' ===';
PRINT '';

SELECT
    e.target_node_id AS [Node ID],
    n.transformation AS [Transformation],
    n.id_type AS [Type],
    n.proprietaire AS [Proprietaire],
    e.data_name AS [Data]
FROM dbo.Edges e
INNER JOIN dbo.Nodes n ON e.target_node_id = n.id
WHERE e.data_name = @DataName
ORDER BY e.target_node_id;

-- ============================================
-- PREDECESSEURS NIVEAU 1 (directs)
-- Node qui produit cette donnée en output
-- ============================================
PRINT '';
PRINT '=== Predecesseur NIVEAU 1 de ' + @DataName + ' ===';
PRINT '';

SELECT DISTINCT
    e.source_node_id AS [Node ID],
    n.transformation AS [Transformation],
    n.id_type AS [Type],
    n.proprietaire AS [Proprietaire],
    e.data_name AS [Data]
FROM dbo.Edges e
INNER JOIN dbo.Nodes n ON e.source_node_id = n.id
WHERE e.data_name = @DataName
ORDER BY e.source_node_id;
GO
