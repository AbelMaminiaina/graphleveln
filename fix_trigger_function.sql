-- ============================================
-- CORRECTION DU TRIGGER ET DE LA FONCTION
-- Pour LineageGraphDB
-- ============================================
SET QUOTED_IDENTIFIER ON;
GO

USE LineageGraphDB;
GO

-- Supprimer l'ancien trigger s'il existe
IF EXISTS (SELECT * FROM sys.triggers WHERE name = 'TR_Detect_Cycle')
    DROP TRIGGER TR_Detect_Cycle;
GO

-- Supprimer l'ancienne fonction si elle existe
IF EXISTS (SELECT * FROM sys.objects WHERE name = 'fn_HasCycle' AND type = 'FN')
    DROP FUNCTION dbo.fn_HasCycle;
GO

-- ============================================
-- TRIGGER: Détection de cycles dans le graphe
-- (empêche les cycles indirects)
-- ============================================
PRINT 'Création du trigger de détection de cycles...';
GO

CREATE TRIGGER TR_Detect_Cycle
ON dbo.GrapheTransformation
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @HasCycle BIT = 0;
    DECLARE @CycleMessage NVARCHAR(500);

    -- Collecte des outputs de la ligne insérée/modifiée
    DECLARE @InsertedOutputs TABLE (OutputValue NVARCHAR(100));
    INSERT INTO @InsertedOutputs
    SELECT output1 FROM inserted WHERE output1 IS NOT NULL
    UNION SELECT output2 FROM inserted WHERE output2 IS NOT NULL
    UNION SELECT output3 FROM inserted WHERE output3 IS NOT NULL
    UNION SELECT output4 FROM inserted WHERE output4 IS NOT NULL;

    -- Collecte des inputs de la ligne insérée/modifiée
    DECLARE @InsertedInputs TABLE (InputValue NVARCHAR(100));
    INSERT INTO @InsertedInputs
    SELECT input1 FROM inserted WHERE input1 IS NOT NULL
    UNION SELECT input2 FROM inserted WHERE input2 IS NOT NULL
    UNION SELECT input3 FROM inserted WHERE input3 IS NOT NULL
    UNION SELECT input4 FROM inserted WHERE input4 IS NOT NULL;

    -- CTE récursif pour trouver tous les prédécesseurs (upstream)
    -- Sans DISTINCT dans la partie récursive
    ;WITH Predecessors AS (
        -- Base: les nœuds qui produisent nos inputs
        SELECT g.id, g.output1, g.output2, g.output3, g.output4,
               g.input1, g.input2, g.input3, g.input4,
               1 AS Level
        FROM dbo.GrapheTransformation g
        WHERE EXISTS (
            SELECT 1 FROM @InsertedInputs ii
            WHERE ii.InputValue IN (g.output1, g.output2, g.output3, g.output4)
        )
        AND g.id NOT IN (SELECT id FROM inserted)

        UNION ALL

        -- Récursion: les prédécesseurs des prédécesseurs (sans DISTINCT)
        SELECT g.id, g.output1, g.output2, g.output3, g.output4,
               g.input1, g.input2, g.input3, g.input4,
               p.Level + 1
        FROM dbo.GrapheTransformation g
        INNER JOIN Predecessors p ON
            (p.input1 IS NOT NULL AND p.input1 IN (g.output1, g.output2, g.output3, g.output4)) OR
            (p.input2 IS NOT NULL AND p.input2 IN (g.output1, g.output2, g.output3, g.output4)) OR
            (p.input3 IS NOT NULL AND p.input3 IN (g.output1, g.output2, g.output3, g.output4)) OR
            (p.input4 IS NOT NULL AND p.input4 IN (g.output1, g.output2, g.output3, g.output4))
        WHERE p.Level < 50  -- Limite de profondeur
        AND g.id NOT IN (SELECT id FROM inserted)
    )
    -- Vérifie si un prédécesseur consomme un de nos outputs (cycle!)
    SELECT TOP 1 @HasCycle = 1,
           @CycleMessage = 'Cycle détecté: le nœud ' + CAST(p.id AS VARCHAR(10)) +
                          ' crée une boucle dans le graphe de lignage'
    FROM (SELECT DISTINCT id, input1, input2, input3, input4 FROM Predecessors) p
    WHERE EXISTS (
        SELECT 1 FROM @InsertedOutputs io
        WHERE io.OutputValue IN (p.input1, p.input2, p.input3, p.input4)
    )
    OPTION (MAXRECURSION 50);

    IF @HasCycle = 1
    BEGIN
        RAISERROR(@CycleMessage, 16, 1);
        ROLLBACK TRANSACTION;
        RETURN;
    END
