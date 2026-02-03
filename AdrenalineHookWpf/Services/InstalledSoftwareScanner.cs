using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using AdrenalineHookWpf.Models;
using AdrenalineHookWpf.Utilities;
using Microsoft.Win32;

namespace AdrenalineHookWpf.Services;

public sealed class InstalledSoftwareScanner
{
    private static readonly string[] UninstallRoots =
    {
        @"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        @"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    };

    public Task<List<AppEntry>> ScanAsync(IProgress<string>? progress = null, CancellationToken ct = default)
        => Task.Run(() => ScanInternal(null, progress, ct), ct);

    public Task<List<AppEntry>> SearchAsync(string term, IProgress<string>? progress = null, CancellationToken ct = default)
        => Task.Run(() => ScanInternal(term, progress, ct), ct);

    private static List<AppEntry> ScanInternal(string? term, IProgress<string>? progress, CancellationToken ct)
    {
        var results = new List<AppEntry>();
        var seen = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

        foreach (var root in UninstallRoots)
        {
            ct.ThrowIfCancellationRequested();
            progress?.Report($"Scanning registry: {root}");

            using var baseKey = Registry.LocalMachine.OpenSubKey(root);
            if (baseKey is null) continue;

            foreach (var subName in baseKey.GetSubKeyNames())
            {
                ct.ThrowIfCancellationRequested();

                using var sub = baseKey.OpenSubKey(subName);
                if (sub is null) continue;

                var displayName = sub.GetValue("DisplayName") as string;
                if (string.IsNullOrWhiteSpace(displayName)) continue;

                if (!string.IsNullOrWhiteSpace(term) &&
                    !displayName.Contains(term, StringComparison.OrdinalIgnoreCase))
                    continue;

                var installLocation = sub.GetValue("InstallLocation") as string;

                string? exePath = null;

                if (!string.IsNullOrWhiteSpace(installLocation) && Directory.Exists(installLocation))
                {
                    exePath = FileSearch.FindFirstExe(installLocation);
                }

                // Fallback to DisplayIcon if InstallLocation isn't helpful
                if (string.IsNullOrWhiteSpace(exePath))
                {
                    var displayIcon = sub.GetValue("DisplayIcon") as string;
                    if (!string.IsNullOrWhiteSpace(displayIcon))
                    {
                        exePath = displayIcon.Split(',').FirstOrDefault()?.Trim('"', ' ');
                        if (exePath is not null && !File.Exists(exePath))
                            exePath = null;
                    }
                }

                if (string.IsNullOrWhiteSpace(exePath) || !File.Exists(exePath))
                    continue;

                var key = $"{displayName}|{exePath}";
                if (!seen.Add(key)) continue;

                results.Add(new AppEntry
                {
                    Name = displayName,
                    ExePath = exePath,
                    ImagePath = exePath,
                    InstallLocation = installLocation ?? Path.GetDirectoryName(exePath),
                    Source = "Installed"
                });
            }
        }

        return results.OrderBy(r => r.Name).ToList();
    }
}
