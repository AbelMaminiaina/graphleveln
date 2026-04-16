using Microsoft.EntityFrameworkCore;
using Microsoft.Data.SqlClient;
using LineageGraph.Web.Data;
using LineageGraph.Web.Models;

namespace LineageGraph.Web.Services;

public interface IGraphService
{
    Task<List<NodeSearchResult>> SearchByInputsAsync(string? input1, string? input2, string? input3, string? input4);
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

    public async Task<List<NodeSearchResult>> SearchByInputsAsync(string? input1, string? input2, string? input3, string? input4)
    {
        // Build dynamic query based on provided inputs
        var query = _context.Nodes.AsQueryable();

        // Get all edges that match any of the inputs
        var matchingNodeIds = new List<int>();

        if (!string.IsNullOrWhiteSpace(input1) || !string.IsNullOrWhiteSpace(input2) ||
            !string.IsNullOrWhiteSpace(input3) || !string.IsNullOrWhiteSpace(input4))
        {
            var edgeQuery = _context.Edges.AsQueryable();

            if (!string.IsNullOrWhiteSpace(input1))
                edgeQuery = edgeQuery.Where(e => e.DataName.Contains(input1));
            else if (!string.IsNullOrWhiteSpace(input2))
                edgeQuery = edgeQuery.Where(e => e.DataName.Contains(input2));
            else if (!string.IsNullOrWhiteSpace(input3))
                edgeQuery = edgeQuery.Where(e => e.DataName.Contains(input3));
            else if (!string.IsNullOrWhiteSpace(input4))
                edgeQuery = edgeQuery.Where(e => e.DataName.Contains(input4));

            // If multiple inputs provided, use AND logic
            var inputs = new List<string>();
            if (!string.IsNullOrWhiteSpace(input1)) inputs.Add(input1);
            if (!string.IsNullOrWhiteSpace(input2)) inputs.Add(input2);
            if (!string.IsNullOrWhiteSpace(input3)) inputs.Add(input3);
            if (!string.IsNullOrWhiteSpace(input4)) inputs.Add(input4);

            if (inputs.Count > 0)
            {
                // Get nodes that match ANY of the inputs
                matchingNodeIds = await _context.Edges
                    .Where(e => inputs.Any(i => e.DataName.Contains(i)))
                    .Select(e => e.SourceNodeId)
                    .Union(
                        _context.Edges
                            .Where(e => inputs.Any(i => e.DataName.Contains(i)))
                            .Select(e => e.TargetNodeId)
                    )
                    .Distinct()
                    .ToListAsync();
            }
        }

        if (matchingNodeIds.Count == 0)
            return new List<NodeSearchResult>();

        var results = await _context.Nodes
            .Where(n => matchingNodeIds.Contains(n.Id))
            .Select(n => new NodeSearchResult
            {
                Id = n.Id,
                Transformation = n.Transformation,
                Proprietaire = n.Proprietaire,
                IdType = n.IdType,
                SuccessorCount = _context.Edges.Count(e => e.SourceNodeId == n.Id),
                PredecessorCount = _context.Edges.Count(e => e.TargetNodeId == n.Id)
            })
            .OrderBy(n => n.Id)
            .Take(100) // Limit results
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
