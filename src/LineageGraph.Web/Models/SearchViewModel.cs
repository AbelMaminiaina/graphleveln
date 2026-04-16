namespace LineageGraph.Web.Models;

public class SearchViewModel
{
    public string? DataName { get; set; }
    public List<NodeSearchResult> Results { get; set; } = new();
}

public class NodeSearchResult
{
    public int Id { get; set; }
    public string Transformation { get; set; } = string.Empty;
    public string? Proprietaire { get; set; }
    public int IdType { get; set; }
    public int SuccessorCount { get; set; }
    public int PredecessorCount { get; set; }
}
