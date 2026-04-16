using Microsoft.AspNetCore.Mvc;
using LineageGraph.Web.Models;
using LineageGraph.Web.Services;

namespace LineageGraph.Web.Controllers;

public class HomeController : Controller
{
    private readonly IGraphService _graphService;

    public HomeController(IGraphService graphService)
    {
        _graphService = graphService;
    }

    // GET: / - Écran 1: Recherche
    public IActionResult Index()
    {
        return View(new SearchViewModel());
    }

    // POST: /Home/Search - Recherche par data name
    [HttpPost]
    public async Task<IActionResult> Search(SearchViewModel model)
    {
        if (string.IsNullOrWhiteSpace(model.DataName))
        {
            ModelState.AddModelError("DataName", "Veuillez entrer un nom de donnée");
            return View("Index", model);
        }

        model.Results = await _graphService.SearchByDataNameAsync(model.DataName);
        return View("Index", model);
    }
}
