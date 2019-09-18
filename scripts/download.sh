#!/bin/bash
source scripts/utils.sh echo -n

# Saner programming env: these switches turn some bugs into errors
set -o errexit -o pipefail

# This script is meant to be used with the command 'datalad run'

function delete_remote {
	init_conda_env --name rclone --prefix .tmp/
	echo "Deleting ${REMOTE} access token"
	rclone config delete ${REMOTE}
}

test_enhanced_getopt

PARSED=$(enhanced_getopt --options "d,h" --longoptions "directory:,client-id:,secret:,help" --name "$0" -- "$@")
eval set -- "${PARSED}"

GDRIVE_DIR_ID=$(git config --file scripts/celeba_config --get google.directory || echo "")
CLIENT_ID=$(git config --file scripts/celeba_config --get google.client-id || echo "")
CLIENT_SECRET=$(git config --file scripts/celeba_config --get google.client-secret || echo "")
REMOTE=__gdrive

while [[ $# -gt 0 ]]
do
	arg="$1"; shift
	case "${arg}" in
                -d | --directory) GDRIVE_DIR_ID="$1"; shift
                echo "directory = [${GDRIVE_DIR_ID}]"
                ;;
		--client-id) CLIENT_ID="$1"; shift
		echo "client-id = [${CLIENT_ID}]"
		;;
		--secret) CLIENT_SECRET="$1"; shift
		echo "secret = [${CLIENT_SECRET}]"
		;;
		-h | --help)
		>&2 echo "Options for $(basename "$0") are:"
		>&2 echo "[-d | --directory GDRIVE_DIR_ID] Google Drive root directory id (optional)"
		>&2 echo "[--client-id CLIENT_ID] Google application client id (optional)"
		>&2 echo "[--secret CLIENT_SECRET] OAuth Client Secret (optional)"
		exit 1
		;;
		--) break ;;
		*) >&2 echo "Unknown argument [${arg}]"; exit 3 ;;
	esac
done

init_conda_env --name rclone --prefix .tmp/
conda install --yes --strict-channel-priority --use-local -c defaults -c conda-forge rclone=1.57.0

trap delete_remote EXIT

if [[ -z "$(rclone listremotes | grep -o "^${REMOTE}:")" ]]
then
	echo "Configuring the rclone remote. Use default values when asked."
	rclone config create ${REMOTE} drive client_id ${CLIENT_ID} \
		client_secret ${CLIENT_SECRET} \
		scope "drive.readonly" \
		root_folder_id "" \
		config_is_local false \
		config_refresh_token false \
		service_account_file "" \
		--all
fi

files_url=(
	"Img/ Img/"
	"Eval/ Eval/"
	"Anno/ Anno/"
	"README.txt .")

rclone_copy --remote ${REMOTE} --root ${GDRIVE_DIR_ID} -- "${files_url[@]}"

conda deactivate

git-annex add --fast -c annex.largefiles=anything Img/ Eval/ Anno/

[[ -f md5sums ]] && md5sum -c md5sums
[[ -f md5sums ]] || md5sum $(list -- --fast) > md5sums
