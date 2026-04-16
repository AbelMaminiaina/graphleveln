namespace LineageGraph.Web.Models;

public class Edge
{
    public int Id { get; set; }
    public int SourceNodeId { get; set; }
    public int TargetNodeId { get; set; }
    public string DataName { get; set; } = string.Empty;

    // Navigation
    public Node? SourceNode { get; set; }
    public Node? TargetNode { get; set; }
}
