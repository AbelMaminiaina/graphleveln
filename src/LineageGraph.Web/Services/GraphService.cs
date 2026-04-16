using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using LineageGraph.Web.Data;
using LineageGraph.Web.Models;

namespace LineageGraph.Web.Services;

public interface IGraphService
{
    Task<List<NodeSearchResult>> SearchByDataNameAsync(string dataName);
    Task<Node?> GetNodeByIdAsync(int id);
    Task<List<LineageItem>> GetSuccessorsAsync(int nodeId, int maxDepth = 10);
    Task<List<LineageItem>> GetPredecessorsAsync(int nodeId, int maxDepth = 10);
}

public class GraphService : IGraphService
{
    private readonly LineageDbContext _context;
    private readonly string _connectionString;

    public GraphService(LineageDbContext context, IConfiguration configuration)
    {
        _context = context;
        _connectionString = configuration.GetConnectionString("LineageDb") ?? "";
    }

    public async Task<List<NodeSearchResult>> SearchByDataNameAsync(string dataName)
    {
        var results = await _context.Nodes
            .Where(n => _context.Edges.Any(e =>
                (e.SourceNodeId == n.Id || e.TargetNodeId == n.Id) &&
                e.DataName.Contains(dataName)))
            .Select(n => new NodeSearchResult
            {
                Id = n.Id,
                Transformation = n.Transformation,
                Proprietaire = n.Proprietaire,
                IdType = n.IdType,
                SuccessorCount = _context.Edges.Count(e => e.SourceNodeId == n.Id),
                PredecessorCount = _context.Edges.Count(e => e.TargetNodeId == n.Id)
            })
            .ToListAsync();

        return results;
    }

    public async Task<Node?> GetNodeByIdAsync(int id)
    {
        return await _context.Nodes.FindAsync(id);
    }

    public async Task<List<LineageItem>> GetSuccessorsAsync(int nodeId, int maxDepth = 10)
    {
        var results = new List<LineageItem>();

        var sql = @"
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
            ORDER BY depth, node_id
            OPTION (MAXRECURSION 100);";

        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@NodeId", nodeId);
        command.Parameters.AddWithValue("@MaxDepth", maxDepth);

        using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new LineageItem
            {
                NodeId = reader.GetInt32(0),
                Transformation = reader.GetString(1),
                IdType = reader.GetInt32(2),
                Proprietaire = reader.IsDBNull(3) ? null : reader.GetString(3),
                DataName = reader.GetString(4),
                Depth = reader.GetInt32(5),
                Path = reader.GetString(6)
            });
        }

        return results;
    }

    public async Task<List<LineageItem>> GetPredecessorsAsync(int nodeId, int maxDepth = 10)
    {
        var results = new List<LineageItem>();

        var sql = @"
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
            ORDER BY depth, node_id
            OPTION (MAXRECURSION 100);";

        using var connection = new SqlConnection(_connectionString);
        await connection.OpenAsync();

        using var command = new SqlCommand(sql, connection);
        command.Parameters.AddWithValue("@NodeId", nodeId);
        command.Parameters.AddWithValue("@MaxDepth", maxDepth);

        using var reader = await command.ExecuteReaderAsync();
        while (await reader.ReadAsync())
        {
            results.Add(new LineageItem
            {
                NodeId = reader.GetInt32(0),
                Transformation = reader.GetString(1),
                IdType = reader.GetInt32(2),
                Proprietaire = reader.IsDBNull(3) ? null : reader.GetString(3),
                DataName = reader.GetString(4),
                Depth = reader.GetInt32(5),
                Path = reader.GetString(6)
            });
        }

        return results;
    }
}
