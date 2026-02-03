using System;
using System.Diagnostics;
using System.IO;
using System.Linq;

namespace AdrenalineHookWpf.Services;

public static class AmdSoftwareLauncher
{
    public static bool TryLaunch()
    {
        var possiblePaths = new[]
        {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "AMD", "CNext", "CNext", "RadeonSoftware.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "AMD", "Radeon Software", "RadeonSoftware.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles), "AMD", "CNext", "CNext", "AMDRSServ.exe"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86), "AMD", "CNext", "CNext", "RadeonSoftware.exe"),
        };

        var found = possiblePaths.FirstOrDefault(File.Exists);
        if (found is null) return false;

        Process.Start(new ProcessStartInfo
        {
            FileName = found,
            UseShellExecute = true
        });

        return true;
    }

    public static void OpenDownloadPage()
    {
        Process.Start(new ProcessStartInfo
        {
            FileName = "https://www.amd.com/en/products/software/adrenalin.html",
            UseShellExecute = true
        });
    }
}
