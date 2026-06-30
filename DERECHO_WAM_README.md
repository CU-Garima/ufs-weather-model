# FV3-WAM (ATM-only) on Derecho

This branch (`wam-derecho-port`) adds support for building and running the
Whole Atmosphere Model (FV3-WAM, ATM-only) on NCAR's **Derecho**. It is based
on the `ufs-wamv1` WAM branch with three changes:

- `modulefiles/ufs_derecho.intel.lua` — rebuilt against spack-stack 1.9.2
  (`ue-oneapi-2024.2.1`) + `ufs_common` (esmf 8.8.0, fms 2024.02). The previous
  modulefile is kept as `ufs_derecho.intelold.lua`.
- `FV3/ccpp/physics` — fixes a build break where `unified_ugwp.F90` referenced
  `drag_suite_psl`, which no longer exists in `drag_suite.F90`.
- `tests/fv3_conf/control_wam_run.IN` — points at Derecho input data.

The submodules (`fv3atm`, `ccpp-physics`) are pinned to matching forks, so a
recursive clone is self-contained.

---

## 1. Clone

```bash
git clone --recursive -b wam-derecho-port \
  https://github.com/CU-Garima/ufs-weather-model.git
cd ufs-weather-model
```

If you already cloned without `--recursive`:

```bash
git submodule update --init --recursive
```

## 2. Build

From a Derecho login node:

```bash
module purge
module use $PWD/modulefiles
module load ufs_derecho.intel        # sets CMAKE_Platform=derecho.intel

export CMAKE_FLAGS="-DAPP=ATM \
  -DCCPP_SUITES=FV3_GFS_v16_fv3wamphys,FV3_GFS_v17_fv3wamphys,FV3_GFS_v17_wam_ugwpv1 \
  -D32BIT=ON -DMULTI_GASES=ON"
export BUILD_DIR=/glade/derecho/scratch/$USER/fv3wam_build
export BUILD_JOBS=64
./build.sh
```

The executable is produced at `$BUILD_DIR/ufs_model`.

A full build takes ~30–50 min; submit it as a batch job rather than building on
the login node. Example PBS job (queue `main`, account = your project):

```bash
#PBS -N wam_build
#PBS -A <ACCOUNT>
#PBS -q main
#PBS -l select=1:ncpus=128:mpiprocs=1
#PBS -l walltime=01:30:00
#PBS -j oe
```

## 3. Input data

The `control_fv3wamphys_ugwpv1_p8` case (2018-02-01 00Z, C96/L196) needs two
input sets, staged into the run directory by
`tests/fv3_conf/control_wam_run.IN`:

| Source | Goes to | Contents |
|---|---|---|
| `<INPUT>/`          | `./INPUT/` | C96 cold-start ICs (`gfs_data`, `sfc_data`, grid, oro) |
| `<FV3WAM_V2_INPUT>/`| `./`       | WAM fix/forcing (IDEA tables, climatology, CO2, etc.) |

On Derecho these live under `/glade/campaign/univ/ucub0172/{INPUT,FV3WAM_V2_INPUT}`.
Edit `control_wam_run.IN` to point at your own copies if needed.

Solar/geomagnetic forcing for this case is **fixed in the namelist**
(`parm/fv3wamphys.nml.IN`, `&wamphys_nml`: `f107_fix=80, kp_fix=3.0`), not read
from a file. Edit those for different conditions.

## 4. Run

Build a run directory with the regression-test framework's templates, or
reuse the rt harness. Key Derecho-specific settings that must be right (these
were required to get a clean run):

- **`domains_stack_size`** (`input.nml`, `&fms_nml`): raise from the default
  `3000000` to `16000000`. Lower rank counts (large subdomains) overflow the
  default and abort with `mpp_domains_stack overflow`.
- **Memory**: request full-node memory in the PBS select, e.g.
  `select=N:ncpus=128:mpiprocs=PPN:mem=230gb`. The `develop` queue's shared
  nodes default to ~10 GB, which OOM-kills ranks (signal 9) during adiabatic
  init. For an **interactive** develop session, request `mem` on the
  `qsub -I` line itself.
- **Ranks per node**: place ~40 ranks/node (not the full 128). Each rank loads
  large fix files (MERRA2 aerosols, T1534 climatology, IDEA tables); packing
  the node full exhausts memory.

Launch (inside the run directory):

```bash
mpiexec -n <TASKS> -ppn <PPN> ./ufs_model
```

The default test uses 600 tasks (576 compute + 24 write) → 15 nodes at
40 ranks/node.

A quick 1-node smoke test: shrink the decomposition (e.g. `INPES=2, JNPES=3`,
4 write tasks → 40 tasks) and set `FHMAX=1`.

## 5. Output

Hourly history files in the run directory:

- `atmfNNN.nc` — 3D atmosphere on a Gaussian grid (384×190×196), surface to
  ~430 km: `tmp`, `ugrd`, `vgrd`, `dzdt`, `spfo` (O), `spfo2` (O2), `o3mr`, etc.
- `sfcfNNN.nc` — 2D surface/diagnostic fields.
- `RESTART/` — restart files at the end of the forecast.

For a 24-hour forecast with hourly output that is `atmf001.nc … atmf024.nc`
(each ~860 MB).
