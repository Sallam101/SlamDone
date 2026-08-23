using System.Net;
using System.Net.Sockets;
using System.Text;
using System.Text.Json;

namespace SlamDone.TimerCompanion;

public sealed class LocalBridgeServer : IDisposable
{
    public const string Endpoint = "http://127.0.0.1:37110";
    private readonly TcpListener _listener = new(IPAddress.Loopback, 37110);
    private readonly CancellationTokenSource _cts = new();
    private readonly object _actionLock = new();
    private readonly List<TimerActionEnvelope> _actions = new();
    private readonly SemaphoreSlim _actionSignal = new(0, int.MaxValue);
    private long _actionSequence;
    private Task? _acceptLoop;
    private int _disposed;

    public event Action<TimerSnapshot>? StateReceived;
    public event Action? HideRequested;
    public event Action<string>? ChimeRequested;

    public void Start()
    {
        _listener.Start();
        _acceptLoop = Task.Run(AcceptLoopAsync);
    }

    public void EnqueueAction(string action)
    {
        var envelope = new TimerActionEnvelope(Interlocked.Increment(ref _actionSequence), action);
        lock (_actionLock)
        {
            _actions.Add(envelope);
            if (_actions.Count > 120) _actions.RemoveRange(0, _actions.Count - 120);
        }
        try { _actionSignal.Release(); } catch { }
    }

    private async Task AcceptLoopAsync()
    {
        while (!_cts.IsCancellationRequested)
        {
            try
            {
                var client = await _listener.AcceptTcpClientAsync(_cts.Token);
                _ = Task.Run(() => HandleClientAsync(client), _cts.Token);
            }
            catch (OperationCanceledException) { break; }
            catch when (_cts.IsCancellationRequested) { break; }
        }
    }

    private async Task HandleClientAsync(TcpClient client)
    {
        using (client)
        using (var stream = client.GetStream())
        {
            try
            {
                var request = await ReadRequestAsync(stream, _cts.Token);
                if (request is null) return;
                var method = request.Method;
                var target = request.Target;
                var headers = request.Headers;
                headers.TryGetValue("Origin", out var origin);
                var allowedOrigin = NormalizeAllowedOrigin(origin);

                if (method == "OPTIONS")
                {
                    if (allowedOrigin is null) { await WriteResponseAsync(stream, 403, "text/plain", "Forbidden", null, false); return; }
                    await WriteResponseAsync(stream, 204, "text/plain", string.Empty, allowedOrigin, true);
                    return;
                }
                if (allowedOrigin is null)
                {
                    await WriteResponseAsync(stream, 403, "application/json", "{\"ok\":false}", null, false);
                    return;
                }

                var path = target.Split('?', 2)[0];
                var query = target.Contains('?') ? target[(target.IndexOf('?') + 1)..] : string.Empty;
                var body = Encoding.UTF8.GetString(request.Body);

                if (method == "GET" && path == "/health")
                {
                    await WriteJsonAsync(stream, new { ok = true, version = "7.12.0", endpoint = "127.0.0.1:37110" }, allowedOrigin);
                    return;
                }
                if (method == "POST" && path == "/state")
                {
                    var snapshot = JsonSerializer.Deserialize<TimerSnapshot>(body, JsonOptions);
                    if (snapshot is null) { await WriteResponseAsync(stream, 400, "application/json", "{\"ok\":false}", allowedOrigin, false); return; }
                    StateReceived?.Invoke(snapshot);
                    await WriteJsonAsync(stream, new { ok = true }, allowedOrigin);
                    return;
                }
                if (method == "POST" && path == "/hide")
                {
                    HideRequested?.Invoke();
                    await WriteJsonAsync(stream, new { ok = true }, allowedOrigin);
                    return;
                }
                if (method == "POST" && path == "/chime")
                {
                    var payload = JsonSerializer.Deserialize<Dictionary<string, string>>(body, JsonOptions);
                    var token = payload is not null && payload.TryGetValue("token", out var value) ? value : "timer-complete";
                    ChimeRequested?.Invoke(token);
                    await WriteJsonAsync(stream, new { ok = true }, allowedOrigin);
                    return;
                }
                if (method == "GET" && path == "/actions")
                {
                    var values = ParseQuery(query);
                    _ = long.TryParse(values.GetValueOrDefault("after"), out var after);
                    var waitMs = int.TryParse(values.GetValueOrDefault("wait"), out var parsedWait) ? Math.Clamp(parsedWait, 0, 15000) : 12000;
                    var actions = GetActionsAfter(after);
                    if (actions.Count == 0 && waitMs > 0)
                    {
                        try { await _actionSignal.WaitAsync(waitMs, _cts.Token); } catch { }
                        actions = GetActionsAfter(after);
                    }
                    await WriteJsonAsync(stream, new { ok = true, actions }, allowedOrigin);
                    return;
                }

                await WriteResponseAsync(stream, 404, "application/json", "{\"ok\":false,\"error\":\"not_found\"}", allowedOrigin, false);
            }
            catch
            {
                try { await WriteResponseAsync(stream, 500, "application/json", "{\"ok\":false}", null, false); } catch { }
            }
        }
    }

    private sealed record HttpRequestData(string Method, string Target, Dictionary<string, string> Headers, byte[] Body);

