using System.Drawing;
using System.Windows.Forms;
using System.Media;
using System.Reflection;
using System.Runtime.InteropServices;

namespace SlamDone.TimerCompanion;

public sealed class TimerForm : Form
{
    private const int WmNclButtonDown = 0xA1;
    private const int HtCaption = 0x2;
    private const int HtBottomRight = 17;

    [DllImport("user32.dll")] private static extern bool ReleaseCapture();
    [DllImport("user32.dll")] private static extern IntPtr SendMessage(IntPtr hWnd, int msg, IntPtr wParam, IntPtr lParam);

    private readonly TableLayoutPanel _layout = new();
    private readonly Panel _header = new();
    private readonly Label _title = new();
    private readonly Button _opacityButton = new();
    private readonly Button _themeButton = new();
    private readonly Button _pinButton = new();
    private readonly Button _closeButton = new();
    private readonly Panel _opacityPanel = new();
    private readonly TrackBar _opacityTrack = new();
    private readonly TimerDialControl _dial = new();
    private readonly FlowLayoutPanel _controls = new();
    private readonly Button _toggleButton = new();
    private readonly Button _resetButton = new();
    private readonly Button _stopButton = new();
    private readonly Button _stopwatchButton = new();
    private readonly Label _resizeGrip = new();
    private readonly ToolTip _tips = new();
    private readonly ContextMenuStrip _themeMenu = new();
    private readonly System.Windows.Forms.Timer _ticker = new() { Interval = 250 };
    private readonly HashSet<string> _playedTokens = new(StringComparer.Ordinal);
    private readonly MemoryStream? _chimeStream;
    private readonly SoundPlayer? _chimePlayer;

    private TimerSnapshot _snapshot = new();
    private int _themeIndex;
    private string _deadlineQueuedToken = string.Empty;
    private bool _applyingSnapshot;

    public event Action<string>? ActionRequested;

