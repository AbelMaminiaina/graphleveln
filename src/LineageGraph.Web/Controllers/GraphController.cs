using Microsoft.AspNetCore.Mvc;
using LineageGraph.Web.Models;
using LineageGraph.Web.Services;

namespace LineageGraph.Web.Controllers;

public class GraphController : Controller
{
    private readonly IGraphService _graphService;

    public GraphController(IGraphService graphService)
    {
        _graphService = graphService;
    }

    // GET: /Graph/Details/5 - Écran 2: Successeurs et Prédécesseurs
    public async Task<IActionResult> Details(int id, int maxDepth = 10)
    {
        var node = await _graphService.GetNodeByIdAsync(id);
        if (node == null)
        {
            return NotFound();
        }

        var model = new GraphViewModel
        {
            NodeId = node.Id,
            Transformation = node.Transformation,
            Proprietaire = node.Proprietaire,
            Successors = await _graphService.GetSuccessorsAsync(id, maxDepth),
            Predecessors = await _graphService.GetPredecessorsAsync(id, maxDepth)
        };

        return View(model);
    }

    // GET: /Graph/Successors/5 - API pour AJAX
    [HttpGet]
    public async Task<IActionResult> Successors(int id, int maxDepth = 10)
    {
        var successors = await _graphService.GetSuccessorsAsync(id, maxDepth);
        return Json(successors);
    }

    // GET: /Graph/Predecessors/5 - API pour AJAX
    [HttpGet]
    public async Task<IActionResult> Predecessors(int id, int maxDepth = 10)
    {
        var predecessors = await _graphService.GetPredecessorsAsync(id, maxDepth);
        return Json(predecessors);
    }
}
