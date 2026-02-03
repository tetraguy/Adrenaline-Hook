using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Data;
using System.Windows.Input;
using AdrenalineHookWpf.Models;
using AdrenalineHookWpf.Services;
using AdrenalineHookWpf.Utilities;
using Microsoft.Win32;

namespace AdrenalineHookWpf;

public partial class MainWindow : Window, INotifyPropertyChanged
{
    private readonly GmdbService _gmdb = new();
    private readonly UwpScanner _uwpScanner = new();
    private readonly InstalledSoftwareScanner _installedScanner = new();

    private CancellationTokenSource? _cts;

    public ObservableCollection<AppEntry> Apps { get; } = new();
    public ICollectionView AppsView { get; }

    private string _statusText = "Ready.";
    public string StatusText
    {
        get => _statusText;
        set { _statusText = value; OnPropertyChanged(nameof(StatusText)); }
    }

    private string _busyText = "Working…";
    public string BusyText
    {
        get => _busyText;
        set { _busyText = value; OnPropertyChanged(nameof(BusyText)); }
    }

    private string _footerText = "";
    public string FooterText
    {
        get => _footerText;
        set { _footerText = value; OnPropertyChanged(nameof(FooterText)); }
    }

    private readonly HashSet<string> _existingTitles = new(StringComparer.OrdinalIgnoreCase);

    public MainWindow()
    {
        InitializeComponent();
        DataContext = this;

        AppsView = CollectionViewSource.GetDefaultView(Apps);
        AppsView.SortDescriptions.Add(new SortDescription(nameof(AppEntry.Name), ListSortDirection.Ascending));

        Loaded += MainWindow_Loaded;
    }

    private async void MainWindow_Loaded(object sender, RoutedEventArgs e)
    {
        try
        {
            FooterText = $"Database: {_gmdb.GmdbPath}";
            ProcessUtils.KillProcessByName("RadeonSoftware");

            ReloadExistingTitles();

            // Update check (non-blocking)
            var update = await UpdateChecker.GetUpdateAsync();
            if (update is not null)
            {
                var res = MessageBox.Show(
                    $"A new version ({update.LatestTag}) is available.\n\nOpen the download page now?",
                    "Update Available",
                    MessageBoxButton.YesNo,
                    MessageBoxImage.Information);

                if (res == MessageBoxResult.Yes)
                {
                    ProcessUtils.StartFile(update.HtmlUrl);
                }
            }
        }
        catch (Exception ex)
        {
            Logger.Error("Startup error", ex);
        }
    }

    private void ReloadExistingTitles()
    {
        _existingTitles.Clear();
        foreach (var t in _gmdb.GetExistingTitles())
            _existingTitles.Add(t);
    }

    private void ApplyHookedColoring()
    {
        foreach (var a in Apps)
            a.IsAlreadyHooked = _existingTitles.Contains(a.Name);
    }

    // ---------- Scans ----------
    private async void ScanUwp_Click(object sender, RoutedEventArgs e)
        => await RunScanAsync(async (progress, ct) => await _uwpScanner.ScanAsync(progress, ct), "Scanning UWP/GamePass apps…");

    private async void ScanInstalled_Click(object sender, RoutedEventArgs e)
        => await RunScanAsync(async (progress, ct) => await _installedScanner.ScanAsync(progress, ct), "Scanning installed software…");

    private async void Search_Click(object sender, RoutedEventArgs e)
        => await SearchAllAsync();

    private async Task SearchAllAsync()
    {
        var term = (SearchBox.Text ?? "").Trim();
        if (string.IsNullOrWhiteSpace(term))
        {
            StatusText = "Search term cleared.";
            return;
        }

        await RunScanAsync(async (progress, ct) =>
        {
            // Search both and merge
            var uwpTask = _uwpScanner.SearchAsync(term, progress, ct);
            var instTask = _installedScanner.SearchAsync(term, progress, ct);

            await Task.WhenAll(uwpTask, instTask);

            var merged = uwpTask.Result.Concat(instTask.Result)
                .GroupBy(a => $"{a.Name}|{a.ExePath}", StringComparer.OrdinalIgnoreCase)
                .Select(g => g.First())
                .OrderBy(a => a.Name)
                .ToList();

            return merged;
        }, $"Searching for: {term}");
    }

