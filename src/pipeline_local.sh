#!/bin/bash

# This script is based on pipeline.sh
# This is to run Synb0-DISCO on local computer.
# Prerequisites: You need to set up the following;
# - FreeSurfer
# - FSL
# - ANTs
# - c3d
# - PyTorch
# - nibabel

# Usage

# Prepare subject directory and put INPUTS and OUTPUTS directories under the subject directory
# run pipeline_local.sh
# /path_to_Synb0-DISCO/src/pipeline_local.sh

# K. Nemoto 23 Aug 2022
# Modified by Kiku 15 Apr 2024
 
# For debug
# set -x

## Set path for executable
pipelinepath=$(cd $(dirname $0) && pwd)
synb0path=${pipelinepath%/src}
export Synb0_SRC=${synb0path}/src
export Synb0_PROC=${synb0path}/data_processing
export Synb0_ATLAS=${synb0path}/atlases
export PATH=$PATH:$Synb0_SRC:$Synb0_PROC:$Synb0_ATLAS

# Set default values
TOPUP=1
TOPUP_THREADS=""
SYNTH_FLAG=0
MNI_T1_1_MM_FILE=$Synb0_ATLAS/mni_icbm152_t1_tal_nlin_asym_09c.nii.gz


for arg in "$@"
do
    case $arg in
        -i|--notopup)
        TOPUP=0
        ;;
    	-s|--stripped)
	    MNI_T1_1_MM_FILE=$Synb0_ATLAS/mni_icbm152_t1_tal_nlin_asym_09c_mask.nii.gz
        ;;
        --synthstrip)
          export SYNTH_FLAG=1
        ;;
        --threads=*)
          TOPUP_THREADS="--nthr=${arg#*=}"
        ;;
    esac
done


# Prepare input
prepare_input_local.sh ./INPUTS/b0.nii.gz ./INPUTS/T1.nii.gz $MNI_T1_1_MM_FILE $Synb0_ATLAS/mni_icbm152_t1_tal_nlin_asym_09c_2_5.nii.gz ./OUTPUTS


# Run inference
NUM_FOLDS=5
for i in $(seq 1 $NUM_FOLDS);
  do echo Performing inference on FOLD: "$i"
  python3 $Synb0_SRC/inference_local.py ./OUTPUTS/T1_norm_lin_atlas_2_5.nii.gz ./OUTPUTS/b0_d_lin_atlas_2_5.nii.gz ./OUTPUTS/b0_u_lin_atlas_2_5_FOLD_"$i".nii.gz $Synb0_SRC/train_lin/num_fold_"$i"_total_folds_"$NUM_FOLDS"_seed_1_num_epochs_100_lr_0.0001_betas_\(0.9\,\ 0.999\)_weight_decay_1e-05_num_epoch_*.pth
done


# Take mean
echo Taking ensemble average
fslmerge -t ./OUTPUTS/b0_u_lin_atlas_2_5_merged.nii.gz ./OUTPUTS/b0_u_lin_atlas_2_5_FOLD_*.nii.gz
fslmaths ./OUTPUTS/b0_u_lin_atlas_2_5_merged.nii.gz -Tmean ./OUTPUTS/b0_u_lin_atlas_2_5.nii.gz


# Apply inverse xform to undistorted b0
echo Applying inverse xform to undistorted b0
antsApplyTransforms -d 3 -i ./OUTPUTS/b0_u_lin_atlas_2_5.nii.gz -r ./INPUTS/b0.nii.gz -n BSpline -t [./OUTPUTS/epi_reg_d_ANTS.txt,1] -t [./OUTPUTS/ANTS0GenericAffine.mat,1] -o ./OUTPUTS/b0_u.nii.gz


# Smooth image
echo Applying slight smoothing to distorted b0
fslmaths ./INPUTS/b0.nii.gz -s 1.15 ./OUTPUTS/b0_d_smooth.nii.gz

if [[ $TOPUP -eq 1 ]]; then
    # Merge results and run through topup
    echo Running topup
    fslmerge -t ./OUTPUTS/b0_all.nii.gz ./OUTPUTS/b0_d_smooth.nii.gz ./OUTPUTS/b0_u.nii.gz
    topup -v --imain=./OUTPUTS/b0_all.nii.gz --datain=./INPUTS/acqparams.txt \
    --config=$Synb0_SRC/synb0.cnf --iout=./OUTPUTS/b0_all_topup.nii.gz --out=./OUTPUTS/topup $TOPUP_THREADS
fi


# Done
echo FINISHED!!!
