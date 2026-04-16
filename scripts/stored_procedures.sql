-- ============================================
-- PROCEDURES STOCKEES POUR L'APPLICATION
-- Base: LineageGraphDB
-- ============================================

USE LineageGraphDB;
GO

-- ============================================
-- 1. Recherche par data_name
-- ============================================
CREATE OR ALTER PROCEDURE dbo.sp_SearchByData
    @DataName NVARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT
        n.id,
        n.transformation,
        n.proprietaire,
        n.id_type,
        (SELECT COUNT(*) FROM dbo.Edges WHERE source_node_id = n.id) AS SuccessorCount,
        (SELECT COUNT(*) FROM dbo.Edges WHERE target_node_id = n.id) AS PredecessorCount
    FROM dbo.Nodes n
    INNER JOIN dbo.Edges e ON n.id = e.source_node_id OR n.id = e.target_node_id
    WHERE e.data_name LIKE '%' + @DataName + '%'
    ORDER BY n.id;
END;
GO

PRINT 'Procedure sp_SearchByData creee';
GO

-- ============================================
-- 2. Successeurs recursifs
-- ============================================
CREATE OR ALTER PROCEDURE dbo.sp_GetSuccessors
    @NodeId INT,
    @MaxDepth INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Successors AS (
        -- Base: successeurs directs
        SELECT
            e.target_node_id AS node_id,
            n.transformation,
            n.id_type,
            n.proprietaire,
            e.data_name,
            1 AS depth,
            CAST(CAST(@NodeId AS VARCHAR(10)) + ' -> ' + CAST(e.target_node_id AS VARCHAR(10)) AS VARCHAR(MAX)) AS path
        FROM dbo.Edges e
        INNER JOIN dbo.Nodes n ON e.target_node_id = n.id
        WHERE e.source_node_id = @NodeId

        UNION ALL

        -- Recursion: successeurs des successeurs
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
        WHERE s.depth < @MaxDepth
        AND CHARINDEX(CAST(e.target_node_id AS VARCHAR(10)), s.path) = 0
    )
    SELECT DISTINCT node_id, transformation, id_type, proprietaire, data_name, depth, path
    FROM Successors
    ORDER BY depth, node_id
    OPTION (MAXRECURSION 100);
END;
GO

PRINT 'Procedure sp_GetSuccessors creee';
GO

-- ============================================
-- 3. Predecesseurs recursifs
-- ============================================
CREATE OR ALTER PROCEDURE dbo.sp_GetPredecessors
    @NodeId INT,
    @MaxDepth INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH Predecessors AS (
        -- Base: predecesseurs directs
        SELECT
            e.source_node_id AS node_id,
            n.transformation,
            n.id_type,
            n.proprietaire,
            e.data_name,
            1 AS depth,
            CAST(CAST(e.source_node_id AS VARCHAR(10)) + ' -> ' + CAST(@NodeId AS VARCHAR(10)) AS VARCHAR(MAX)) AS path
        FROM dbo.Edges e
        INNER JOIN dbo.Nodes n ON e.source_node_id = n.id
        WHERE e.target_node_id = @NodeId

        UNION ALL

        -- Recursion: predecesseurs des predecesseurs
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
        WHERE p.depth < @MaxDepth
        AND CHARINDEX(CAST(e.source_node_id AS VARCHAR(10)), p.path) = 0
    )
    SELECT DISTINCT node_id, transformation, id_type, proprietaire, data_name, depth, path
    FROM Predecessors
    ORDER BY depth, node_id
    OPTION (MAXRECURSION 100);
END;
GO

PRINT 'Procedure sp_GetPredecessors creee';
GO

-- ============================================
-- TEST
-- ============================================
PRINT '';
PRINT '========== TEST sp_GetSuccessors(1) ==========';
EXEC dbo.sp_GetSuccessors @NodeId = 1, @MaxDepth = 3;

PRINT '';
PRINT '========== TEST sp_GetPredecessors(10) ==========';
EXEC dbo.sp_GetPredecessors @NodeId = 10, @MaxDepth = 3;
GO
