using SPTarkov.Common.Models.Logging;
using SPTarkov.DI.Annotations;
using SPTarkov.Server.Core.DI;
using SPTarkov.Server.Core.Models.Spt.Config;
using SPTarkov.Server.Core.Models.Spt.Mod;

namespace ScavTime;

public sealed record ModMetadata : IModMetadata
{
    public string ModGuid { get; init; } = "com.vargor.scavtime";
    public string Name { get; init; } = "ScavTime - Never be late for a Raid!";
    public string Author { get; init; } = "Vargor / OptimisticSociopath";
    public List<string>? Contributors { get; init; }
    public SemanticVersioning.Version Version { get; init; } = new("1.0.0");
    public SemanticVersioning.Range SptVersion { get; init; } = new("~4.1.6");
    public List<string>? Incompatibilities { get; init; }
    public Dictionary<string, SemanticVersioning.Range>? ModDependencies { get; init; }
    public string? Url { get; init; }
    public string License { get; init; } = "MIT";
    public bool HasPrepatcher { get; init; } = false;
}

public static class FullRaidLogic
{
    public static int DisableScavTimeReduction(ScavRaidTimeSettings config)
    {
        ArgumentNullException.ThrowIfNull(config);
        if (config.Maps is null || config.Maps.Count == 0)
            throw new InvalidOperationException("No scav raid map settings found; refusing an unverified no-op.");

        int changed = 0;
        int available = 0;
        foreach (KeyValuePair<string, ScavRaidTimeLocationSettings?> entry in config.Maps)
        {
            ScavRaidTimeLocationSettings? map = entry.Value;
            if (map is null) continue;
            available++;
            if (!double.IsFinite(map.ReducedChancePercent) ||
                map.ReducedChancePercent < 0 || map.ReducedChancePercent > 100)
                throw new InvalidOperationException($"Invalid reduction chance for map '{entry.Key}'.");
        }
        if (available == 0)
            throw new InvalidOperationException("All map settings are null; refusing an unverified no-op.");

        foreach (ScavRaidTimeLocationSettings? map in config.Maps.Values)
        {
            if (map is null || map.ReducedChancePercent == 0d) continue;
            map.ReducedChancePercent = 0d;
            changed++;
        }
        return changed;
    }
}

// Fika uses the same SPT server backend. No Fika APIs are called and no
// client-side patches are installed. This probes only the default Fika server
// mod folder to provide diagnostics; it does NOT prove a co-op raid succeeded.
public static class FikaBackendCompatibility
{
    public static bool ServerFilesPresent(string? runtimeDirectory)
    {
        if (string.IsNullOrWhiteSpace(runtimeDirectory)) return false;
        return Directory.Exists(Path.Combine(runtimeDirectory, "user", "mods", "fika-server"));
    }

    public static string Describe(bool present)
        => present ? "FIKA_SERVER_FOLDER_PRESENT|BACKEND_SHARED|COOP_RUNTIME_UNVERIFIED"
                   : "FIKA_SERVER_FOLDER_NOT_FOUND|STANDALONE_MODE";
}

[Injectable(TypePriority = OnLoadOrder.PostLoad + 999)]
public sealed class ScavTimeStartup(
    LocationConfig locationConfig,
    ISptLogger<ScavTimeStartup> logger) : IOnLoad
{
    public Task OnLoadAsync(CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        int changed = FullRaidLogic.DisableScavTimeReduction(locationConfig.ScavRaidTimeSettings);
        int applicable = locationConfig.ScavRaidTimeSettings.Maps.Values.Count(map => map is not null);
        logger.Success($"[ScavTime] ACTIVE: {applicable} map entries checked; {changed} chances set to 0%. PMC raid settings untouched.");
        bool fikaFiles = FikaBackendCompatibility.ServerFilesPresent(AppContext.BaseDirectory);
        logger.Success($"[ScavTime] {FikaBackendCompatibility.Describe(fikaFiles)}. Server-side setting only; raid host/client tests remain required.");
        return Task.CompletedTask;
    }
}
