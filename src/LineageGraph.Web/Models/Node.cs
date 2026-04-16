namespace LineageGraph.Web.Models;

public class Node
{
    public int Id { get; set; }
    public string Transformation { get; set; } = string.Empty;
    public int IdType { get; set; }
    public string? Proprietaire { get; set; }
    public DateTime DateCreation { get; set; }

    // Navigation
    public ICollection<Edge> OutgoingEdges { get; set; } = new List<Edge>();
    public ICollection<Edge> IncomingEdges { get; set; } = new List<Edge>();
}
