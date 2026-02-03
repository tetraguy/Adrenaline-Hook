using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.Json;
using System.Text.Json.Nodes;
using AdrenalineHookWpf.Models;
using AdrenalineHookWpf.Utilities;

namespace AdrenalineHookWpf.Services;

public sealed class GmdbService
{
    public string GmdbPath { get; }
    public string BackupPath { get; }

    private static readonly JsonSerializerOptions JsonWriteOptions = new()
    {
        WriteIndented = true
    };

    public GmdbService()
    {
        var amdCn = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "AMD", "CN");
        Directory.CreateDirectory(amdCn);

        GmdbPath = Path.Combine(amdCn, "gmdb.blb");
        BackupPath = Path.Combine(amdCn, "backup.blb");
    }

    public bool Exists => File.Exists(GmdbPath);

    public HashSet<string> GetExistingTitles()
    {
        try
        {
            var root = LoadRootOrNull();
            var games = root?["games"] as JsonArray;
            if (games is null) return new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            return games
                .Select(n => n?["title"]?.GetValue<string>())
                .Where(s => !string.IsNullOrWhiteSpace(s))
                .ToHashSet(StringComparer.OrdinalIgnoreCase)!;
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to read existing titles", ex);
            return new HashSet<string>(StringComparer.OrdinalIgnoreCase);
        }
    }

    public List<string> GetHookedTitles()
    {
        try
        {
            var root = LoadRootOrNull();
            var games = root?["games"] as JsonArray;
            if (games is null) return new List<string>();

            return games
                .Select(n => n?["title"]?.GetValue<string>())
                .Where(s => !string.IsNullOrWhiteSpace(s))
                .OrderBy(s => s)
                .ToList()!;
        }
        catch (Exception ex)
        {
            Logger.Error("Failed to load hooked titles", ex);
            return new List<string>();
        }
    }

    public (int total, int missing) GetVerifyStats()
    {
        try
        {
            var root = LoadRootOrNull();
            var games = root?["games"] as JsonArray;
            if (games is null) return (0, 0);

            var exePaths = games.Select(n => n?["exe_path"]?.GetValue<string>()).Where(p => !string.IsNullOrWhiteSpace(p)).ToList();
            var total = exePaths.Count;
            var missing = exePaths.Count(p => p is null || !File.Exists(p));
            return (total, missing);
        }
        catch (Exception ex)
        {
            Logger.Error("Verify failed", ex);
            return (0, 0);
        }
    }

    public void Backup()
    {
        if (!File.Exists(GmdbPath))
            throw new FileNotFoundException("gmdb.blb not found", GmdbPath);

        File.Copy(GmdbPath, BackupPath, overwrite: true);
    }

    public void Restore()
    {
        if (!File.Exists(BackupPath))
            throw new FileNotFoundException("backup.blb not found", BackupPath);

        File.Copy(BackupPath, GmdbPath, overwrite: true);
    }

    public void ResetDatabase()
    {
        if (File.Exists(GmdbPath))
            File.Delete(GmdbPath);
    }

    public (int added, int skipped) AddApps(IEnumerable<AppEntry> apps)
    {
        var list = apps.ToList();
        if (list.Count == 0) return (0, 0);

        var root = LoadRootOrCreate();
        var games = root["games"] as JsonArray ?? new JsonArray();
        root["games"] = games;

        var existingTitles = games
            .Select(n => n?["title"]?.GetValue<string>())
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .ToHashSet(StringComparer.OrdinalIgnoreCase)!;

        var existingExe = games
            .Select(n => n?["exe_path"]?.GetValue<string>())
            .Where(s => !string.IsNullOrWhiteSpace(s))
            .ToHashSet(StringComparer.OrdinalIgnoreCase)!;

        int added = 0, skipped = 0;

        foreach (var app in list)
        {
            if (existingTitles.Contains(app.Name) || existingExe.Contains(app.ExePath))
            {
                skipped++;
                continue;
            }

            games.Add(CreateGameNode(app));
            existingTitles.Add(app.Name);
            existingExe.Add(app.ExePath);
            added++;
        }

        SaveRoot(root);
        return (added, skipped);
    }

    public int RemoveTitles(IEnumerable<string> titles)
    {
        var toRemove = titles.Where(t => !string.IsNullOrWhiteSpace(t)).ToHashSet(StringComparer.OrdinalIgnoreCase);
        if (toRemove.Count == 0) return 0;

        var root = LoadRootOrNull();
        var games = root?["games"] as JsonArray;
        if (root is null || games is null) return 0;

        var kept = new JsonArray();
        int removed = 0;

        foreach (var n in games)
        {
            var title = n?["title"]?.GetValue<string>() ?? "";
            if (toRemove.Contains(title))
            {
                removed++;
                continue;
            }
            kept.Add(n);
        }

        root["games"] = kept;
        SaveRoot(root);
        return removed;
    }

    public string ReadRawText()
    {
        if (!File.Exists(GmdbPath)) return "";
        return File.ReadAllText(GmdbPath);
    }

    public void SaveRawText(string text)
    {
        File.WriteAllText(GmdbPath, text);
    }

    private JsonObject LoadRootOrCreate()
    {
        var root = LoadRootOrNull();
        if (root is not null) return root;

        return new JsonObject
        {
            ["engines"] = new JsonArray(),
            ["games"] = new JsonArray()
        };
    }

    private JsonObject? LoadRootOrNull()
    {
        if (!File.Exists(GmdbPath))
            return null;

        var json = File.ReadAllText(GmdbPath);
        if (string.IsNullOrWhiteSpace(json))
            return null;

        var node = JsonNode.Parse(json) as JsonObject;
        return node;
    }

    private void SaveRoot(JsonObject root)
    {
        var json = root.ToJsonString(JsonWriteOptions);
        File.WriteAllText(GmdbPath, json);
    }

    private static JsonObject CreateGameNode(AppEntry app)
    {
        // This mirrors your PowerShell template (v1.3.x) with safe defaults.
        return new JsonObject
        {
            ["FRAMEGEN_PerfMode"] = 0,
            ["FRAMEGEN_SearchMode"] = 0,
            ["amdId"] = -1,
            ["appDisplayScalingSet"] = "FALSE",
            ["appHistogramCapture"] = "FALSE",
            ["arguments"] = "",
            ["athena_support"] = "FALSE",
            ["auto_enable_ps_state"] = "USEGLOBAL",
            ["averageFPS"] = -1,
            ["color_enabled"] = "FALSE",
            ["colors"] = new JsonArray(),
            ["commandline"] = "",
            ["exe_path"] = app.ExePath,
            ["eyefinity_enabled"] = "FALSE",
            ["framegen_enabled"] = 0,
            ["freeSyncForceSet"] = "FALSE",
            ["guid"] = Guid.NewGuid().ToString(),
            ["has_framegen_profile"] = "FALSE",
            ["has_upscaling_profile"] = "FALSE",
            ["hidden"] = "FALSE",
            ["image_info"] = app.ImagePath ?? app.ExePath,
            ["install_location"] = "",
            ["installer_id"] = "",
            ["is_ai_app"] = "FALSE",
            ["is_appforlink"] = "FALSE",
            ["is_favourite"] = "FALSE",
            ["last_played_mins"] = 0,
            ["lastlaunchtime"] = "",
            ["lastperformancereporttime"] = "",
            ["lnk_path"] = "",
            ["manual"] = app.Source.Equals("Manual", StringComparison.OrdinalIgnoreCase) ? "TRUE" : "FALSE",
            ["origin_id"] = -1,
            ["overdrive"] = new JsonArray(),
            ["overdrive_enabled"] = "FALSE",
            ["percentile95_msec"] = -1,
            ["profileCustomized"] = "FALSE",
            ["profileEnabled"] = "TRUE",
            ["rayTracing"] = "FALSE",
            ["rendering_process"] = "",
            ["revertuserprofiletype"] = -1,
            ["smartshift_enabled"] = "FALSE",
            ["special_flags"] = "",
            ["steam_id"] = -1,
            ["title"] = app.Name,
            ["total_played_mins"] = 0,
            ["uninstall_location"] = -1,
            ["uninstalled"] = "FALSE",
            ["uplay_id"] = -1,
            ["upscaling_enabled"] = "FALSE",
            ["upscaling_sharpness"] = 0,
            ["upscaling_target_resolution"] = "",
            ["upscaling_use_borderless"] = "FALSE",
            ["useEyefinity"] = "FALSE",
            ["userprofiletype"] = -1,
            ["week_played_mins"] = 0
        };
    }
}
