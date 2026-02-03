using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel;
using System.Windows;

namespace AdrenalineHookWpf.Windows;

public partial class HookedAppsWindow : Window, INotifyPropertyChanged
{
    public ObservableCollection<string> Titles { get; } = new();

    public string CountText => $"Total: {Titles.Count}";

    public HookedAppsWindow(IEnumerable<string> titles)
    {
        InitializeComponent();
        DataContext = this;

        foreach (var t in titles)
            Titles.Add(t);

        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(CountText)));
    }

    private void Close_Click(object sender, RoutedEventArgs e) => Close();

    public event PropertyChangedEventHandler? PropertyChanged;
}
