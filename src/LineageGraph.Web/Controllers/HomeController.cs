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

    // GET: / - Ecran 1: Recherche
    public IActionResult Index()
    {
        return View(new SearchViewModel());
    }

    // POST: /Home/Search - Recherche par 4 inputs
    [HttpPost]
    public async Task<IActionResult> Search(SearchViewModel model)
    {
        model.HasSearched = true;

        // Check if at least one input is provided
        if (string.IsNullOrWhiteSpace(model.Input1) &&
            string.IsNullOrWhiteSpace(model.Input2) &&
            string.IsNullOrWhiteSpace(model.Input3) &&
            string.IsNullOrWhiteSpace(model.Input4))
        {
            ModelState.AddModelError("", "Veuillez entrer au moins un critere de recherche");
            return View("Index", model);
        }

        model.Results = await _graphService.SearchByInputsAsync(
            model.Input1,
            model.Input2,
            model.Input3,
            model.Input4
        );

        return View("Index", model);
    }
}