END;
GO

PRINT 'Trigger TR_Detect_Cycle créé avec succès';
GO

-- ============================================
-- FONCTION: Vérification de cycle pour un nœud donné
-- ============================================
PRINT 'Création de la fonction de vérification de cycle...';
GO

CREATE FUNCTION dbo.fn_HasCycle(@NodeId INT)
RETURNS BIT
AS
BEGIN
    DECLARE @HasCycle BIT = 0;

    -- Récupère les outputs du nœud
    DECLARE @Outputs TABLE (OutputValue NVARCHAR(100));
    INSERT INTO @Outputs
    SELECT output1 FROM dbo.GrapheTransformation WHERE id = @NodeId AND output1 IS NOT NULL
    UNION SELECT output2 FROM dbo.GrapheTransformation WHERE id = @NodeId AND output2 IS NOT NULL
    UNION SELECT output3 FROM dbo.GrapheTransformation WHERE id = @NodeId AND output3 IS NOT NULL
    UNION SELECT output4 FROM dbo.GrapheTransformation WHERE id = @NodeId AND output4 IS NOT NULL;

    -- Cherche un chemin vers ce nœud via ses successeurs (sans DISTINCT dans récursion)
    ;WITH Successors AS (
        SELECT g.id, g.input1, g.input2, g.input3, g.input4,
               g.output1, g.output2, g.output3, g.output4, 1 AS Level
        FROM dbo.GrapheTransformation g
        WHERE EXISTS (
            SELECT 1 FROM @Outputs o
            WHERE o.OutputValue IN (g.input1, g.input2, g.input3, g.input4)
        )
        AND g.id <> @NodeId

        UNION ALL

        SELECT g.id, g.input1, g.input2, g.input3, g.input4,
               g.output1, g.output2, g.output3, g.output4, s.Level + 1
        FROM dbo.GrapheTransformation g
        INNER JOIN Successors s ON
            (s.output1 IS NOT NULL AND s.output1 IN (g.input1, g.input2, g.input3, g.input4)) OR
            (s.output2 IS NOT NULL AND s.output2 IN (g.input1, g.input2, g.input3, g.input4)) OR
            (s.output3 IS NOT NULL AND s.output3 IN (g.input1, g.input2, g.input3, g.input4)) OR
            (s.output4 IS NOT NULL AND s.output4 IN (g.input1, g.input2, g.input3, g.input4))
        WHERE s.Level < 50
        AND g.id <> @NodeId
    )
    SELECT @HasCycle = 1
    FROM (SELECT DISTINCT id FROM Successors) s
    WHERE s.id = @NodeId
    OPTION (MAXRECURSION 50);

    RETURN @HasCycle;
END;
GO

PRINT 'Fonction fn_HasCycle créée avec succès';
GO

-- ============================================
-- TESTS DE VALIDATION
-- ============================================
PRINT '';
PRINT '========== TESTS DE VALIDATION ==========';
PRINT '';

-- Test 1: Tentative d'insertion avec inputs dupliqués (doit échouer)
PRINT 'Test 1: Insertion avec inputs dupliqués...';
BEGIN TRY
    INSERT INTO dbo.GrapheTransformation (id_type, input1, input2, transformation, output1)
    VALUES (1, 'SAME_DATA', 'SAME_DATA', 'Test_Duplicate_Input', 'OUTPUT_TEST');
    PRINT 'ERREUR: L''insertion aurait dû échouer!';
