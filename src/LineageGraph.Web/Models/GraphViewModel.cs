namespace LineageGraph.Web.Models;

public class GraphViewModel
{
    public int NodeId { get; set; }
    public string Transformation { get; set; } = string.Empty;
    public string? Proprietaire { get; set; }
    public List<LineageItem> Successors { get; set; } = new();
    public List<LineageItem> Predecessors { get; set; } = new();
}

public class LineageItem
{
    public int NodeId { get; set; }
    public string Transformation { get; set; } = string.Empty;
    public int IdType { get; set; }
    public string? Proprietaire { get; set; }
    public string DataName { get; set; } = string.Empty;
    public int Depth { get; set; }
    public string Path { get; set; } = string.Empty;
}
