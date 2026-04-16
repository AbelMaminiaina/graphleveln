-- ============================================
-- AJOUT DES CONTRAINTES DE VALIDATION
-- Pour LineageGraphDB
-- ============================================
USE LineageGraphDB;
GO

-- ============================================
-- 1. CONTRAINTE: Les inputs doivent être différents entre eux
-- ============================================
PRINT 'Ajout de la contrainte: inputs différents...';

ALTER TABLE dbo.GrapheTransformation
ADD CONSTRAINT CK_Inputs_Differents
CHECK (
    -- input1 différent des autres inputs (si non NULL)
    (input1 IS NULL OR input1 <> COALESCE(input2, '')) AND
    (input1 IS NULL OR input1 <> COALESCE(input3, '')) AND
    (input1 IS NULL OR input1 <> COALESCE(input4, '')) AND
    -- input2 différent des autres inputs (si non NULL)
    (input2 IS NULL OR input2 <> COALESCE(input3, '')) AND
    (input2 IS NULL OR input2 <> COALESCE(input4, '')) AND
    -- input3 différent de input4 (si non NULL)
    (input3 IS NULL OR input3 <> COALESCE(input4, ''))
);
GO

PRINT 'Contrainte CK_Inputs_Differents créée avec succès';
GO

-- ============================================
-- 2. CONTRAINTE: Les outputs doivent être différents entre eux
-- ============================================
PRINT 'Ajout de la contrainte: outputs différents...';

ALTER TABLE dbo.GrapheTransformation
ADD CONSTRAINT CK_Outputs_Differents
CHECK (
    -- output1 différent des autres outputs (si non NULL)
    (output1 IS NULL OR output1 <> COALESCE(output2, '')) AND
    (output1 IS NULL OR output1 <> COALESCE(output3, '')) AND
    (output1 IS NULL OR output1 <> COALESCE(output4, '')) AND
    -- output2 différent des autres outputs (si non NULL)
    (output2 IS NULL OR output2 <> COALESCE(output3, '')) AND
    (output2 IS NULL OR output2 <> COALESCE(output4, '')) AND
    -- output3 différent de output4 (si non NULL)
    (output3 IS NULL OR output3 <> COALESCE(output4, ''))
);
GO

PRINT 'Contrainte CK_Outputs_Differents créée avec succès';
GO

-- ============================================
-- 3. CONTRAINTE: Pas d'auto-référence directe
-- (un nœud ne peut pas avoir ses propres outputs comme inputs)
-- ============================================
PRINT 'Ajout de la contrainte: pas d''auto-référence directe...';

ALTER TABLE dbo.GrapheTransformation
ADD CONSTRAINT CK_No_Self_Reference
CHECK (
    -- Aucun input ne peut être égal à un output de la même ligne
    (input1 IS NULL OR (
        input1 <> COALESCE(output1, '') AND
        input1 <> COALESCE(output2, '') AND
        input1 <> COALESCE(output3, '') AND
        input1 <> COALESCE(output4, '')
    )) AND
    (input2 IS NULL OR (
        input2 <> COALESCE(output1, '') AND
        input2 <> COALESCE(output2, '') AND
        input2 <> COALESCE(output3, '') AND
        input2 <> COALESCE(output4, '')
    )) AND
    (input3 IS NULL OR (
        input3 <> COALESCE(output1, '') AND
        input3 <> COALESCE(output2, '') AND
        input3 <> COALESCE(output3, '') AND
        input3 <> COALESCE(output4, '')
    )) AND
    (input4 IS NULL OR (
        input4 <> COALESCE(output1, '') AND
        input4 <> COALESCE(output2, '') AND
        input4 <> COALESCE(output3, '') AND
        input4 <> COALESCE(output4, '')
    ))
);
GO

PRINT 'Contrainte CK_No_Self_Reference créée avec succès';
GO

-- ============================================
-- 4. TRIGGER: Détection de cycles dans le graphe
-- (empêche les cycles indirects)
-- ============================================
PRINT 'Création du trigger de détection de cycles...';
GO