END TRY
BEGIN CATCH
    PRINT 'OK: Insertion refusée - ' + ERROR_MESSAGE();
END CATCH

-- Test 2: Tentative d'insertion avec outputs dupliqués (doit échouer)
PRINT 'Test 2: Insertion avec outputs dupliqués...';
BEGIN TRY
    INSERT INTO dbo.GrapheTransformation (id_type, input1, transformation, output1, output2)
    VALUES (1, 'INPUT_TEST', 'Test_Duplicate_Output', 'SAME_OUTPUT', 'SAME_OUTPUT');
    PRINT 'ERREUR: L''insertion aurait dû échouer!';
END TRY
BEGIN CATCH
    PRINT 'OK: Insertion refusée - ' + ERROR_MESSAGE();
END CATCH

-- Test 3: Tentative d'auto-référence (doit échouer)
PRINT 'Test 3: Insertion avec auto-référence...';
BEGIN TRY
    INSERT INTO dbo.GrapheTransformation (id_type, input1, transformation, output1)
    VALUES (1, 'SELF_REF', 'Test_Self_Reference', 'SELF_REF');
    PRINT 'ERREUR: L''insertion aurait dû échouer!';
END TRY
BEGIN CATCH
    PRINT 'OK: Insertion refusée - ' + ERROR_MESSAGE();
END CATCH

-- Test 4: Insertion valide (doit réussir)
PRINT 'Test 4: Insertion valide...';
BEGIN TRY
    INSERT INTO dbo.GrapheTransformation (id_type, input1, input2, transformation, output1, output2, proprietaire)
    VALUES (1, 'INPUT_A', 'INPUT_B', 'Test_Valid_Insert', 'OUTPUT_X', 'OUTPUT_Y', 'IT');
    PRINT 'OK: Insertion réussie';
    -- Nettoyage
    DELETE FROM dbo.GrapheTransformation WHERE transformation = 'Test_Valid_Insert';
END TRY
BEGIN CATCH
    PRINT 'ERREUR: ' + ERROR_MESSAGE();
END CATCH

-- Test 5: Un input peut être un output d'un autre nœud (doit réussir)
PRINT 'Test 5: Input = Output d''un autre nœud (relation valide)...';
BEGIN TRY
    -- Créer un nœud source
    INSERT INTO dbo.GrapheTransformation (id_type, transformation, output1, proprietaire)
    VALUES (1, 'Test_Source_Node', 'SHARED_DATA', 'IT');

    -- Créer un nœud qui consomme cet output
    INSERT INTO dbo.GrapheTransformation (id_type, input1, transformation, output1, proprietaire)
    VALUES (1, 'SHARED_DATA', 'Test_Consumer_Node', 'NEW_OUTPUT', 'IT');

    PRINT 'OK: Relation prédécesseur/successeur créée';

    -- Nettoyage
    DELETE FROM dbo.GrapheTransformation WHERE transformation IN ('Test_Source_Node', 'Test_Consumer_Node');
END TRY
BEGIN CATCH
    PRINT 'ERREUR: ' + ERROR_MESSAGE();
END CATCH

PRINT '';
PRINT '========== RÉSUMÉ ==========';
PRINT 'Trigger et fonction corrigés avec succès!';
GO

-- Afficher les contraintes existantes
PRINT '';
PRINT '========== CONTRAINTES ACTIVES ==========';
SELECT
    name AS NomContrainte,
    type_desc AS TypeContrainte
FROM sys.objects
WHERE parent_object_id = OBJECT_ID('dbo.GrapheTransformation')
AND type IN ('C', 'D', 'F', 'UQ')
ORDER BY type_desc, name;
GO

-- Afficher les triggers
PRINT '';
PRINT '========== TRIGGERS ACTIFS ==========';
SELECT name AS NomTrigger
FROM sys.triggers
WHERE parent_id = OBJECT_ID('dbo.GrapheTransformation');
GO
