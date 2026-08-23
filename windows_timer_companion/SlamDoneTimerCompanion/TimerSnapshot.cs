using System.Text.Json.Serialization;

namespace SlamDone.TimerCompanion;

public sealed class TimerSnapshot
{
    [JsonPropertyName("mode")] public string Mode { get; set; } = "general";
    [JsonPropertyName("title")] public string Title { get; set; } = "General focus";
    [JsonPropertyName("durationSeconds")] public int DurationSeconds { get; set; } = 1500;
    [JsonPropertyName("remainingSeconds")] public int RemainingSeconds { get; set; } = 1500;
    [JsonPropertyName("elapsedSeconds")] public int ElapsedSeconds { get; set; }
    [JsonPropertyName("running")] public bool Running { get; set; }
    [JsonPropertyName("paused")] public bool Paused { get; set; }
    [JsonPropertyName("autoRepeat")] public bool AutoRepeat { get; set; }
    [JsonPropertyName("startedAtMs")] public long? StartedAtMs { get; set; }
    [JsonPropertyName("endAtMs")] public long? EndAtMs { get; set; }
    [JsonPropertyName("updatedAtMs")] public long? UpdatedAtMs { get; set; }
    [JsonPropertyName("completionToken")] public string CompletionToken { get; set; } = string.Empty;
    [JsonPropertyName("colorIndex")] public int ColorIndex { get; set; }
    [JsonPropertyName("opacity")] public double Opacity { get; set; } = 1.0;
    [JsonPropertyName("windowWidth")] public int WindowWidth { get; set; } = 218;
    [JsonPropertyName("windowHeight")] public int WindowHeight { get; set; } = 214;

    public int LiveSeconds(DateTimeOffset now)
    {
        if (string.Equals(Mode, "stopwatch", StringComparison.OrdinalIgnoreCase))
        {
            if (Running && !Paused && StartedAtMs.HasValue)
            {
                var started = DateTimeOffset.FromUnixTimeMilliseconds(StartedAtMs.Value);
                return Math.Max(0, (int)Math.Floor((now - started).TotalSeconds));
            }
            return Math.Max(0, ElapsedSeconds);
        }

        if (Running && !Paused && EndAtMs.HasValue)
        {
            var end = DateTimeOffset.FromUnixTimeMilliseconds(EndAtMs.Value);
            return Math.Max(0, (int)Math.Ceiling((end - now).TotalSeconds));
        }
        return Math.Max(0, RemainingSeconds);
    }

    public double Progress(DateTimeOffset now)
    {
        if (string.Equals(Mode, "stopwatch", StringComparison.OrdinalIgnoreCase))
            return (LiveSeconds(now) % 60) / 60.0;
        var duration = Math.Max(1, DurationSeconds);
        return Math.Clamp((duration - LiveSeconds(now)) / (double)duration, 0.0, 1.0);
    }
}

public sealed record TimerActionEnvelope(long Seq, string Action);
