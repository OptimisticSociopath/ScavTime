using ScavTime;
using SPTarkov.Server.Core.Models.Spt.Config;

static void Check(bool condition, string message)
{
    if (!condition) throw new Exception("TEST_FAIL|" + message);
    Console.WriteLine("PASS|" + message);
}

static ScavRaidTimeLocationSettings CreateMap(double chance, bool waves, bool loot) => new()
{
    ReducedChancePercent = chance,
    AdjustWaves = waves,
    ReduceLootByPercent = loot,
    MinDynamicLootPercent = 36.5d,
    MinStaticLootPercent = 71.0d,
    ReductionPercentWeights = new Dictionary<string, double> { ["10"] = 42d }
};

var a = CreateMap(100d, true, true);
var b = CreateMap(35d, false, false);
var c = CreateMap(0d, true, false);
var beforeAWeights = a.ReductionPercentWeights;
var beforeBWeights = b.ReductionPercentWeights;
var maps = new Dictionary<string, ScavRaidTimeLocationSettings?>
{
    ["bigmap"] = a,
    ["factory4_day"] = b,
    ["tarkovstreets"] = c,
    ["null-location"] = null
};
var settings = new ScavRaidTimeSettings { Maps = maps, Settings = new ScavRaidTimeConfigSettings { TrainArrivalDelayObservedSeconds = 123 } };
int changed = FullRaidLogic.DisableScavTimeReduction(settings);
Check(changed == 2, "ONLY_NONZERO_CHANCES_CHANGED");
Check(a.ReducedChancePercent == 0 && b.ReducedChancePercent == 0 && c.ReducedChancePercent == 0, "ALL_SCAV_CHANCES_ZERO");
Check(ReferenceEquals(a.ReductionPercentWeights, beforeAWeights) && ReferenceEquals(b.ReductionPercentWeights, beforeBWeights), "REDUCTION_WEIGHTS_UNCHANGED");
Check(a.AdjustWaves && !b.AdjustWaves && c.AdjustWaves, "BOT_WAVE_FLAGS_UNCHANGED");
Check(a.ReduceLootByPercent && !b.ReduceLootByPercent, "LOOT_FLAGS_UNCHANGED");
Check(a.MinDynamicLootPercent == 36.5 && a.MinStaticLootPercent == 71.0, "LOOT_PERCENTS_UNCHANGED");
Check(settings.Settings.TrainArrivalDelayObservedSeconds == 123, "TRAIN_SETTINGS_UNCHANGED");
Check(maps["null-location"] is null, "NULL_MAP_UNCHANGED");
Check(FullRaidLogic.DisableScavTimeReduction(settings) == 0, "IDEMPOTENT_SECOND_RUN");

var invalid = new ScavRaidTimeSettings { Settings = new ScavRaidTimeConfigSettings(), Maps = new() { ["ok"] = CreateMap(95d, true, true), ["bad"] = CreateMap(101d, true, true) } };
try { FullRaidLogic.DisableScavTimeReduction(invalid); throw new Exception("INVALID_CHANCE_NOT_REJECTED"); }
catch (InvalidOperationException) { Check(invalid.Maps["ok"]!.ReducedChancePercent == 95d, "INVALID_INPUT_ATOMIC_NO_MUTATION"); }
try { FullRaidLogic.DisableScavTimeReduction(new ScavRaidTimeSettings { Settings = new ScavRaidTimeConfigSettings(), Maps = new() }); throw new Exception("EMPTY_NOT_REJECTED"); }
catch (InvalidOperationException) { Check(true, "EMPTY_CONFIG_REJECTED"); }
var fikaScratch = Path.Combine(Path.GetTempPath(), "ScavTimeFikaProbe_" + Guid.NewGuid().ToString("N"));
try
{
    Directory.CreateDirectory(fikaScratch);
    Check(!FikaBackendCompatibility.ServerFilesPresent(fikaScratch), "FIKA_OPTIONAL_ABSENT_STANDALONE");
    Directory.CreateDirectory(Path.Combine(fikaScratch, "user", "mods", "fika-server"));
    Check(FikaBackendCompatibility.ServerFilesPresent(fikaScratch), "FIKA_FOLDER_DETECTED_READ_ONLY");
    Check(FikaBackendCompatibility.Describe(true).Contains("COOP_RUNTIME_UNVERIFIED"), "FIKA_DETECTION_DOES_NOT_CLAIM_RUNTIME_PASS");
    Check(!FikaBackendCompatibility.ServerFilesPresent(null), "FIKA_NULL_RUNTIME_SAFE");
}
finally { if (Directory.Exists(fikaScratch)) Directory.Delete(fikaScratch, true); }
var metadata = new ModMetadata();
Check(metadata.Version.ToString() == "1.0.0", "VERSION_100");
Check(metadata.Name == "ScavTime - Never be late for a Raid!", "PRODUCT_NAME_PRESERVED");
Check(metadata.Author == "Vargor / OptimisticSociopath", "AUTHOR_PRESERVED");
Check(metadata.ModDependencies is null || metadata.ModDependencies.Count == 0, "NO_REQUIRED_FIKA_DEPENDENCY");
Console.WriteLine("STATUS=PASS_SCAVTIME_FIKA_BACKEND_TESTS");
