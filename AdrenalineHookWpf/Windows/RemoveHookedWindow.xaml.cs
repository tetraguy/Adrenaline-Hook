using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Linq;
using System.Windows;

namespace AdrenalineHookWpf.Windows;

public partial class RemoveHookedWindow : Window
{
    public sealed class TitleItem
    {
        public bool IsChecked { get; set; }
        public string Title { get; init; } = "";
    }

    public ObservableCollection<TitleItem> Items { get; } = new();
    public List<string> SelectedTitles { get; private set; } = new();

    public RemoveHookedWindow(IEnumerable<string> titles)
    {
        InitializeComponent();
        DataContext = this;

        foreach (var t in titles)
            Items.Add(new TitleItem { Title = t });
    }

    private void Cancel_Click(object sender, RoutedEventArgs e)
    {
        DialogResult = false;
        Close();
    }

    private void Ok_Click(object sender, RoutedEventArgs e)
    {
        var picked = Items.Where(i => i.IsChecked).Select(i => i.Title).ToList();
        if (picked.Count == 0)
        {
            MessageBox.Show("No application(s) selected.", "Notice", MessageBoxButton.OK, MessageBoxImage.Information);
            return;
        }

        var msg = "Are you sure you want to remove the following application(s)?\n\n" + string.Join("\n", picked);
        var confirm = MessageBox.Show(msg, "Confirm Removal", MessageBoxButton.YesNo, MessageBoxImage.Warning);
        if (confirm != MessageBoxResult.Yes)
            return;

        SelectedTitles = picked;
        DialogResult = true;
        Close();
    }
}
