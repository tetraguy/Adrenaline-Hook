using System.ComponentModel;
using System.Text.Json;
using System.Windows;
using AdrenalineHookWpf.Services;

namespace AdrenalineHookWpf.Windows;

public partial class JsonEditorWindow : Window, INotifyPropertyChanged
{
    private readonly GmdbService _gmdb;

    public string PathText => $"File: {_gmdb.GmdbPath}";

    public JsonEditorWindow(GmdbService gmdb)
    {
        _gmdb = gmdb;
        InitializeComponent();
        DataContext = this;
        Reload();
    }

    private void Reload()
    {
        Editor.Text = _gmdb.ReadRawText();
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(nameof(PathText)));
    }

    private void Reload_Click(object sender, RoutedEventArgs e) => Reload();

    private void Save_Click(object sender, RoutedEventArgs e)
    {
        var text = Editor.Text ?? "";

        try
        {
            JsonDocument.Parse(text);
        }
        catch (JsonException ex)
        {
            MessageBox.Show($"Invalid JSON — file not saved.\n\n{ex.Message}", "JSON Error", MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        try
        {
            _gmdb.SaveRawText(text);
            MessageBox.Show("Saved successfully.", "Saved", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (System.Exception ex)
        {
            MessageBox.Show($"Save failed:\n\n{ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
}