CREATE OR ALTER TRIGGER TR_Detect_Cycle
ON dbo.GrapheTransformation
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Pour chaque ligne insérée/modifiée, vérifier s'il y a un cycle
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
    -- Si un prédécesseur a un output qui est dans nos outputs, c'est un cycle
    ;WITH Predecessors AS (
        -- Base: les nœuds qui produisent nos inputs
        SELECT DISTINCT g.id, g.output1, g.output2, g.output3, g.output4,
               g.input1, g.input2, g.input3, g.input4,
               1 AS Level
        FROM dbo.GrapheTransformation g
        WHERE EXISTS (
            SELECT 1 FROM @InsertedInputs ii
            WHERE ii.InputValue IN (g.output1, g.output2, g.output3, g.output4)
        )
        AND g.id NOT IN (SELECT id FROM inserted)

        UNION ALL

        -- Récursion: les prédécesseurs des prédécesseurs
        SELECT DISTINCT g.id, g.output1, g.output2, g.output3, g.output4,
               g.input1, g.input2, g.input3, g.input4,
               p.Level + 1
        FROM dbo.GrapheTransformation g
        INNER JOIN Predecessors p ON
            p.input1 IN (g.output1, g.output2, g.output3, g.output4) OR
            p.input2 IN (g.output1, g.output2, g.output3, g.output4) OR
            p.input3 IN (g.output1, g.output2, g.output3, g.output4) OR
            p.input4 IN (g.output1, g.output2, g.output3, g.output4)
        WHERE p.Level < 100  -- Limite de profondeur pour éviter récursion infinie
        AND g.id NOT IN (SELECT id FROM inserted)
    )
    -- Vérifie si un prédécesseur consomme un de nos outputs (cycle!)
    SELECT @HasCycle = 1,
           @CycleMessage = 'Cycle détecté: le nœud ' + CAST(p.id AS VARCHAR(10)) +
                          ' crée une boucle dans le graphe de lignage'
    FROM Predecessors p
    WHERE EXISTS (
        SELECT 1 FROM @InsertedOutputs io
        WHERE io.OutputValue IN (p.input1, p.input2, p.input3, p.input4)
    )
    OPTION (MAXRECURSION 100);

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
-- 5. FONCTION: Vérification de cycle pour un nœud donné
-- ============================================
PRINT 'Création de la fonction de vérification de cycle...';
GO

CREATE OR ALTER FUNCTION dbo.fn_HasCycle(@NodeId INT)
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

    -- Cherche un chemin vers ce nœud via ses successeurs
    ;WITH Successors AS (
        SELECT DISTINCT g.id, g.input1, g.input2, g.input3, g.input4,
               g.output1, g.output2, g.output3, g.output4, 1 AS Level
        FROM dbo.GrapheTransformation g
        WHERE EXISTS (
            SELECT 1 FROM @Outputs o
            WHERE o.OutputValue IN (g.input1, g.input2, g.input3, g.input4)
        )
        AND g.id <> @NodeId

        UNION ALL

        SELECT DISTINCT g.id, g.input1, g.input2, g.input3, g.input4,
               g.output1, g.output2, g.output3, g.output4, s.Level + 1
        FROM dbo.GrapheTransformation g
        INNER JOIN Successors s ON
            s.output1 IN (g.input1, g.input2, g.input3, g.input4) OR
            s.output2 IN (g.input1, g.input2, g.input3, g.input4) OR
            s.output3 IN (g.input1, g.input2, g.input3, g.input4) OR
            s.output4 IN (g.input1, g.input2, g.input3, g.input4)
        WHERE s.Level < 100
        AND g.id <> @NodeId
    )
    SELECT @HasCycle = 1
    FROM Successors s
    WHERE s.id = @NodeId
    OPTION (MAXRECURSION 100);

    RETURN @HasCycle;
END;
GO

PRINT 'Fonction fn_HasCycle créée avec succès';
GO

-- ============================================
-- 6. VUE: Affichage des relations du graphe
-- ============================================
PRINT 'Création de la vue des relations...';
GO

CREATE OR ALTER VIEW dbo.vw_GraphRelations
AS
SELECT
    source.id AS SourceNodeId,
    source.transformation AS SourceTransformation,
    target.id AS TargetNodeId,
    target.transformation AS TargetTransformation,
    CASE
        WHEN source.output1 IN (target.input1, target.input2, target.input3, target.input4) THEN source.output1
        WHEN source.output2 IN (target.input1, target.input2, target.input3, target.input4) THEN source.output2
        WHEN source.output3 IN (target.input1, target.input2, target.input3, target.input4) THEN source.output3
        WHEN source.output4 IN (target.input1, target.input2, target.input3, target.input4) THEN source.output4
    END AS DataFlow
FROM dbo.GrapheTransformation source
INNER JOIN dbo.GrapheTransformation target ON
    source.output1 IN (target.input1, target.input2, target.input3, target.input4) OR
    source.output2 IN (target.input1, target.input2, target.input3, target.input4) OR
    source.output3 IN (target.input1, target.input2, target.input3, target.input4) OR
    source.output4 IN (target.input1, target.input2, target.input3, target.input4);
GO

PRINT 'Vue vw_GraphRelations créée avec succès';
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
GO

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
GO

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
GO

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
GO

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
GO

PRINT '';
PRINT '========== RÉSUMÉ DES CONTRAINTES ==========';
PRINT '1. CK_Inputs_Differents: Les inputs d''une ligne doivent être uniques';
PRINT '2. CK_Outputs_Differents: Les outputs d''une ligne doivent être uniques';
PRINT '3. CK_No_Self_Reference: Pas d''auto-référence directe';
PRINT '4. TR_Detect_Cycle: Trigger pour détecter les cycles indirects';
PRINT '5. fn_HasCycle: Fonction pour vérifier les cycles';
PRINT '6. vw_GraphRelations: Vue des relations du graphe';
PRINT '';
PRINT 'Toutes les contraintes ont été ajoutées avec succès!';
GO
