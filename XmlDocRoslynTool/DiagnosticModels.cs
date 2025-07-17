using System.Text.Json.Serialization;
using System.Collections.Generic;

namespace XmlDocRoslynTool.Models
{
    // These models are designed to capture the structure of the JSON output
    // from the Roslynator CLI tool.

    public record RoslynatorReport(
        [property: JsonPropertyName("diagnostics")] IReadOnlyList<Diagnostic> Diagnostics
    );

    public record Diagnostic(
        [property: JsonPropertyName("id")] string Id,
        [property: JsonPropertyName("message")] string Message,
        [property: JsonPropertyName("severity")] string Severity,
        [property: JsonPropertyName("location")] Location Location,
        [property: JsonPropertyName("properties")] IReadOnlyDictionary<string, string> Properties
    );

    public record Location(
        [property: JsonPropertyName("filePath")] string FilePath,
        [property: JsonPropertyName("line")] int Line,
        [property: JsonPropertyName("character")] int Character,
        [property: JsonPropertyName("textSpan")] TextSpan TextSpan
    );

    public record TextSpan(
        [property: JsonPropertyName("start")] int Start,
        [property: JsonPropertyName("length")] int Length
    );
} 