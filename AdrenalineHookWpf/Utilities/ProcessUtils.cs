using System;
using System.Diagnostics;
using System.IO;

namespace AdrenalineHookWpf.Utilities;

public static class ProcessUtils
{
    public static void KillProcessByName(string processName)
    {
        try
        {
            foreach (var p in Process.GetProcessesByName(processName))
            {
                try { p.Kill(entireProcessTree: true); }
                catch { /* ignore */ }
            }
        }
        catch { /* ignore */ }
    }

    public static void OpenFolderForPath(string path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return;

        var folder = Directory.Exists(path) ? path : Path.GetDirectoryName(path);
        if (string.IsNullOrWhiteSpace(folder) || !Directory.Exists(folder))
            return;

        Process.Start(new ProcessStartInfo
        {
            FileName = "explorer.exe",
            Arguments = $"\"{folder}\"",
            UseShellExecute = true
        });
    }

    public static void StartFile(string file, string? args = null)
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = file,
            Arguments = args ?? "",
            UseShellExecute = true
        });
    }
}
