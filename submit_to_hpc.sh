#!/bin/bash
#BSUB -J ParallelJulia 
#BSUB -q hpc

# Requesting 4GB per core. Total = 4 cores * 4GB = 16GB
#BSUB -R "rusage[mem=4GB]"
#BSUB -R "span[hosts=1]"

# Email notifications
#BSUB -B
#BSUB -N
#BSUB -u albert.hogsted0@gmail.com

# Output and Error files
#BSUB -o Output_%J.out
#BSUB -e Output_%J.err

# Wallclock and Cores
#BSUB -W 24:00 
#BSUB -n 4 

# Load Julia
module load julia/1.12.0

# Set threads to match the requested cores (
module load julia/1.12.0
cd /zhome/1c/c/206397/RoRo_Bachelor
export JULIA_NUM_THREADS=$LSB_DJOB_NUMPROC

# Force the compute node to recognize and install the environment locally
julia --project=. -e 'using Pkg; Pkg.instantiate()'

# Now run your script
julia --project=. src/Model/Untitled-3.jl