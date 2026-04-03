# msc-thesis
 
Orchestrator workspace for Hashim Karim's MSc thesis.
 
**MSc Computer and Embedded Systems Engineering — TU Delft**
 
## Clone (fresh machine)
 
```bash
git clone --recurse-submodules git@github.com:Hashim-K/msc-thesis.git
cd msc-thesis
./scripts/bootstrap.sh
```
 
## Submodules
 
| Path | Repo | Description |
|------|------|-------------|
| `repos/mir-core` | [mir-core](https://github.com/Hashim-K/mir-core) | Shared Python package |
| `repos/mir-train-hpc` | [mir-train-hpc](https://github.com/Hashim-K/mir-train-hpc) | DAIC training workflows |
| `repos/mir-desktop-app` | [mir-desktop-app](https://github.com/Hashim-K/mir-desktop-app) | Desktop inference UI |
| `repos/mir-webapp` | [mir-webapp](https://github.com/Hashim-K/mir-webapp) | DAIC job scheduler webapp |
| `repos/mir-embedded-ai` | [mir-embedded-ai](https://github.com/Hashim-K/mir-embedded-ai) | Embedded inference + actuation |
| `repos/mir-embedded-hmi` | [mir-embedded-hmi](https://github.com/Hashim-K/mir-embedded-hmi) | Wireless node firmware + HMI |
| `repos/mir-environment` | [mir-environment](https://github.com/Hashim-K/mir-environment) | Conda environment definitions |
| `repos/mir-data` | [mir-data](https://github.com/Hashim-K/mir-data) | Datasets + promoted weights (DVC) |
| `repos/mir-outputs` | [mir-outputs](https://github.com/Hashim-K/mir-outputs) | Run artifacts + checkpoints (DVC) |
| `repos/thesis-docs` | [thesis-docs](https://github.com/Hashim-K/thesis-docs) | Notes, ADRs, architecture |
| `repos/thesis-latex` | [thesis-latex](https://github.com/Hashim-K/thesis-latex) | Thesis manuscript (LaTeX) |
 
## Scripts
 
| Script | Purpose |
|--------|---------|
| `scripts/bootstrap.sh` | First-time setup — submodules, conda env, DVC, .env |
| `scripts/sync.sh` | Pull latest on all submodules + update SHA pins |
| `scripts/run-desktop.sh` | Launch desktop app |
| `scripts/run-web.sh` | Launch webapp |
| `scripts/promote-model.sh` | Promote checkpoint from outputs to data |
 
## Rules
 
- No domain logic in this repo — thin launchers and config only
- Cross-repo references go through installed packages, env vars, or manifests
- No hard-coded absolute paths — use `MIR_DATA_ROOT`, `MIR_OUTPUTS_ROOT`, `MIR_CORE_PATH`
