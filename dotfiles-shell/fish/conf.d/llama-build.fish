# Optimizaciones para compilación de llama.cpp con ROCm / HIP (paru / AUR)
# - Objetivo GPU exclusivo: Radeon RX 9070 XT (gfx1201 / RDNA 4)
# - Desactiva LTO en el proyecto y en C/C++ (evita cuello de botella y soluciona incompatibilidad con lld)
# - Desactiva la instanciación de FlashAttention para todos los tipos de quants (ahorra decenas de minutos)
# - Usa el linker lld en lugar de ld de GNU
# - Usa ccache para compilador C, C++ y kernels HIP (recompilaciones en segundos)
set -gx LLAMA_BUILD_EXTRA_ARGS "-DAMDGPU_TARGETS=gfx1201 -DGGML_CUDA_FA_ALL_QUANTS=OFF -DGGML_LTO=OFF -DCMAKE_C_FLAGS=-fno-lto -DCMAKE_CXX_FLAGS=-fno-lto -DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld -DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_HIP_COMPILER_LAUNCHER=ccache"