    public TimerForm()
    {
        Text = "SlamDone Timer";
        FormBorderStyle = FormBorderStyle.None;
        TopMost = true;
        ShowInTaskbar = false;
        StartPosition = FormStartPosition.Manual;
        MinimumSize = new Size(170, 170);
        Size = new Size(218, 214);
        Opacity = 1.0;
        KeyPreview = true;
        DoubleBuffered = true;

        _layout.Dock = DockStyle.Fill;
        _layout.ColumnCount = 1;
        _layout.RowCount = 4;
        _layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 34));
        _layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 0));
        _layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
        _layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 38));
        Controls.Add(_layout);

        BuildHeader();
        BuildOpacityPanel();
        BuildDial();
        BuildControls();
        BuildThemeMenu();

        _resizeGrip.Text = "◢";
        _resizeGrip.AutoSize = false;
        _resizeGrip.Size = new Size(22, 22);
        _resizeGrip.TextAlign = ContentAlignment.BottomRight;
        _resizeGrip.Cursor = Cursors.SizeNWSE;
        _resizeGrip.Anchor = AnchorStyles.Bottom | AnchorStyles.Right;
        _resizeGrip.Location = new Point(ClientSize.Width - 24, ClientSize.Height - 24);
        _tips.SetToolTip(_resizeGrip, "Resize timer");
        _resizeGrip.MouseDown += (_, e) => BeginNativeMove(e, HtBottomRight);
        Controls.Add(_resizeGrip);
        _resizeGrip.BringToFront();

        Resize += (_, _) =>
        {
            _resizeGrip.Location = new Point(ClientSize.Width - 24, ClientSize.Height - 24);
            _resizeGrip.BringToFront();
        };
        Shown += (_, _) => _resizeGrip.BringToFront();

        _ticker.Tick += (_, _) => RenderLiveState();
        _ticker.Start();

        (_chimeStream, _chimePlayer) = LoadChime();
        ApplyTheme(0, queueAction: false);
        RenderLiveState();
    }

    private void BuildHeader()
    {
        _header.Dock = DockStyle.Fill;
        _header.Padding = new Padding(8, 2, 2, 2);
        _header.Cursor = Cursors.SizeAll;
        _header.MouseDown += (_, e) => BeginNativeMove(e, HtCaption);
        _layout.Controls.Add(_header, 0, 0);

        _title.Dock = DockStyle.Fill;
        _title.Text = "General focus";
        _title.TextAlign = ContentAlignment.MiddleLeft;
        _title.Font = new Font("Segoe UI", 9f, FontStyle.Bold);
        _title.AutoEllipsis = true;
        _title.Cursor = Cursors.SizeAll;
        _title.MouseDown += (_, e) => BeginNativeMove(e, HtCaption);
        _header.Controls.Add(_title);

        ConfigureHeaderButton(_closeButton, "×", "Close timer", (_, _) =>
        {
            QueueAction("close");
            HideTimer();
        });
        ConfigureHeaderButton(_pinButton, "📌", "Return timer to SlamDone", (_, _) =>
        {
            QueueAction("unpin");
            HideTimer();
        });
        ConfigureHeaderButton(_themeButton, "●", "Timer themes", (_, _) =>
        {
            _themeMenu.Show(_themeButton, new Point(0, _themeButton.Height));
        });
        ConfigureHeaderButton(_opacityButton, "◐", "Transparency", (_, _) => ToggleOpacityPanel());

        var x = _header.Width;
        _closeButton.Dock = DockStyle.Right;
        _pinButton.Dock = DockStyle.Right;
        _themeButton.Dock = DockStyle.Right;
        _opacityButton.Dock = DockStyle.Right;
        _header.Controls.Add(_closeButton);
        _header.Controls.Add(_pinButton);
        _header.Controls.Add(_themeButton);
        _header.Controls.Add(_opacityButton);
        _closeButton.BringToFront();
        _pinButton.BringToFront();
        _themeButton.BringToFront();
        _opacityButton.BringToFront();
        _title.BringToFront();
        _ = x;
    }

    private void ConfigureHeaderButton(Button button, string text, string tooltip, EventHandler handler)
    {
        button.Text = text;
        button.Width = 28;
        button.Dock = DockStyle.Right;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 0;
        button.Margin = Padding.Empty;
        button.Padding = Padding.Empty;
        button.TabStop = false;
        button.Cursor = Cursors.Hand;
        button.Click += handler;
        _tips.SetToolTip(button, tooltip);
    }

    private void BuildOpacityPanel()
    {
        _opacityPanel.Dock = DockStyle.Fill;
        _opacityPanel.Padding = new Padding(8, 1, 8, 1);
        _layout.Controls.Add(_opacityPanel, 0, 1);

        _opacityTrack.Dock = DockStyle.Fill;
        _opacityTrack.Minimum = 20;
        _opacityTrack.Maximum = 100;
        _opacityTrack.TickStyle = TickStyle.None;
        _opacityTrack.Value = 100;
        _opacityTrack.SmallChange = 5;
        _opacityTrack.LargeChange = 10;
        _opacityTrack.ValueChanged += (_, _) =>
        {
            if (_applyingSnapshot) return;
            var value = Math.Clamp(_opacityTrack.Value / 100.0, .20, 1.0);
            Opacity = value;
            _snapshot.Opacity = value;
            QueueAction($"opacity:{value:0.00}");
        };
        _opacityPanel.Controls.Add(_opacityTrack);
    }

    private void ToggleOpacityPanel()
    {
        var row = _layout.RowStyles[1];
        row.Height = row.Height > 0 ? 0 : 34;
        _layout.PerformLayout();
    }

    private void BuildDial()
    {
        var panel = new Panel { Dock = DockStyle.Fill, Padding = new Padding(8, 5, 8, 2) };
        _dial.Dock = DockStyle.Fill;
        panel.Controls.Add(_dial);
        _layout.Controls.Add(panel, 0, 2);
    }

    private void BuildControls()
    {
        _controls.Dock = DockStyle.Fill;
        _controls.FlowDirection = FlowDirection.LeftToRight;
        _controls.WrapContents = false;
        _controls.AutoSize = false;
        _controls.Padding = new Padding(5, 3, 5, 3);
        _controls.Resize += (_, _) => CenterControlButtons();
        _layout.Controls.Add(_controls, 0, 3);

        ConfigureActionButton(_toggleButton, "▶ Start", (_, _) => ToggleTimerOptimistically());
        ConfigureActionButton(_resetButton, "↻", (_, _) => ResetOptimistically());
        ConfigureActionButton(_stopButton, "■", (_, _) => StopOptimistically());
        ConfigureActionButton(_stopwatchButton, "⏱", (_, _) => StopwatchOptimistically());
        _tips.SetToolTip(_resetButton, "Reset");
        _tips.SetToolTip(_stopButton, "Stop & log");
        _tips.SetToolTip(_stopwatchButton, "Stopwatch");
        _controls.Controls.AddRange(new Control[] { _toggleButton, _resetButton, _stopButton, _stopwatchButton });
    }

    private void ConfigureActionButton(Button button, string text, EventHandler handler)
    {
        button.Text = text;
        button.AutoSize = false;
        button.Height = 29;
        button.Width = text.Contains("Start", StringComparison.Ordinal) ? 72 : 34;
        button.FlatStyle = FlatStyle.Flat;
        button.FlatAppearance.BorderSize = 1;
        button.Margin = new Padding(2, 0, 2, 0);
        button.Cursor = Cursors.Hand;
        button.Click += handler;
    }

    private void CenterControlButtons()
    {
        var total = _controls.Controls.Cast<Control>().Sum(c => c.Width + c.Margin.Horizontal);
        _controls.Padding = new Padding(Math.Max(4, (_controls.ClientSize.Width - total) / 2), 3, 4, 3);
    }

    private void BuildThemeMenu()
    {
        for (var i = 0; i < TimerTheme.All.Count; i++)
        {
            var index = i;
            var theme = TimerTheme.All[index];
            var item = new ToolStripMenuItem(theme.Name)
            {
                BackColor = theme.Background,
                ForeColor = theme.Foreground,
            };
            item.Click += (_, _) => ApplyTheme(index, queueAction: true);
            _themeMenu.Items.Add(item);
        }
    }

    public void ApplySnapshot(TimerSnapshot snapshot)
    {
        if (InvokeRequired)
        {
            BeginInvoke(new Action(() => ApplySnapshot(snapshot)));
            return;
        }

        _applyingSnapshot = true;
        try
        {
            var firstShow = !Visible;
            _snapshot = snapshot;
            _title.Text = string.IsNullOrWhiteSpace(snapshot.Title) ? "General focus" : snapshot.Title;
            ApplyTheme(snapshot.ColorIndex, queueAction: false);
            var opacity = Math.Clamp(snapshot.Opacity, .20, 1.0);
            Opacity = opacity;
            _opacityTrack.Value = Math.Clamp((int)Math.Round(opacity * 100), 20, 100);

            if (firstShow)
            {
                var width = Math.Clamp(snapshot.WindowWidth, MinimumSize.Width, 760);
                var height = Math.Clamp(snapshot.WindowHeight, MinimumSize.Height, 840);
                Size = new Size(width, height);
                var area = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1280, 720);
                Location = new Point(Math.Max(area.Left, area.Right - width - 24), Math.Max(area.Top, area.Bottom - height - 64));
            }

            ShowTimer();
            RenderLiveState();
        }
        finally
        {
            _applyingSnapshot = false;
        }
    }

    public void ShowTimer()
    {
        if (!Visible) Show();
        TopMost = true;
        BringToFront();
        Activate();
    }

    public void HideTimer()
    {
        if (Visible) Hide();
    }

    public void PlayChime(string token)
    {
        if (InvokeRequired)
        {
            BeginInvoke(new Action(() => PlayChime(token)));
            return;
        }
        token = string.IsNullOrWhiteSpace(token) ? "timer-complete" : token;
        if (!_playedTokens.Add(token)) return;
        if (_playedTokens.Count > 80) _playedTokens.Clear();
        try { _chimePlayer?.Play(); } catch { }
    }

    private void RenderLiveState()
    {
        var now = DateTimeOffset.UtcNow;
        var seconds = _snapshot.LiveSeconds(now);
        _dial.Seconds = seconds;
        _dial.ProgressValue = _snapshot.Progress(now);
        _dial.Mode = _snapshot.Mode;
        _dial.ThemeChoice = TimerTheme.At(_themeIndex);
        _dial.Invalidate();
        _toggleButton.Text = !_snapshot.Running && !_snapshot.Paused ? "▶ Start" : (_snapshot.Paused ? "▶ Resume" : "Ⅱ Pause");
        _title.Text = string.IsNullOrWhiteSpace(_snapshot.Title) ? "General focus" : _snapshot.Title;

        if (!string.Equals(_snapshot.Mode, "stopwatch", StringComparison.OrdinalIgnoreCase) &&
            _snapshot.Running && !_snapshot.Paused && seconds <= 0)
        {
            var token = string.IsNullOrWhiteSpace(_snapshot.CompletionToken) ? "timer-complete" : _snapshot.CompletionToken;
            PlayChime(token);
            if (!string.Equals(_deadlineQueuedToken, token, StringComparison.Ordinal))
            {
                _deadlineQueuedToken = token;
                QueueAction("deadline");
            }
        }
        else if (seconds > 0 && !string.Equals(_deadlineQueuedToken, _snapshot.CompletionToken, StringComparison.Ordinal))
        {
            _deadlineQueuedToken = string.Empty;
        }
    }

    private void ToggleTimerOptimistically()
    {
        var now = DateTimeOffset.UtcNow;
        if (!_snapshot.Running && !_snapshot.Paused)
        {
            _snapshot.Running = true;
            _snapshot.Paused = false;
            _snapshot.StartedAtMs = now.ToUnixTimeMilliseconds();
            if (!string.Equals(_snapshot.Mode, "stopwatch", StringComparison.OrdinalIgnoreCase))
                _snapshot.EndAtMs = now.AddSeconds(Math.Max(0, _snapshot.RemainingSeconds)).ToUnixTimeMilliseconds();
        }
        else if (_snapshot.Paused)
        {
            _snapshot.Running = true;
            _snapshot.Paused = false;
            _snapshot.StartedAtMs = now.ToUnixTimeMilliseconds();
            if (!string.Equals(_snapshot.Mode, "stopwatch", StringComparison.OrdinalIgnoreCase))
                _snapshot.EndAtMs = now.AddSeconds(Math.Max(0, _snapshot.RemainingSeconds)).ToUnixTimeMilliseconds();
        }
        else
        {
            var seconds = _snapshot.LiveSeconds(now);
            if (string.Equals(_snapshot.Mode, "stopwatch", StringComparison.OrdinalIgnoreCase))
                _snapshot.ElapsedSeconds = seconds;
            else
                _snapshot.RemainingSeconds = seconds;
            _snapshot.Running = false;
            _snapshot.Paused = true;
            _snapshot.StartedAtMs = null;
            _snapshot.EndAtMs = null;
        }
        QueueAction("toggle");
        RenderLiveState();
    }

    private void ResetOptimistically()
    {
        _snapshot.Running = false;
        _snapshot.Paused = false;
        _snapshot.ElapsedSeconds = 0;
        _snapshot.RemainingSeconds = string.Equals(_snapshot.Mode, "stopwatch", StringComparison.OrdinalIgnoreCase) ? 0 : _snapshot.DurationSeconds;
        _snapshot.StartedAtMs = null;
        _snapshot.EndAtMs = null;
        QueueAction("reset");
        RenderLiveState();
    }

    private void StopOptimistically()
    {
        var now = DateTimeOffset.UtcNow;
        var seconds = _snapshot.LiveSeconds(now);
        if (string.Equals(_snapshot.Mode, "stopwatch", StringComparison.OrdinalIgnoreCase))
            _snapshot.ElapsedSeconds = seconds;
        else
            _snapshot.RemainingSeconds = seconds;
        _snapshot.Running = false;
        _snapshot.Paused = false;
        _snapshot.StartedAtMs = null;
        _snapshot.EndAtMs = null;
        QueueAction("stop");
        RenderLiveState();
    }

    private void StopwatchOptimistically()
    {
        var now = DateTimeOffset.UtcNow;
        _snapshot.Mode = "stopwatch";
        _snapshot.Title = "Study stopwatch";
        _snapshot.Running = true;
        _snapshot.Paused = false;
        _snapshot.ElapsedSeconds = 0;
        _snapshot.RemainingSeconds = 0;
        _snapshot.StartedAtMs = now.ToUnixTimeMilliseconds();
        _snapshot.EndAtMs = null;
        QueueAction("stopwatch");
        RenderLiveState();
    }

    private void ApplyTheme(int index, bool queueAction)
    {
        _themeIndex = Math.Clamp(index, 0, TimerTheme.All.Count - 1);
        _snapshot.ColorIndex = _themeIndex;
        var theme = TimerTheme.At(_themeIndex);
        BackColor = theme.Background;
        ForeColor = theme.Foreground;
        _layout.BackColor = theme.Background;
        _header.BackColor = Blend(theme.Background, theme.Accent, .14);
        _header.ForeColor = theme.Foreground;
        _title.ForeColor = theme.Foreground;
        _opacityPanel.BackColor = theme.Background;
        _controls.BackColor = theme.Background;
        _dial.BackColor = theme.Background;
        _dial.ThemeChoice = theme;
        _resizeGrip.BackColor = theme.Background;
        _resizeGrip.ForeColor = theme.Accent;
        _opacityTrack.BackColor = theme.Background;
        foreach (var button in new[] { _opacityButton, _themeButton, _pinButton, _closeButton })
        {
            button.BackColor = _header.BackColor;
            button.ForeColor = theme.Foreground;
            button.FlatAppearance.MouseOverBackColor = Blend(theme.Background, theme.Accent, .20);
        }
        foreach (var button in new[] { _toggleButton, _resetButton, _stopButton, _stopwatchButton })
        {
            button.BackColor = button == _toggleButton ? theme.Accent : theme.Background;
            button.ForeColor = button == _toggleButton ? ContrastText(theme.Accent) : theme.Foreground;
            button.FlatAppearance.BorderColor = Blend(theme.Background, theme.Accent, .45);
        }
        Invalidate(true);
        if (queueAction) QueueAction($"color:{_themeIndex}");
    }

    private void QueueAction(string action) => ActionRequested?.Invoke(action);

    private void BeginNativeMove(MouseEventArgs e, int hitTest)
    {
        if (e.Button != MouseButtons.Left) return;
        ReleaseCapture();
        SendMessage(Handle, WmNclButtonDown, (IntPtr)hitTest, IntPtr.Zero);
    }

    private static Color Blend(Color a, Color b, double amount)
    {
        amount = Math.Clamp(amount, 0, 1);
        return Color.FromArgb(
            (int)Math.Round(a.R + (b.R - a.R) * amount),
            (int)Math.Round(a.G + (b.G - a.G) * amount),
            (int)Math.Round(a.B + (b.B - a.B) * amount));
    }

    private static Color ContrastText(Color color)
    {
        var luminance = (0.299 * color.R + 0.587 * color.G + 0.114 * color.B) / 255.0;
        return luminance > .62 ? Color.Black : Color.White;
    }

    private static (MemoryStream?, SoundPlayer?) LoadChime()
    {
        try
        {
            var assembly = Assembly.GetExecutingAssembly();
            var name = assembly.GetManifestResourceNames().FirstOrDefault(n => n.EndsWith("soft_chime.wav", StringComparison.OrdinalIgnoreCase));
            if (name is null) return (null, null);
            using var source = assembly.GetManifestResourceStream(name);
            if (source is null) return (null, null);
            var memory = new MemoryStream();
            source.CopyTo(memory);
            memory.Position = 0;
            var player = new SoundPlayer(memory);
            player.Load();
            return (memory, player);
        }
        catch
        {
            return (null, null);
        }
    }


    protected override void OnFormClosing(FormClosingEventArgs e)
    {
        if (e.CloseReason == CloseReason.UserClosing)
        {
            e.Cancel = true;
            QueueAction("close");
            HideTimer();
            return;
        }
        base.OnFormClosing(e);
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing)
        {
            _ticker.Dispose();
            _themeMenu.Dispose();
            _tips.Dispose();
            _chimePlayer?.Dispose();
            _chimeStream?.Dispose();
        }
        base.Dispose(disposing);
    }
}
