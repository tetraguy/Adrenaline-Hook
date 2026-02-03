using System;
using System.Diagnostics;
using System.Linq;
using System.Text;
using System.Text.Json;

namespace AdrenalineHookWpf.Services;

public static class SystemInfoService
{
    private sealed record GpuInfo(string? Name, string? DriverVersion, double AdapterRAM);

    public static string BuildSummary(string appVersionTag)
    {
        var (gpuName, driver, vramGb) = TryGetGpuInfo();

        var windowsVer = Environment.OSVersion.Version.ToString();
        var procCount = Process.GetProcesses().Length;

        return string.Join(Environment.NewLine, new[]
        {
            $"Adrenaline Hook Version: {appVersionTag}",
            $"GPU: {gpuName}",
            $"Driver: {driver}",
            $"VRAM: {vramGb:N2} GB",
            $"Windows Version: {windowsVer}",
            $"Processes: {procCount} running"
        });
    }

    private static (string gpuName, string driver, double vramGb) TryGetGpuInfo()
    {
        try
        {
            // Avoid System.Management NuGet dependency: use PowerShell CIM and parse JSON.
            var ps =
                "$ErrorActionPreference='SilentlyContinue';" +
                "$g=Get-CimInstance Win32_VideoController | Select-Object -First 1 Name,DriverVersion,AdapterRAM;" +
                "if($null -eq $g){return};" +
                "$g | ConvertTo-Json -Depth 2";

            var json = RunPowerShell(ps);
            if (string.IsNullOrWhiteSpace(json))
                return ("Unknown", "Unknown", 0);

            using var doc = JsonDocument.Parse(json);
            var root = doc.RootElement;

            var name = root.TryGetProperty("Name", out var n) ? n.ToString() : "Unknown";
            var drv = root.TryGetProperty("DriverVersion", out var d) ? d.ToString() : "Unknown";
            double vramGb = 0;

            if (root.TryGetProperty("AdapterRAM", out var r))
            {
                // AdapterRAM can come back as string or number
                var ramStr = r.ToString();
                if (double.TryParse(ramStr, out var ramBytes) && ramBytes > 0)
                    vramGb = ramBytes / (1024d * 1024d * 1024d);
            }

            return (name, drv, vramGb);
        }
        catch
        {
            return ("Unknown", "Unknown", 0);
        }
    }

    private static string RunPowerShell(string script)
    {
        var candidates = new[] { "pwsh.exe", "powershell.exe" };
        string shell = candidates.FirstOrDefault(IsOnPath) ?? "powershell.exe";

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
        var outText = proc.StandardOutput.ReadToEnd();
        var errText = proc.StandardError.ReadToEnd();
        proc.WaitForExit(5000);
        return outText;
    }

    private static bool IsOnPath(string exe)
    {
        try
        {
            var paths = (Environment.GetEnvironmentVariable("PATH") ?? "").Split(System.IO.Path.PathSeparator);
            return paths.Any(p => System.IO.File.Exists(System.IO.Path.Combine(p.Trim(), exe)));
        }
        catch
        {
            return false;
        }
    }

    private static string EscapeForCommand(string s)
        => s.Replace("\"", "`\"");
}
