using Microsoft.AspNetCore.Mvc;

namespace ex1_webapi_controllers.Controllers
{
    [ApiController]
    [Route("")]
    public class MyController : ControllerBase
    {
        [HttpGet]
        public void Get(string cmd)
        {
            /* Vulnerability: Command Injection. */
            System.Diagnostics.Process.Start(cmd);
        }
    }

}