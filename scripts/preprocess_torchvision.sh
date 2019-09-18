#!/bin/bash
source scripts/utils.sh echo -n

# this script is meant to be used with 'datalad run'
set -o errexit -o pipefail

_SNAME=$(basename "$0")

mkdir -p logs/

python3 -m pip install -r scripts/requirements_torchvision.txt

# Move data files to the project's root as it is where torchvision looks for
# the raw files
mkdir -p celeba/
git mv $(list) celeba/
git-annex fsck --fast celeba/

python3 scripts/preprocess_torchvision.py \
	1>>logs/${_SNAME}.out_$$ 2>>logs/${_SNAME}.err_$$

./scripts/stats.sh celeba/*/

# Delete raw files
git rm -f celeba/img_align_celeba.zip md5sums
