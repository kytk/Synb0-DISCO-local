#!/bin/bash

# A script to prepare images for Synb0-DISCO

# Usage: prep_synb0.sh <subjectID> <T1> <DWI>

# 1. make directory of the name of subjectID
# 2. copy T1 as T1.nii.gz
# 3. generate b0.nii.gz
# 4. generate acqparams.txt

if [ $# -lt 3 ]; then
  echo "Please specify subjectID, T1 image, and Diffusion image"
  echo "Usage: $0 <subjectID> T1.nii(.gz) DWI.nii(.gz)"
  exit 1
fi

sid=$1
t1w=$2
dwi=$3

# generate sid
if [ ! -d $sid ]; then
  mkdir -p $sid/{INPUTS,OUTPUTS}
fi

# copy T1
ext=$(file $t1w | awk '{ print $2 }')
if [ ${ext} = "gzip" ]; then
  cp $t1w $sid/INPUTS/T1.nii.gz
else
  cp $t1w $sid/INPUTS/T1.nii
  gzip $sid/INPUTS/T1.nii
fi

# copy b0 (assume the first image is b0)
fslroi $dwi $sid/INPUTS/b0.nii.gz 0 1

# generate acqparams.txt
imgjson=$(imglob $dwi).json

pe=$(grep \"PhaseEncodingDirection\" ${imgjson} | awk '{ print $2 }' | sed 's/,//')
readout=$(grep \"TotalReadoutTime\" ${imgjson} | awk '{ print $2 }' | sed 's/,//')
if [ ${pe} = "j" ]; then
  echo "0 -1 0 0" > $sid/INPUTS/acqparams.txt
  echo "0 1 0 $readout" >> $sid/INPUTS/acqparams.txt
else
  echo "0 -1 0 $readout" > $sid/INPUTS/acqparams.txt
  echo "0 1 0 0" >> $sid/INPUTS/acqparams.txt
fi
 
exit

