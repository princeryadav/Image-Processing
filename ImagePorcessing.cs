using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.Versioning;
using System.Security.Cryptography;
using System.Text.Json.Serialization;
using System.Threading.Tasks;
using Azure.Storage.Blobs;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Extensions.Tables;
using Microsoft.Extensions.Logging;

namespace ImageProcess;

public class ImagePorcessing
{
    private const string ImageContainerName = "images";
    private const string BlobConnectionSetting = "BlobConnection";
    private readonly ILogger<ImagePorcessing> _logger;

    public ImagePorcessing(ILogger<ImagePorcessing> logger)
    {
        _logger = logger;
    }

    [Function("Health")]
    public IActionResult Run([HttpTrigger(AuthorizationLevel.Anonymous, "get", Route = "health")] HttpRequest req)
    {
        _logger.LogInformation("Health check requested.");
        return new OkObjectResult(new HealthResponse("Healthy"));
    }

    [Function("ProcessImageMetadata")]
    [SupportedOSPlatform("windows")]
    public async Task<ProcessImageResult> ProcessImageMetadata(
        [BlobTrigger(ImageContainerName + "/{name}", Connection = BlobConnectionSetting)] Stream imageStream,
        string name)
    {
        if (imageStream == null)
        {
            _logger.LogWarning("Blob trigger fired with null stream for {BlobName}.", name);
            return new ProcessImageResult(
                new ImageMetadata(name, 0, "Unknown", 0, 0, null, null),
                null);
        }

        long fileSize = imageStream.CanSeek ? imageStream.Length : 0;
        using var buffered = new MemoryStream();
        await imageStream.CopyToAsync(buffered);
        buffered.Position = 0;
        fileSize = fileSize == 0 ? buffered.Length : fileSize;

        using Image image = Image.FromStream(buffered, useEmbeddedColorManagement: false, validateImageData: false);
        string format = GetImageFormat(image);

        DateTimeOffset? createdOn = null;
        DateTimeOffset? lastModified = null;
        var connectionString = Environment.GetEnvironmentVariable(BlobConnectionSetting);
        if (!string.IsNullOrWhiteSpace(connectionString))
        {
            var containerClient = new BlobContainerClient(connectionString, ImageContainerName);
            var blobClient = containerClient.GetBlobClient(name);
            var properties = await blobClient.GetPropertiesAsync();
            createdOn = properties.Value.CreatedOn;
            lastModified = properties.Value.LastModified;
        }

        var metadata = new ImageMetadata(
            name,
            fileSize,
            format,
            image.Width,
            image.Height,
            createdOn,
            lastModified);

        _logger.LogInformation(
            "Processed image {FileName} ({FileSize} bytes, {Format}, {Width}x{Height}).",
            metadata.FileName,
            metadata.FileSize,
            metadata.Format,
            metadata.Width,
            metadata.Height);

        TableImageEntity? entity = await PersistMetadataAsync(metadata, name);

        return new ProcessImageResult(metadata, entity);
    }

    [SupportedOSPlatform("windows")]
    private static string GetImageFormat(Image image)
    {
        if (image.RawFormat.Equals(ImageFormat.Jpeg))
        {
            return "Jpeg";
        }

        if (image.RawFormat.Equals(ImageFormat.Png))
        {
            return "Png";
        }

        if (image.RawFormat.Equals(ImageFormat.Gif))
        {
            return "Gif";
        }

        if (image.RawFormat.Equals(ImageFormat.Bmp))
        {
            return "Bmp";
        }

        if (image.RawFormat.Equals(ImageFormat.Tiff))
        {
            return "Tiff";
        }

        if (image.RawFormat.Equals(ImageFormat.Icon))
        {
            return "Icon";
        }

        return image.RawFormat.ToString();
    }

    private Task<TableImageEntity?> PersistMetadataAsync(
        ImageMetadata metadata,
        string blobName)
    {
        string blobPath = $"{ImageContainerName}/{blobName}";
        string rowKey = CreateRowKey(blobPath);
        var entity = new TableImageEntity(
            ImageContainerName,
            rowKey,
            rowKey,
            metadata.FileName,
            ImageContainerName,
            blobPath,
            metadata.FileSize,
            metadata.Format,
            metadata.Width,
            metadata.Height,
            DateTimeOffset.UtcNow);

        _logger.LogInformation("Saving metadata entity for {BlobPath} to Table Storage.", blobPath);
        return Task.FromResult<TableImageEntity?>(entity);
    }

    private static string CreateRowKey(string blobPath)
    {
        using var sha256 = SHA256.Create();
        byte[] hash = sha256.ComputeHash(System.Text.Encoding.UTF8.GetBytes(blobPath));
        return Convert.ToHexString(hash);
    }
}

public sealed record HealthResponse(string Status);

public sealed record ImageMetadata(
    string FileName,
    long FileSize,
    string Format,
    int Width,
    int Height,
    DateTimeOffset? CreatedOn,
    DateTimeOffset? LastModified);

public sealed record ProcessImageResult(
    ImageMetadata Metadata,
    [property: TableOutput(
        "%ImageMetadataTable%",
        Connection = "BlobConnection")]
    TableImageEntity? Entity);

public sealed record TableImageEntity(
    [property: JsonPropertyName("partitionKey")] string PartitionKey,
    [property: JsonPropertyName("rowKey")] string RowKey,
    [property: JsonPropertyName("id")] string Id,
    [property: JsonPropertyName("fileName")] string FileName,
    [property: JsonPropertyName("containerName")] string ContainerName,
    [property: JsonPropertyName("blobPath")] string BlobPath,
    [property: JsonPropertyName("fileSize")] long FileSize,
    [property: JsonPropertyName("imageFormat")] string ImageFormat,
    [property: JsonPropertyName("width")] int Width,
    [property: JsonPropertyName("height")] int Height,
    [property: JsonPropertyName("createdAtUtc")] DateTimeOffset CreatedAtUtc);