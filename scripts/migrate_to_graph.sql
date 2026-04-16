-- ============================================
-- MIGRATION: Split en 2 tables (Nodes + Edges)
-- Base: LineageGraphDB
-- ============================================

USE LineageGraphDB;
GO

-- ============================================
-- 1. TABLE NODES (Transformations)
-- ============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Nodes')
BEGIN
    CREATE TABLE dbo.Nodes (
        id INT PRIMARY KEY IDENTITY(1,1),
        transformation NVARCHAR(255) NOT NULL,
        id_type INT NOT NULL,
        proprietaire NVARCHAR(100),
        date_creation DATETIME2 DEFAULT GETDATE()
    );
    PRINT 'Table Nodes creee';
END
ELSE
    PRINT 'Table Nodes existe deja';
GO

-- ============================================
-- 2. TABLE EDGES (Relations entre nodes)
-- ============================================
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'Edges')
BEGIN
    CREATE TABLE dbo.Edges (
        id INT PRIMARY KEY IDENTITY(1,1),
        source_node_id INT NOT NULL,
        target_node_id INT NOT NULL,
        data_name NVARCHAR(100) NOT NULL,
        CONSTRAINT FK_Edge_Source FOREIGN KEY (source_node_id) REFERENCES dbo.Nodes(id),
        CONSTRAINT FK_Edge_Target FOREIGN KEY (target_node_id) REFERENCES dbo.Nodes(id),
        CONSTRAINT CK_No_Self_Loop CHECK (source_node_id <> target_node_id)
    );
    PRINT 'Table Edges creee';
END
ELSE
    PRINT 'Table Edges existe deja';
GO

-- Index pour recherches rapides
IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Edges_Source')
    CREATE INDEX IX_Edges_Source ON dbo.Edges(source_node_id);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Edges_Target')
    CREATE INDEX IX_Edges_Target ON dbo.Edges(target_node_id);

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE name = 'IX_Edges_DataName')
    CREATE INDEX IX_Edges_DataName ON dbo.Edges(data_name);

PRINT 'Index crees';
GO

-- ============================================
-- 3. MIGRATION DES DONNÉES
-- ============================================
IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Nodes)
BEGIN
    PRINT 'Migration des nodes...';

    SET IDENTITY_INSERT dbo.Nodes ON;
    INSERT INTO dbo.Nodes (id, transformation, id_type, proprietaire, date_creation)
    SELECT id, transformation, id_type, proprietaire, date_creation
    FROM dbo.GrapheTransformation;
    SET IDENTITY_INSERT dbo.Nodes OFF;

    PRINT 'Nodes migres: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
END
ELSE
    PRINT 'Nodes deja migres';
GO

IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.Edges)
BEGIN
    PRINT 'Migration des edges...';

    INSERT INTO dbo.Edges (source_node_id, target_node_id, data_name)
    SELECT DISTINCT
        src.id,
        tgt.id,
        CASE
            WHEN src.output1 IN (tgt.input1, tgt.input2, tgt.input3, tgt.input4) THEN src.output1
            WHEN src.output2 IN (tgt.input1, tgt.input2, tgt.input3, tgt.input4) THEN src.output2
            WHEN src.output3 IN (tgt.input1, tgt.input2, tgt.input3, tgt.input4) THEN src.output3
            WHEN src.output4 IN (tgt.input1, tgt.input2, tgt.input3, tgt.input4) THEN src.output4
        END
    FROM dbo.GrapheTransformation src
    INNER JOIN dbo.GrapheTransformation tgt ON
        src.output1 IN (tgt.input1, tgt.input2, tgt.input3, tgt.input4) OR
        src.output2 IN (tgt.input1, tgt.input2, tgt.input3, tgt.input4) OR
        src.output3 IN (tgt.input1, tgt.input2, tgt.input3, tgt.input4) OR
        src.output4 IN (tgt.input1, tgt.input2, tgt.input3, tgt.input4);

    PRINT 'Edges migres: ' + CAST(@@ROWCOUNT AS VARCHAR(10));
END
ELSE
    PRINT 'Edges deja migres';
GO

-- ============================================
-- 4. STATISTIQUES
-- ============================================
PRINT '';
PRINT '========== STATISTIQUES ==========';
SELECT 'Nodes' AS [Table], COUNT(*) AS [Count] FROM dbo.Nodes
UNION ALL
SELECT 'Edges', COUNT(*) FROM dbo.Edges;
GO

PRINT '';
PRINT 'Migration terminee avec succes!';
GO
