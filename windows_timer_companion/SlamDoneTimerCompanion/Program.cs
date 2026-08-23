using System.Drawing;
using System.Windows.Forms;
using System.Diagnostics;

namespace SlamDone.TimerCompanion;

internal static class Program
{
    [STAThread]
    private static void Main(string[] args)
    {
        using var mutex = new Mutex(true, "SlamDone.TimerCompanion.7B8FE84A", out var firstInstance);
        if (!firstInstance) return;
        ApplicationConfiguration.Initialize();
        Application.Run(new CompanionContext(args));
    }
}

internal sealed class CompanionContext : ApplicationContext
{
    private readonly TimerForm _form = new();
    private readonly LocalBridgeServer _server = new();
    private readonly NotifyIcon _tray = new();

    public CompanionContext(string[] args)
    {
        _form.ActionRequested += _server.EnqueueAction;
        _server.StateReceived += snapshot => SafeUi(() => _form.ApplySnapshot(snapshot));
        _server.HideRequested += () => SafeUi(_form.HideTimer);
        _server.ChimeRequested += token => SafeUi(() => _form.PlayChime(token));

        var menu = new ContextMenuStrip();
        menu.Items.Add("Show timer", null, (_, _) => SafeUi(_form.ShowTimer));
        menu.Items.Add("Exit companion", null, (_, _) => ExitCompanion());
        _tray.Icon = SystemIcons.Application;
        _tray.Text = "SlamDone Timer Companion";
        _tray.Visible = true;
        _tray.ContextMenuStrip = menu;
        _tray.DoubleClick += (_, _) => SafeUi(_form.ShowTimer);

        _server.Start();
        if (args.Any(a => string.Equals(a, "--show", StringComparison.OrdinalIgnoreCase))) _form.ShowTimer();
    }

    private void SafeUi(Action action)
    {
        if (_form.IsDisposed) return;
        if (_form.InvokeRequired) _form.BeginInvoke(action);
        else action();
    }

    private void ExitCompanion()
    {
        _tray.Visible = false;
        _server.Dispose();
        _form.Dispose();
        _tray.Dispose();
        ExitThread();
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _tray.Visible = false;
            _server.Dispose();
            _form.Dispose();
            _tray.Dispose();
        }
        base.Dispose(disposing);
    }
}
