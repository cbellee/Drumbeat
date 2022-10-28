using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Azure.Storage;
using Azure.Storage.Blobs;
using Azure.Storage.Sas;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using drumbeat.Models;
using System.Diagnostics;

namespace drumbeat.Controllers;

public class FileUploadController : Controller
{
    private readonly drumbeat.Data.ApplicationDbContext _dbContext;
    private ILogger _logger;

    public FileUploadController(drumbeat.Data.ApplicationDbContext dbContext, ILogger<FileUploadController> logger)
    {
        _dbContext = dbContext ?? throw new ArgumentNullException(nameof(dbContext));
        _logger = logger;
    }

    [ResponseCache(Duration = 0, Location = ResponseCacheLocation.None, NoStore = true)]
    public IActionResult Error()
    {
        return View(new ErrorViewModel { RequestId = Activity.Current?.Id ?? HttpContext.TraceIdentifier });
    }

    public IActionResult Upload()
    {
        return View();
    }

    [Authorize]
    [HttpPost("FileUpload")]
    public async Task<IActionResult> Upload(IFormFile file)
    {
        var accountName = System.Environment.GetEnvironmentVariable("STORAGE_ACCOUNT_NAME");
        var accountKey = System.Environment.GetEnvironmentVariable("STORAGE_ACCOUNT_KEY");
        var containerName = System.Environment.GetEnvironmentVariable("STORAGE_CONTAINER_NAME");
        var subscriptionKey = Environment.GetEnvironmentVariable("COMPUTER_VISION_SUBSCRIPTION_KEY");
        var endpoint = Environment.GetEnvironmentVariable("COMPUTER_VISION_ENDPOINT");

        BlobContainerClient container = new BlobContainerClient($"DefaultEndpointsProtocol=https;AccountName={accountName};AccountKey={accountKey};EndpointSuffix=core.windows.net", containerName);
        drumbeat.Models.Photo photo = new drumbeat.Models.Photo();

        // if the image file is valid
        // rename & upload the image to blob storage
        // send the image to Azure Cognitive Services for analysis
        if (file.Length > 0)
        {
            var filePath = Path.GetTempFileName();

            using (var stream = new FileStream(filePath, FileMode.Create))
            {
                await file.CopyToAsync(stream);
                try
                {
                    var uniqueFileName = Guid.NewGuid().ToString() + ".jpg";
                    BlobClient blobClient = container.GetBlobClient(uniqueFileName);

                    stream.Position = 0;
                    blobClient.Upload(stream);
                    var blobSasBuilder = new BlobSasBuilder()
                    {
                        BlobContainerName = containerName,
                        BlobName = uniqueFileName,
                        ExpiresOn = DateTime.UtcNow.AddMinutes(30),
                    };

                    blobSasBuilder.SetPermissions(Azure.Storage.Sas.BlobSasPermissions.Read);
                    var sasToken = blobSasBuilder.ToSasQueryParameters(new StorageSharedKeyCredential(accountName, accountKey)).ToString();
                    var sasUrl = blobClient.Uri.AbsoluteUri + "?" + sasToken;

                    photo.Url = sasUrl;
                    photo.Size = file.Length;
                    photo.Name = uniqueFileName;
                    photo.ContentType = file.ContentType;

                    try
                    {
                        var result = CustomVisionApi.AnalyzeImageSample.RunAsync(endpoint, subscriptionKey, stream, sasUrl);

                        if (result.Result.Count <= 0)
                        {
                            return View();
                        }

                        StringBuilder sb = new StringBuilder();
                        foreach (var r in result.Result)
                        {
                            sb.Append(r.Gender + ";");
                            Console.WriteLine($"Face Gender: {r.Gender.ToString()}");
                            Console.WriteLine($"Face Age: {r.Age}");
                        }

                        if (this.User != null)
                        {
                            System.Security.Claims.ClaimsPrincipal currentUser = this.User;
                            Console.WriteLine($"Current user: {currentUser.Identity.Name}");
                            var currentUserId = User.FindFirst(ClaimTypes.NameIdentifier);

                            drumbeat.Data.ImageScore imageScore = new Data.ImageScore();
                            imageScore.ImageUrl = blobClient.Uri.AbsoluteUri;
                            imageScore.Result = sb.ToString();
                            imageScore.TimeStamp = DateTime.Now;
                            imageScore.ApplicationUserId = currentUserId.Value;

                            _dbContext.Add<drumbeat.Data.ImageScore>(imageScore);
                            _dbContext.SaveChanges();
                        }
                    }
                    catch (Exception e)
                    {
                        Console.WriteLine(e.Message);
                    }
                }
                catch (Exception ex)
                {
                    return Ok(ex.Message);
                }
            }
        }
        else
        {
            return View();
        }
        return View(photo);
    }
}
