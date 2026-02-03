using System;
using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;
using AdrenalineHookWpf.Models;

namespace AdrenalineHookWpf.Windows;

public partial class AppDetailsWindow : Window
{
    public sealed class Vm
    {
        public string Name { get; init; } = "";
        public string Source { get; init; } = "";
        public string Publisher { get; init; } = "";
        public string Version { get; init; } = "";
        public string Architecture { get; init; } = "";
        public string ExePath { get; init; } = "";
        public string InstallLocation { get; init; } = "";
        public BitmapImage? Logo { get; init; }
    }

    public AppDetailsWindow(AppEntry entry)
    {
        InitializeComponent();

        DataContext = new Vm
        {
            Name = entry.Name,
            Source = entry.Source,
            Publisher = entry.Publisher ?? "",
            Version = entry.Version ?? "",
            Architecture = entry.Architecture ?? "",
            ExePath = entry.ExePath,
            InstallLocation = entry.InstallLocation ?? "",
            Logo = LoadImage(entry.ImagePath)
        };
    }

    private static BitmapImage? LoadImage(string? path)
    {
        try
        {
            if (string.IsNullOrWhiteSpace(path)) return null;
            if (!File.Exists(path)) return null;

            var bmp = new BitmapImage();
            bmp.BeginInit();
            bmp.CacheOption = BitmapCacheOption.OnLoad;
            bmp.UriSource = new Uri(path);
            bmp.EndInit();
            bmp.Freeze();
            return bmp;
        }
        catch
        {
            return null;
        }
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();
}
