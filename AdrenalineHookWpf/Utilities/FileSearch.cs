using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

namespace AdrenalineHookWpf.Utilities;

public static class FileSearch
{
    /// <summary>
    /// Tries to find an executable inside <paramref name="root"/> without doing an unbounded recursion.
    /// </summary>
    public static string? FindFirstExe(string root, int maxDepth = 6, int maxFilesScanned = 5000)
    {
        if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
            return null;

        var queue = new Queue<(string dir, int depth)>();
        queue.Enqueue((root, 0));

        int scanned = 0;

        while (queue.Count > 0)
        {
            var (dir, depth) = queue.Dequeue();
            if (depth > maxDepth) continue;

            try
            {
                foreach (var exe in Directory.EnumerateFiles(dir, "*.exe", SearchOption.TopDirectoryOnly))
                {
                    scanned++;
                    if (scanned > maxFilesScanned) return null;
                    return exe;
                }

                foreach (var sub in Directory.EnumerateDirectories(dir))
                {
                    // Skip very noisy folders
                    var name = Path.GetFileName(sub);
                    if (name.Equals("Logs", StringComparison.OrdinalIgnoreCase) ||
                        name.Equals("CrashDumps", StringComparison.OrdinalIgnoreCase) ||
                        name.Equals("Temp", StringComparison.OrdinalIgnoreCase))
                        continue;

                    queue.Enqueue((sub, depth + 1));
                }
            }
            catch
            {
                // access denied etc.
            }
        }

        return null;
    }

    public static string? FindFileByName(string root, string fileName, int maxDepth = 8, int maxFilesScanned = 15000)
    {
        if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root))
            return null;

        var queue = new Queue<(string dir, int depth)>();
        queue.Enqueue((root, 0));
        int scanned = 0;

        while (queue.Count > 0)
        {
            var (dir, depth) = queue.Dequeue();
            if (depth > maxDepth) continue;

            try
            {
                foreach (var f in Directory.EnumerateFiles(dir, fileName, SearchOption.TopDirectoryOnly))
                {
                    scanned++;
                    if (scanned > maxFilesScanned) return null;
                    return f;
                }

                foreach (var sub in Directory.EnumerateDirectories(dir))
                {
                    queue.Enqueue((sub, depth + 1));
                }
            }
            catch
            {
                // ignore
            }
        }

        return null;
    }
}
