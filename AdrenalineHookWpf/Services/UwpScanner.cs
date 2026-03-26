using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using System.Xml.Linq;
using AdrenalineHookWpf.Models;
using AdrenalineHookWpf.Utilities;

namespace AdrenalineHookWpf.Services;

/// <summary>
/// UWP/GamePass scanner.
///
/// Why PowerShell?
/// Many locked-down or enterprise machines enable NuGet PackageSourceMapping and/or block nuget.org,
/// which can prevent restoring WinRT projection packages (e.g., Microsoft.Windows.SDK.NET).
/// This scanner avoids WinRT references by using PowerShell's Get-AppxPackage to enumerate packages,
/// then resolves exe/logo paths by reading package files on disk.
/// </summary>
internal sealed class AppxPkg
{
    public string? Name { get; set; }
    public string? InstallLocation { get; set; }
    public string? Publisher { get; set; }
    public string? Version { get; set; }
    public string? Architecture { get; set; }
}

// Source-generated JSON context — no runtime reflection, trimming-safe.
[JsonSerializable(typeof(AppxPkg[]))]
[JsonSerializable(typeof(AppxPkg))]
[JsonSourceGenerationOptions(PropertyNameCaseInsensitive = true)]
internal sealed partial class AppxPkgContext : JsonSerializerContext { }

public sealed class UwpScanner
{

    public static Task<List<AppEntry>> ScanAsync(IProgress<string>? progress = null, CancellationToken ct = default)
        => Task.Run(() => ScanInternal(null, progress, ct), ct);

    public static Task<List<AppEntry>> SearchAsync(string term, IProgress<string>? progress = null, CancellationToken ct = default)
        => Task.Run(() => ScanInternal(term, progress, ct), ct);

    private static List<AppEntry> ScanInternal(string? term, IProgress<string>? progress, CancellationToken ct)
    {
        var results = new List<AppEntry>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        var pkgs = GetAppxPackages(ct);
        foreach (var p in pkgs)
        {
            ct.ThrowIfCancellationRequested();

            var install = p.InstallLocation;
            if (string.IsNullOrWhiteSpace(install) || !Directory.Exists(install))
                continue;

            // Display name: best effort from AppxManifest.xml; fall back to package name.
            var display = TryReadDisplayName(install) ?? p.Name ?? "";
            if (string.IsNullOrWhiteSpace(display))
                continue;

            // Match PowerShell filter behavior
            if (display.Contains("WindowsAppRuntime", StringComparison.OrdinalIgnoreCase) ||
                display.Contains("ms-resource", StringComparison.OrdinalIgnoreCase) ||
                display.Contains("AppManifest", StringComparison.OrdinalIgnoreCase) ||
                display.Contains("DisplayName", StringComparison.OrdinalIgnoreCase))
                continue;

            if (!string.IsNullOrWhiteSpace(term))
            {
                var name = p.Name ?? "";
                if (!display.Contains(term, StringComparison.OrdinalIgnoreCase) &&
                    !name.Contains(term, StringComparison.OrdinalIgnoreCase))
                    continue;
            }

            progress?.Report($"Scanning UWP: {display}");

            var exePath = TryResolveExePath(install);
            if (string.IsNullOrWhiteSpace(exePath) || !File.Exists(exePath))
                continue;

            var logoPath = TryResolveLogoPath(install);
            var publisher = p.Publisher;
            if (!string.IsNullOrWhiteSpace(publisher))
            {
                // mimic PS: Publisher -replace '.*CN=', ''
                var idx = publisher.IndexOf("CN=", StringComparison.OrdinalIgnoreCase);
                if (idx >= 0) publisher = publisher[(idx + 3)..];
            }

            var key = $"{display}|{exePath}";
            if (!seen.Add(key)) continue;

            results.Add(new AppEntry
            {
                Name = display,
                ExePath = exePath,
                ImagePath = logoPath,
                Publisher = publisher,
                Version = p.Version,
                Architecture = p.Architecture,
                InstallLocation = install,
                Source = "UWP"
            });
        }

        return results.OrderBy(r => r.Name).ToList();
    }

    private static List<AppxPkg> GetAppxPackages(CancellationToken ct)
    {
        // Use JSON so we don't have to parse table output.
        // Keep the select small so output stays fast.
        // Version is a System.Version object and Architecture is a ProcessorArchitecture enum —
        // stringify both so ConvertTo-Json emits plain strings, not nested objects or integers.
        var ps =
            "$ErrorActionPreference='SilentlyContinue';" +
            "Get-AppxPackage | Select-Object Name, InstallLocation, Publisher," +
            "@{n='Version';e={$_.Version.ToString()}}," +
            "@{n='Architecture';e={$_.Architecture.ToString()}} | ConvertTo-Json -Depth 2";

        var output = RunPowerShell(ps, ct);
        if (string.IsNullOrWhiteSpace(output))
            return [];

        try
        {
            // Normalize: PowerShell returns a single object (not array) when only one package found.
            var trimmed = output.TrimStart();
            if (trimmed.StartsWith('{'))
                output = $"[{output}]";

            var list = JsonSerializer.Deserialize(output, AppxPkgContext.Default.AppxPkgArray);
            return list is null ? [] : [.. list];
        }
        catch (Exception ex)
        {
            Logger.Warn($"Failed to parse Get-AppxPackage JSON: {ex.Message}");
            return [];
        }
    }

