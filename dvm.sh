# Dart Version Manager
# Implemented as a bash function
# To use source this file from your bash profile
# Inspired by nvm

DVM_ROOT=$HOME/.dvm
DART_ARCHIVE_URI=http://storage.googleapis.com/dart-archive

# bootstrap a new dart environment. 
dvm_bootstrap() {
	dvm_check 'gcutil' 

	mkdir -p ${DVM_ROOT}/channels/stable/release/latest/sdk ${DVM_ROOT}/channels/dev/release/latest/sdk
	gsutil cp gs://dart-archive/channels/stable/release/latest/VERSION ${DVM_ROOT}/channels/stable/release/latest/

	set -f # turn off globbing
	IFS=$'\n' # split at newlines only
	output=($(gsutil cat gs://dart-archive/channels/stable/release/latest/VERSION | python -c 'import json,sys;o=json.load(sys.stdin);print o["version"];print o["revision"];'))
	unset IFS
	set +f

	echo "Bootstrapping with Version (${output[0]}) Revision (${output[1]})"

	local dart_sdk_zip_file_name="dartsdk-${SYSTEM}-release.zip"
	local dartsdk_zip_file_path="gs://dart-archive/channels/stable/release/latest/sdk/${dart_sdk_zip_file_name}"
	
	# TODO: check md5sum file
	pushd ${DVM_ROOT}/channels/stable/release/latest/sdk
	if (
	        gsutil cp $dartsdk_zip_file_path $dart_sdk_zip_file_name && \
	        unzip $dart_sdk_zip_file_name
	    )
	then
	    echo "dvm: install ${output[0]} successfully!"
	    export DART_SDK=${DVM_ROOT}/channels/stable/release/latest/sdk/dart-sdk
		export DART_SDK_BIN=$DART_SDK/bin
		export PATH=$DART_SDK_BIN:$PATH
	else
	    echo "dvm: install ${output[0]} failed!"
	fi
	popd
}

# check dependencies
dvm_check() {
    case "$1" in
        "curl")
            if [ ! `which curl` ]; then
                echo 'DVM Needs curl to proceed.' >&2;
                exit
            fi
            ;;
        "system")
            local uname="$(uname -a)"
            local os=''
            local arch="$(uname -m)"

            case "$uname" in
                Linux\ *)
                    os=linux ;;
                Darwin\ *)
                    os=macos ;;
                SunOS\ *)
                    os=sunos ;;
            esac

            case "$uname" in
                *x86_64*)
                    arch=x64 ;;
                *i*86*)
                    arch=ia32 ;;
            esac

            echo "${os}-${arch}"
            ;;
        "gcutil")
			if [ ! `which curl` ]; then
				echo "DVM Needs gcutil to proceed." >&2;
				exit
			fi
			;;
    esac
}

# general function
dvm() {
	local ACTION="$1"
    local SYSTEM=$(dvm_check system)
    local DVM_VERSION="0.0.1"

    #process arguments
    case "$ACTION" in
        "help" )
            echo
            echo "Dart Version Manager"
            echo 
		    cat dart-logo
		    echo
            echo
            echo "Usage:"
            echo "    dvm help                    Show this message"
            echo "    dvm version                 Show the dvm version"
            echo "    dvm bootstrap               Bootstrap dvm"
            echo
            ;;
        "version" | "--version" | "-v" )
            echo "v${DVM_VERSION}"
            echo "SYSTEM = ${SYSTEM}"
            ;;
        "bootstrap" | "--bootstrap" | "-b")
			echo "Bootstrapping dvm"
			dvm_bootstrap
			;;
    	* )
        dvm help
        ;;
esac
}
