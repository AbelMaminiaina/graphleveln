# LineageGraph - Application de Visualisation de Lignage

## Structure de la Base de Données

### Modèle Original (1 table)
```
GrapheTransformation (id, input1-4, transformation, output1-4, proprietaire, date_creation)
```

### Modèle Optimisé (2 tables)
```
Nodes (id, transformation, id_type, proprietaire, date_creation)
Edges (id, source_node_id, target_node_id, data_name)
```

### Statistiques
| Table | Count |
|-------|-------|
| GrapheTransformation | 10 000 |
| Nodes | 10 000 |
| Edges | 13 997 |

> **Note:** Il y a plus d'Edges que de Nodes car un Node peut avoir plusieurs outputs (1-4), et chaque output crée un Edge.

---

## Scripts SQL

### 1. Création de la base (create_graphe_db.sql)

```sql
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
```

### 2. Contraintes de validation (add_constraints.sql)

```sql
USE LineageGraphDB;
GO

-- Contrainte: inputs différents entre eux
ALTER TABLE dbo.GrapheTransformation
ADD CONSTRAINT CK_Inputs_Differents
CHECK (
    (input1 IS NULL OR input1 <> COALESCE(input2, '')) AND
    (input1 IS NULL OR input1 <> COALESCE(input3, '')) AND
    (input1 IS NULL OR input1 <> COALESCE(input4, '')) AND
    (input2 IS NULL OR input2 <> COALESCE(input3, '')) AND
    (input2 IS NULL OR input2 <> COALESCE(input4, '')) AND
    (input3 IS NULL OR input3 <> COALESCE(input4, ''))
);
GO

-- Contrainte: outputs différents entre eux
ALTER TABLE dbo.GrapheTransformation
ADD CONSTRAINT CK_Outputs_Differents
CHECK (
    (output1 IS NULL OR output1 <> COALESCE(output2, '')) AND
    (output1 IS NULL OR output1 <> COALESCE(output3, '')) AND
    (output1 IS NULL OR output1 <> COALESCE(output4, '')) AND
    (output2 IS NULL OR output2 <> COALESCE(output3, '')) AND
    (output2 IS NULL OR output2 <> COALESCE(output4, '')) AND
    (output3 IS NULL OR output3 <> COALESCE(output4, ''))
);
GO

-- Contrainte: pas d'auto-référence
ALTER TABLE dbo.GrapheTransformation
ADD CONSTRAINT CK_No_Self_Reference
CHECK (
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
```

### 3. Migration vers modèle 2 tables (migrate_to_graph.sql)

```sql
USE LineageGraphDB;
GO

-- TABLE NODES
CREATE TABLE dbo.Nodes (
    id INT PRIMARY KEY IDENTITY(1,1),
    transformation NVARCHAR(255) NOT NULL,
    id_type INT NOT NULL,
    proprietaire NVARCHAR(100),
    date_creation DATETIME2 DEFAULT GETDATE()
);
GO

-- TABLE EDGES
CREATE TABLE dbo.Edges (
    id INT PRIMARY KEY IDENTITY(1,1),
    source_node_id INT NOT NULL,
    target_node_id INT NOT NULL,
    data_name NVARCHAR(100) NOT NULL,
    CONSTRAINT FK_Edge_Source FOREIGN KEY (source_node_id) REFERENCES dbo.Nodes(id),
    CONSTRAINT FK_Edge_Target FOREIGN KEY (target_node_id) REFERENCES dbo.Nodes(id),
    CONSTRAINT CK_No_Self_Loop CHECK (source_node_id <> target_node_id)
);
GO

-- Index
CREATE INDEX IX_Edges_Source ON dbo.Edges(source_node_id);
CREATE INDEX IX_Edges_Target ON dbo.Edges(target_node_id);
CREATE INDEX IX_Edges_DataName ON dbo.Edges(data_name);
GO

-- Migration des nodes
SET IDENTITY_INSERT dbo.Nodes ON;
INSERT INTO dbo.Nodes (id, transformation, id_type, proprietaire, date_creation)
SELECT id, transformation, id_type, proprietaire, date_creation
FROM dbo.GrapheTransformation;
SET IDENTITY_INSERT dbo.Nodes OFF;
GO

-- Migration des edges
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
GO
```

### 4. Procédures stockées (stored_procedures.sql)

