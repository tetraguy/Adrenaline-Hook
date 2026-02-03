using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace AdrenalineHookWpf.Models;

public sealed class AppEntry : INotifyPropertyChanged
{
    private bool _isChecked;
    private bool _isAlreadyHooked;

    public bool IsChecked
    {
        get => _isChecked;
        set { _isChecked = value; OnPropertyChanged(); }
    }

    public bool IsAlreadyHooked
    {
        get => _isAlreadyHooked;
        set { _isAlreadyHooked = value; OnPropertyChanged(); }
    }

    public string Name { get; init; } = "";
    public string ExePath { get; init; } = "";
    public string? ImagePath { get; init; }
    public string? Publisher { get; init; }
    public string? Version { get; init; }
    public string? Architecture { get; init; }
    public string? InstallLocation { get; init; }
    public string Source { get; init; } = ""; // UWP / Installed / Manual

    public event PropertyChangedEventHandler? PropertyChanged;
    private void OnPropertyChanged([CallerMemberName] string? propName = null)
        => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(propName));
}
