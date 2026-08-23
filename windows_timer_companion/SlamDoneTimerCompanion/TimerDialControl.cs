using System.Drawing;
using System.Windows.Forms;
using System.Drawing.Drawing2D;

namespace SlamDone.TimerCompanion;

public sealed class TimerDialControl : Control
{
    public int Seconds { get; set; } = 1500;
    public double ProgressValue { get; set; }
    public string Mode { get; set; } = "GENERAL";
    public TimerTheme ThemeChoice { get; set; } = TimerTheme.All[0];

    public TimerDialControl()
    {
        SetStyle(ControlStyles.AllPaintingInWmPaint | ControlStyles.OptimizedDoubleBuffer | ControlStyles.ResizeRedraw | ControlStyles.UserPaint, true);
        MinimumSize = new Size(70, 70);
    }

    protected override void OnPaint(PaintEventArgs e)
    {
        base.OnPaint(e);
        e.Graphics.SmoothingMode = SmoothingMode.AntiAlias;
        var size = Math.Min(ClientSize.Width, ClientSize.Height);
        var stroke = Math.Clamp(size * 0.06f, 5f, 11f);
        var rect = new RectangleF((ClientSize.Width - size) / 2f + stroke, (ClientSize.Height - size) / 2f + stroke, size - stroke * 2, size - stroke * 2);

        using var track = new Pen(Color.FromArgb(55, ThemeChoice.Accent), stroke) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        using var active = new Pen(ThemeChoice.Accent, stroke) { StartCap = LineCap.Round, EndCap = LineCap.Round };
        e.Graphics.DrawArc(track, rect, -90, 360);
        e.Graphics.DrawArc(active, rect, -90, (float)(360 * Math.Clamp(ProgressValue, 0, 1)));

        var time = FormatSeconds(Seconds);
        var timeSize = Math.Clamp(size * .22f, 18f, 46f);
        using var timeFont = new Font("Segoe UI", timeSize, FontStyle.Bold, GraphicsUnit.Pixel);
        using var modeFont = new Font("Segoe UI", Math.Clamp(size * .065f, 8f, 11f), FontStyle.Bold, GraphicsUnit.Pixel);
        var timeRect = new Rectangle(0, ClientSize.Height / 2 - (int)(timeSize * .7f), ClientSize.Width, (int)(timeSize * 1.35f));
        TextRenderer.DrawText(e.Graphics, time, timeFont, timeRect, ThemeChoice.Foreground, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
        var modeRect = new Rectangle(0, ClientSize.Height / 2 + (int)(timeSize * .48f), ClientSize.Width, 20);
        TextRenderer.DrawText(e.Graphics, Mode.ToUpperInvariant(), modeFont, modeRect, ThemeChoice.Accent, TextFormatFlags.HorizontalCenter | TextFormatFlags.VerticalCenter | TextFormatFlags.NoPadding);
    }

    private static string FormatSeconds(int seconds)
    {
        seconds = Math.Max(0, seconds);
        var h = seconds / 3600;
        var m = (seconds % 3600) / 60;
        var s = seconds % 60;
        return h > 0 ? $"{h}:{m:00}:{s:00}" : $"{m:00}:{s:00}";
    }
}