    private async Task RunScanAsync(Func<IProgress<string>, CancellationToken, Task<System.Collections.Generic.List<AppEntry>>> runner, string busyText)
    {
        try
        {
            _cts?.Cancel();
            _cts = new CancellationTokenSource();

            var ct = _cts.Token;
            var progress = new Progress<string>(s =>
            {
                BusyText = s;
                StatusText = s;
            });

            ShowBusy(busyText);

            var results = await runner(progress, ct);

            Apps.Clear();
            foreach (var a in results)
                Apps.Add(a);

            ApplyHookedColoring();
            StatusText = $"Loaded {Apps.Count} item(s).";
        }
        catch (OperationCanceledException)
        {
            StatusText = "Operation cancelled.";
        }
        catch (Exception ex)
        {
            Logger.Error("Scan failed", ex);
            MessageBox.Show($"Operation failed:\n\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
        finally
        {
            HideBusy();
        }
    }

    private void ShowBusy(string text)
    {
        BusyText = text;
        BusyOverlay.Visibility = Visibility.Visible;
    }

    private void HideBusy()
    {
        BusyOverlay.Visibility = Visibility.Collapsed;
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        _cts?.Cancel();
    }

    // ---------- Hooking ----------
    private void HookSelections_Click(object sender, RoutedEventArgs e)
    {
        var selected = Apps.Where(a => a.IsChecked).ToList();
        if (selected.Count == 0)
        {
            MessageBox.Show("No items selected!", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        var list = string.Join("\n", selected.Select(s => $" - {s.Name}"));
        var confirm = MessageBox.Show(
            $"Do you want to hook the following apps?\n\n{list}",
            "Confirm",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (confirm != MessageBoxResult.Yes)
        {
            MessageBox.Show("Hook Aborted!", "Canceled", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        ProcessUtils.KillProcessByName("RadeonSoftware");

        var (added, skipped) = _gmdb.AddApps(selected);
        ReloadExistingTitles();

        Apps.Clear();

        MessageBox.Show(
            $"Programs hooked to AMD Adrenaline!\n\nAdded: {added}\nSkipped (already present): {skipped}",
            "Success",
            MessageBoxButton.OK,
            MessageBoxImage.Information);

        var open = MessageBox.Show(
            "Would you like to open AMD Adrenaline Software now?",
            "Application(s) Hooked",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (open == MessageBoxResult.Yes)
        {
            OpenAmdInternal();
        }
    }

    private void HookManual_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFileDialog
        {
            Filter = "Executable Files (*.exe)|*.exe",
            Title = "Select Application",
            InitialDirectory = "C:\\"
        };

        if (dlg.ShowDialog(this) != true)
            return;

        var exePath = dlg.FileName;
        var title = System.IO.Path.GetFileNameWithoutExtension(exePath);

        var confirm = MessageBox.Show(
            $"Do you want to hook '{System.IO.Path.GetFileName(exePath)}' to AMD Adrenaline?",
            "Confirm",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (confirm != MessageBoxResult.Yes)
            return;

        ProcessUtils.KillProcessByName("RadeonSoftware");

        var entry = new AppEntry
        {
            Name = title,
            ExePath = exePath,
            ImagePath = exePath,
            Source = "Manual"
        };

        var (added, skipped) = _gmdb.AddApps(new[] { entry });
        ReloadExistingTitles();

        MessageBox.Show(
            added == 1 ? $"{title} hooked successfully!" : $"Nothing added (already present).",
            "Success",
            MessageBoxButton.OK,
            MessageBoxImage.Information);
    }

    // ---------- Database windows ----------
    private void ViewHooked_Click(object sender, RoutedEventArgs e)
    {
        if (!_gmdb.Exists)
        {
            MessageBox.Show("No gmdb.blb file found.", "Not Found", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var win = new Windows.HookedAppsWindow(_gmdb.GetHookedTitles()) { Owner = this };
        win.ShowDialog();
    }

    private void RemoveHooked_Click(object sender, RoutedEventArgs e)
    {
        if (!_gmdb.Exists)
        {
            MessageBox.Show("No gmdb.blb file found.", "Not Found", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var titles = _gmdb.GetHookedTitles();
        var win = new Windows.RemoveHookedWindow(titles) { Owner = this };
        if (win.ShowDialog() == true)
        {
            ProcessUtils.KillProcessByName("RadeonSoftware");
            var removed = _gmdb.RemoveTitles(win.SelectedTitles);
            ReloadExistingTitles();

            MessageBox.Show($"Removed {removed} item(s).", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
        }
    }

    private void DbEditor_Click(object sender, RoutedEventArgs e)
    {
        var win = new Windows.JsonEditorWindow(_gmdb) { Owner = this };
        win.ShowDialog();
    }

    // ---------- Backup/Restore/Verify/Reset ----------
    private void Backup_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (!_gmdb.Exists)
            {
                MessageBox.Show("No gmdb.blb file found to back up.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            var confirm = MessageBox.Show("Are you sure you want to backup the current database?",
                "Confirm Backup", MessageBoxButton.YesNo, MessageBoxImage.Question);

            if (confirm != MessageBoxResult.Yes) return;

            _gmdb.Backup();
            MessageBox.Show("Backup created successfully!", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Backup failed:\n\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void Restore_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var confirm = MessageBox.Show(
                "Are you sure you want to restore the backup? This will overwrite the current version.",
                "Confirm Restore",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);

            if (confirm != MessageBoxResult.Yes) return;

            _gmdb.Restore();
            ReloadExistingTitles();
            MessageBox.Show("Backup restored successfully!", "Restored", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Restore failed:\n\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void Verify_Click(object sender, RoutedEventArgs e)
    {
        if (!_gmdb.Exists)
        {
            MessageBox.Show("No gmdb.blb file found.", "Not Found", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var (total, missing) = _gmdb.GetVerifyStats();
        MessageBox.Show($"✔ {total} games hooked\n⚠ {missing} executables missing", "Adrenaline Hook Summary",
            MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void Reset_Click(object sender, RoutedEventArgs e)
    {
        var confirm = MessageBox.Show(
            "Would you like to reset AMD Adrenaline Game settings database?",
            "Confirm Reset",
            MessageBoxButton.YesNo,
            MessageBoxImage.Question);

        if (confirm != MessageBoxResult.Yes)
            return;

        try
        {
            ProcessUtils.KillProcessByName("RadeonSoftware");
            _gmdb.ResetDatabase();

            MessageBox.Show(
                "Database has been reset! AMD Adrenaline Software will start soon to rebuild the database.",
                "Reset Complete",
                MessageBoxButton.OK,
                MessageBoxImage.Information);

            OpenAmdInternal();
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Reset failed:\n\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    // ---------- Info / links ----------
    private void Info_Click(object sender, RoutedEventArgs e)
    {
        var info = SystemInfoService.BuildSummary(UpdateChecker.CurrentVersionTag);
        MessageBox.Show(info, "System Info", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void GitHub_Click(object sender, RoutedEventArgs e)
        => ProcessUtils.StartFile("https://github.com/tetraguy/Adrenaline-Hook/");

    private void Tutorial_Click(object sender, RoutedEventArgs e)
        => ProcessUtils.StartFile("https://www.youtube.com/watch?v=SsagApi-B9U");

    // ---------- AMD Software ----------
    private void OpenAmd_Click(object sender, RoutedEventArgs e) => OpenAmdInternal();

    private void OpenAmdInternal()
    {
        if (!AmdSoftwareLauncher.TryLaunch())
        {
            var res = MessageBox.Show(
                "AMD Software could not be found in standard install paths.\n\nOpen AMD download page?",
                "Launch Failed",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning);

            if (res == MessageBoxResult.Yes)
                AmdSoftwareLauncher.OpenDownloadPage();
        }
    }

    // ---------- Grid context menu ----------
    private AppEntry? SelectedEntry => AppsGrid.SelectedItem as AppEntry;

    private void AppsGrid_MouseRightButtonDown(object sender, MouseButtonEventArgs e)
    {
        // Ensure row under cursor becomes selected (so context menu operates on it)
        var dep = e.OriginalSource as System.Windows.DependencyObject;
        while (dep != null && dep is not System.Windows.Controls.DataGridRow)
            dep = System.Windows.Media.VisualTreeHelper.GetParent(dep);

        if (dep is System.Windows.Controls.DataGridRow row)
        {
            AppsGrid.SelectedItem = row.Item;
        }
    }

    private void CtxHookThis_Click(object sender, RoutedEventArgs e)
    {
        if (SelectedEntry is null) return;
        MessageBox.Show($"To hook: {SelectedEntry.Name}\n\nCheck the box next to it, then click 'Hook Selection(s)'.",
            "How to hook", MessageBoxButton.OK, MessageBoxImage.Information);
    }

    private void CtxOpenLocation_Click(object sender, RoutedEventArgs e)
    {
        if (SelectedEntry is null) return;
        ProcessUtils.OpenFolderForPath(SelectedEntry.ExePath);
    }

    private void CtxDetails_Click(object sender, RoutedEventArgs e)
    {
        if (SelectedEntry is null) return;
        var win = new Windows.AppDetailsWindow(SelectedEntry) { Owner = this };
        win.ShowDialog();
    }

    private void CtxStart_Click(object sender, RoutedEventArgs e)
    {
        if (SelectedEntry is null) return;

        try
        {
            ProcessUtils.StartFile(SelectedEntry.ExePath);
        }
        catch (Exception ex)
        {
            MessageBox.Show($"Failed to start application.\n\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    // ---------- Search box enter ----------
    private async void SearchBox_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key == Key.Enter)
            await SearchAllAsync();
    }

    // ---------- INotifyPropertyChanged ----------
    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged(string propertyName)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propertyName));
}