    private static string RunPowerShell(string script, CancellationToken ct)
    {
        // Prefer pwsh if available, otherwise fallback to Windows PowerShell.
        var candidates = new[] { "pwsh.exe", "powershell.exe" };
        string? shell = candidates.FirstOrDefault(c => IsOnPath(c));
        shell ??= "powershell.exe";

        var psi = new ProcessStartInfo
        {
            FileName = shell,
            Arguments = $"-NoProfile -NonInteractive -ExecutionPolicy Bypass -Command \"{EscapeForCommand(script)}\"",
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            CreateNoWindow = true,
            StandardOutputEncoding = Encoding.UTF8,
            StandardErrorEncoding = Encoding.UTF8
        };

        using var proc = new Process { StartInfo = psi };
        proc.Start();

        // Read both streams concurrently to avoid pipe-buffer deadlock.
        var stdout = proc.StandardOutput.ReadToEndAsync(CancellationToken.None);
        var stderr = proc.StandardError.ReadToEndAsync(CancellationToken.None);

        // Kill the process immediately on cancellation or 90-second timeout.
        using var timeoutCts = new CancellationTokenSource(TimeSpan.FromSeconds(90));
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(ct, timeoutCts.Token);
        using var _ = linked.Token.Register(() =>
        {
            try { proc.Kill(entireProcessTree: true); } catch { }
        });

        proc.WaitForExitAsync(linked.Token).GetAwaiter().GetResult();

        ct.ThrowIfCancellationRequested();

        var outText = stdout.GetAwaiter().GetResult();
        var errText = stderr.GetAwaiter().GetResult();

        if (!string.IsNullOrWhiteSpace(errText))
            Logger.Warn($"PowerShell stderr: {errText.Trim()}");

        return outText;
    }

    private static bool IsOnPath(string exe)
    {
        try
        {
            var paths = (Environment.GetEnvironmentVariable("PATH") ?? "").Split(Path.PathSeparator);
            return paths.Any(p => File.Exists(Path.Combine(p.Trim(), exe)));
        }
        catch
        {
            return false;
        }
    }

    private static string EscapeForCommand(string s)
        => s.Replace("\"", "`\"");

    private static string? TryResolveExePath(string install)
    {
        // 1) If MicrosoftGame.config exists, try to read the declared executable
        var gameConfigPath = Path.Combine(install, "MicrosoftGame.config");
        if (File.Exists(gameConfigPath))
        {
            try
            {
                var doc = XDocument.Load(gameConfigPath);
                var exeElem = doc.Descendants().FirstOrDefault(e => e.Name.LocalName.Equals("Executable", StringComparison.OrdinalIgnoreCase));
                if (exeElem is not null)
                {
                    var attr = exeElem.Attributes().FirstOrDefault(a => a.Name.LocalName.Equals("Name", StringComparison.OrdinalIgnoreCase));
                    var exeName = attr?.Value ?? exeElem.Value;

                    if (!string.IsNullOrWhiteSpace(exeName))
                    {
                        var found = FileSearch.FindFileByName(install, exeName);
                        if (!string.IsNullOrWhiteSpace(found))
                            return found;
                    }
                }
            }
            catch (Exception ex)
            {
                Logger.Warn($"Failed to parse MicrosoftGame.config in '{install}': {ex.Message}");
            }
        }

        // 2) Fallback: first exe found in the install location (bounded scan)
        return FileSearch.FindFirstExe(install);
    }

    private static string? TryResolveLogoPath(string install)
    {
        var manifestPath = Path.Combine(install, "AppxManifest.xml");
        if (!File.Exists(manifestPath))
            return null;

        try
        {
            var doc = XDocument.Load(manifestPath);
            var logo = doc.Descendants().FirstOrDefault(e => e.Name.LocalName.Equals("Logo", StringComparison.OrdinalIgnoreCase))?.Value;

            if (string.IsNullOrWhiteSpace(logo))
                return null;

            var full = Path.Combine(install, logo.Replace('/', Path.DirectorySeparatorChar));
            return File.Exists(full) ? full : null;
        }
        catch
        {
            return null;
        }
    }

    private static string? TryReadDisplayName(string install)
    {
        var manifestPath = Path.Combine(install, "AppxManifest.xml");
        if (!File.Exists(manifestPath))
            return null;

        try
        {
            var doc = XDocument.Load(manifestPath);

            // Usually under <Properties><DisplayName>...</DisplayName>
            var dn = doc.Descendants().FirstOrDefault(e => e.Name.LocalName.Equals("DisplayName", StringComparison.OrdinalIgnoreCase))?.Value;
            if (string.IsNullOrWhiteSpace(dn)) return null;
            return dn.Trim();
        }
        catch
        {
            return null;
        }
    }
}
