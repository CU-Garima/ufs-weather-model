help([[
loads UFS Model prerequisites for Derecho/Intel
]])

local ss_root = "/glade/work/epicufsrt/contrib/spack-stack/derecho/spack-stack-1.9.2/envs/ue-oneapi-2024.2.1/install/modulefiles"

prepend_path("MODULEPATH", pathJoin(ss_root, "Core"))

stack_oneapi_ver=os.getenv("stack_oneapi_ver") or "2024.2.1"
load(pathJoin("stack-oneapi", stack_oneapi_ver))

stack_cray_mpich_ver=os.getenv("stack_cray_mpich_ver") or "8.1.29"
load(pathJoin("stack-cray-mpich", stack_cray_mpich_ver))

cmake_ver=os.getenv("cmake_ver") or "3.27.9"
load(pathJoin("cmake", cmake_ver))

-- scotch is under the gcc toolchain in this env
prepend_path("MODULEPATH", pathJoin(ss_root, "cray-mpich/8.1.29-3sepg3g/gcc/12.4.0"))

load("ufs_common")

setenv("CMAKE_Platform", "derecho.intel")

whatis("Description: UFS build environment")