    private static async Task<HttpRequestData?> ReadRequestAsync(NetworkStream stream, CancellationToken cancellationToken)
    {
        const int maxHeaderBytes = 64 * 1024;
        const int maxBodyBytes = 1_000_000;
        var collected = new List<byte>(8192);
        var buffer = new byte[4096];
        var headerEnd = -1;

        while (headerEnd < 0)
        {
            var read = await stream.ReadAsync(buffer.AsMemory(0, buffer.Length), cancellationToken);
            if (read <= 0) return null;
            collected.AddRange(buffer.AsSpan(0, read).ToArray());
            if (collected.Count > maxHeaderBytes) throw new InvalidDataException("HTTP header too large");
            headerEnd = FindHeaderEnd(collected);
        }

        var headerBytes = collected.Take(headerEnd).ToArray();
        var headerText = Encoding.ASCII.GetString(headerBytes);
        var lines = headerText.Split("\r\n", StringSplitOptions.None);
        if (lines.Length == 0) return null;
        var first = lines[0].Split(' ', 3, StringSplitOptions.RemoveEmptyEntries);
        if (first.Length < 2) return null;
        var headers = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var line in lines.Skip(1))
        {
            var colon = line.IndexOf(':');
            if (colon > 0) headers[line[..colon].Trim()] = line[(colon + 1)..].Trim();
        }

        var contentLength = 0;
        if (headers.TryGetValue("Content-Length", out var rawLength)) int.TryParse(rawLength, out contentLength);
        contentLength = Math.Clamp(contentLength, 0, maxBodyBytes);
        var body = new byte[contentLength];
        var bodyStart = headerEnd + 4;
        var available = Math.Min(contentLength, Math.Max(0, collected.Count - bodyStart));
        if (available > 0) collected.CopyTo(bodyStart, body, 0, available);
        var offset = available;
        while (offset < contentLength)
        {
            var read = await stream.ReadAsync(body.AsMemory(offset, contentLength - offset), cancellationToken);
            if (read <= 0) break;
            offset += read;
        }
        if (offset != contentLength) Array.Resize(ref body, offset);
        return new HttpRequestData(first[0].ToUpperInvariant(), first[1], headers, body);
    }

    private static int FindHeaderEnd(List<byte> bytes)
    {
        for (var i = 0; i <= bytes.Count - 4; i++)
        {
            if (bytes[i] == 13 && bytes[i + 1] == 10 && bytes[i + 2] == 13 && bytes[i + 3] == 10) return i;
        }
        return -1;
    }

    private List<TimerActionEnvelope> GetActionsAfter(long after)
    {
        lock (_actionLock) return _actions.Where(item => item.Seq > after).ToList();
    }

    private static Dictionary<string, string> ParseQuery(string query)
    {
        var result = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        foreach (var part in query.Split('&', StringSplitOptions.RemoveEmptyEntries))
        {
            var pieces = part.Split('=', 2);
            var key = Uri.UnescapeDataString(pieces[0]);
            var value = pieces.Length > 1 ? Uri.UnescapeDataString(pieces[1]) : string.Empty;
            result[key] = value;
        }
        return result;
    }

    private static string? NormalizeAllowedOrigin(string? origin)
    {
        if (string.IsNullOrWhiteSpace(origin)) return null;
        if (string.Equals(origin, "https://sallam101.github.io", StringComparison.OrdinalIgnoreCase)) return origin;
        if (!Uri.TryCreate(origin, UriKind.Absolute, out var uri)) return null;
        if ((uri.Host == "localhost" || uri.Host == "127.0.0.1") && (uri.Scheme == "http" || uri.Scheme == "https")) return origin;
        return null;
    }

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web) { PropertyNameCaseInsensitive = true };

    private static Task WriteJsonAsync(NetworkStream stream, object payload, string origin) =>
        WriteResponseAsync(stream, 200, "application/json; charset=utf-8", JsonSerializer.Serialize(payload, JsonOptions), origin, false);

    private static async Task WriteResponseAsync(NetworkStream stream, int status, string contentType, string body, string? origin, bool preflight)
    {
        var bytes = Encoding.UTF8.GetBytes(body);
        var reason = status switch { 200 => "OK", 204 => "No Content", 400 => "Bad Request", 403 => "Forbidden", 404 => "Not Found", _ => "Internal Server Error" };
        var header = new StringBuilder()
            .Append($"HTTP/1.1 {status} {reason}\r\n")
            .Append($"Content-Type: {contentType}\r\n")
            .Append($"Content-Length: {bytes.Length}\r\n")
            .Append("Cache-Control: no-store\r\n")
            .Append("Connection: close\r\n");
        if (origin is not null)
        {
            header.Append($"Access-Control-Allow-Origin: {origin}\r\n");
            header.Append("Vary: Origin\r\n");
        }
        if (preflight)
        {
            header.Append("Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n");
            header.Append("Access-Control-Allow-Headers: Content-Type\r\n");
            header.Append("Access-Control-Allow-Private-Network: true\r\n");
            header.Append("Access-Control-Max-Age: 600\r\n");
        }
        header.Append("\r\n");
        var headerBytes = Encoding.ASCII.GetBytes(header.ToString());
        await stream.WriteAsync(headerBytes);
        if (bytes.Length > 0) await stream.WriteAsync(bytes);
        await stream.FlushAsync();
    }

    public void Dispose()
    {
        if (Interlocked.Exchange(ref _disposed, 1) != 0) return;
        _cts.Cancel();
        try { _listener.Stop(); } catch { }
        try { _acceptLoop?.Wait(500); } catch { }
        _actionSignal.Dispose();
        _cts.Dispose();
    }
}
