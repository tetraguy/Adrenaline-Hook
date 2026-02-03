using System;
using System.Net.Http;
using System.Text.Json;
using System.Threading.Tasks;
using AdrenalineHookWpf.Utilities;

namespace AdrenalineHookWpf.Services;

public static class UpdateChecker
{
    // Change this when you bump app version.
    public const string CurrentVersionTag = "v2.0.0";
    private const string LatestReleaseApi = "https://api.github.com/repos/tetraguy/Adrenaline-Hook/releases/latest";

    public sealed record UpdateInfo(string LatestTag, string HtmlUrl);

    public static async Task<UpdateInfo?> GetUpdateAsync()
    {
        try
        {
            using var http = new HttpClient();
            http.DefaultRequestHeaders.UserAgent.ParseAdd("AdrenalineHookWpf/1.0 (+https://github.com/tetraguy)");
            using var resp = await http.GetAsync(LatestReleaseApi).ConfigureAwait(false);
            resp.EnsureSuccessStatusCode();

            var json = await resp.Content.ReadAsStringAsync().ConfigureAwait(false);
            using var doc = JsonDocument.Parse(json);

            var latest = doc.RootElement.GetProperty("tag_name").GetString() ?? "";
            var url = doc.RootElement.GetProperty("html_url").GetString() ?? "";

            if (string.IsNullOrWhiteSpace(latest) || string.IsNullOrWhiteSpace(url))
                return null;

            if (!latest.Equals(CurrentVersionTag, StringComparison.OrdinalIgnoreCase))
                return new UpdateInfo(latest, url);

            return null;
        }
        catch (Exception ex)
        {
            Logger.Warn($"Update check failed: {ex.Message}");
            return null;
        }
    }
}