```sql
USE LineageGraphDB;
GO

-- Recherche par data_name
CREATE OR ALTER PROCEDURE dbo.sp_SearchByData
    @DataName NVARCHAR(100)
AS
BEGIN
    SELECT DISTINCT
        n.id,
        n.transformation,
        n.proprietaire,
        n.id_type
    FROM dbo.Nodes n
    INNER JOIN dbo.Edges e ON n.id = e.source_node_id OR n.id = e.target_node_id
    WHERE e.data_name LIKE '%' + @DataName + '%';
END;
GO

-- Successeurs récursifs
CREATE OR ALTER PROCEDURE dbo.sp_GetSuccessors
    @NodeId INT,
    @MaxDepth INT = 10
AS
BEGIN
    ;WITH Successors AS (
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
    ORDER BY depth, node_id;
END;
GO

-- Prédécesseurs récursifs
CREATE OR ALTER PROCEDURE dbo.sp_GetPredecessors
    @NodeId INT,
    @MaxDepth INT = 10
AS
BEGIN
    ;WITH Predecessors AS (
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
    ORDER BY depth, node_id;
END;
GO
```

### 5. Vue Lineage (i, T, o)

```sql
CREATE OR ALTER VIEW dbo.vw_Lineage_iTo
AS
SELECT
    id,
    CONCAT(
        COALESCE(input1, ''),
        CASE WHEN input2 IS NOT NULL THEN ', ' + input2 ELSE '' END,
        CASE WHEN input3 IS NOT NULL THEN ', ' + input3 ELSE '' END,
        CASE WHEN input4 IS NOT NULL THEN ', ' + input4 ELSE '' END
    ) AS i,
    transformation AS T,
    CONCAT(
        COALESCE(output1, ''),
        CASE WHEN output2 IS NOT NULL THEN ', ' + output2 ELSE '' END,
        CASE WHEN output3 IS NOT NULL THEN ', ' + output3 ELSE '' END,
        CASE WHEN output4 IS NOT NULL THEN ', ' + output4 ELSE '' END
    ) AS o
FROM dbo.GrapheTransformation;
GO
```

### 6. Successeurs par Data (get_successors_by_data.sql)

```sql
USE LineageGraphDB;
GO

DECLARE @DataName NVARCHAR(100) = 'DATA_1_O1';  -- << Modifier ici

PRINT '=== Successeurs de ' + @DataName + ' ===';

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
```

### 7. Prédécesseurs par Data (get_predecessors_by_data.sql)

```sql
USE LineageGraphDB;
GO

DECLARE @DataName NVARCHAR(100) = 'DATA_10_O1';  -- << Modifier ici

PRINT '=== Predecesseurs de ' + @DataName + ' ===';

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
```

---

## Application .NET MVC

### Structure du projet
```
src/LineageGraph.Web/
├── Controllers/
│   ├── HomeController.cs       # Écran 1: Recherche
│   └── GraphController.cs      # Écran 2: Graphe
├── Models/
│   ├── Node.cs
│   ├── Edge.cs
│   ├── SearchViewModel.cs
│   └── GraphViewModel.cs
├── Data/
│   └── LineageDbContext.cs
├── Services/
│   └── GraphService.cs
├── Views/
│   ├── Home/Index.cshtml       # Formulaire de recherche
│   ├── Graph/Details.cshtml    # Tableaux successeurs/prédécesseurs
│   └── Shared/_Layout.cshtml
├── appsettings.json
├── Program.cs
└── LineageGraph.Web.csproj
```

### Lancer l'application

```bash
cd src/LineageGraph.Web
dotnet restore
dotnet build
dotnet run
```

Puis ouvrir: **http://localhost:5000**

### Connection String (appsettings.json)
```json
{
  "ConnectionStrings": {
    "LineageDb": "Server=DESKTOP-M4OVEKQ\\SQLEXPRESS02;Database=LineageGraphDB;Trusted_Connection=True;TrustServerCertificate=True;"
  }
}
```

---

## Exécution des scripts SQL

```bash
# Connexion à SQL Server
sqlcmd -S "DESKTOP-M4OVEKQ\SQLEXPRESS02" -E

# Exécuter un script
sqlcmd -S "DESKTOP-M4OVEKQ\SQLEXPRESS02" -d LineageGraphDB -i "scripts/migrate_to_graph.sql" -E

# Exécuter les procédures stockées
sqlcmd -S "DESKTOP-M4OVEKQ\SQLEXPRESS02" -d LineageGraphDB -i "scripts/stored_procedures.sql" -E

# Obtenir les successeurs de DATA_1_O1
sqlcmd -S "DESKTOP-M4OVEKQ\SQLEXPRESS02" -d LineageGraphDB -i "scripts/get_successors_by_data.sql" -E

# Obtenir les prédécesseurs de DATA_10_O1
sqlcmd -S "DESKTOP-M4OVEKQ\SQLEXPRESS02" -d LineageGraphDB -i "scripts/get_predecessors_by_data.sql" -E
```

---

## Structure des fichiers

```
C:\Users\amami\GitHub\Lineage\
├── README.md
├── scripts/
│   ├── migrate_to_graph.sql
│   ├── stored_procedures.sql
│   ├── get_successors_by_data.sql
│   └── get_predecessors_by_data.sql
├── create_graphe_db.sql
├── add_constraints.sql
└── src/
    └── LineageGraph.Web/
        └── ... (application .NET MVC)
```
