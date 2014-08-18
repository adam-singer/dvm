# Dart Version Manager
# Implemented as a bash function
# To use source this file from your bash profile
# Inspired by nvm

DVM_ROOT=$HOME/.dvm
DART_ARCHIVE_URI=http://storage.googleapis.com/dart-archive

DVM_GS_CHANNELS_URI=gs://dart-archive/channels
DVM_VERSION_CACHE=${DVM_ROOT}/version_cache
DVM_LOCAL_CHANNELS_PATH=${DVM_ROOT}/channels
DVM_CHANNELS="stable dev"

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

dvm_sync() {
    mkdir -p ${DVM_ROOT}/version_cache
    dvm_build_version_cache
}

dvm_build_version_cache() {
    for CHANNEL in $DVM_CHANNELS; do
        local VERSION_URLS=$(gsutil ls ${DVM_GS_CHANNELS_URI}/${CHANNEL}/release/*/VERSION)
        for VERSION in $VERSION_URLS; do 
            echo "Processing Url ${VERSION}"
            local VERSION_JSON=$(gsutil cat $VERSION)
            set -f # turn off globbing
            IFS=$'\n' # split at newlines only
            local output=($(echo $VERSION_JSON | python -c 'import json,sys;o=json.load(sys.stdin);print o["version"];print o["revision"];'))
            unset IFS
            set +f
            mkdir -p ${DVM_VERSION_CACHE}/${CHANNEL}/${output[1]}
            echo $VERSION_JSON > ${DVM_VERSION_CACHE}/${CHANNEL}/${output[1]}/VERSION
        done
    done
}

dvm_clean_version_cache() {
    rm -r -i ${DVM_VERSION_CACHE}
}

dvm_clean_downloaded_channels() {
    rm -r -i ${DVM_LOCAL_CHANNELS_PATH}
}

dvm_list_version_cache() {
    for CHANNEL in $DVM_CHANNELS; do 
        local CHANNEL_PATH=${DVM_VERSION_CACHE}/${CHANNEL}
        echo
        echo $CHANNEL
        echo
        for REVISION in `ls ${CHANNEL_PATH}`; do
            local VERION_FILE_PATH=${CHANNEL_PATH}/${REVISION}/VERSION
            set -f # turn off globbing
            IFS=$'\n' # split at newlines only
            output=($(cat ${VERION_FILE_PATH} | python -c 'import json,sys;o=json.load(sys.stdin);print o["version"];print o["revision"];'))
            unset IFS
            set +f
            echo ${output[0]}
        done
    done
}

# usage:
# dvm_version_to_revision dev 1.6.0-dev.0.0
dvm_version_to_revision() {
    local CHANNEL=$1
    local VERSION=$2
    local CHANNEL_PATH=${DVM_VERSION_CACHE}/${CHANNEL}
    for REVISION in `ls ${CHANNEL_PATH}`; do
        local VERION_FILE_PATH=${CHANNEL_PATH}/${REVISION}/VERSION
        set -f # turn off globbing
        IFS=$'\n' # split at newlines only
        output=($(cat ${VERION_FILE_PATH} | python -c 'import json,sys;o=json.load(sys.stdin);print o["version"];print o["revision"];'))
        unset IFS
        set +f
        if [ ${output[0]} == ${VERSION} ]; then
            echo ${output[1]}
            return
        fi
    done
    echo ""
}

dvm_build_os_arch() {
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
}

dvm_build_sdk_filename() {
    local filename="dartsdk-$(dvm_build_os_arch)-release.zip"
    echo $filename
}

dvm_build_sdk_path() {
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_GS_CHANNELS_URI}/${CHANNEL}/release/${REVISION}/sdk/$(dvm_build_sdk_filename)"
    echo $path
}

dvm_build_local_sdk_path() {
    # use mkdir -p $(dvm_build_local_sdk_path)
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_LOCAL_CHANNELS_PATH}/${CHANNEL}/release/${REVISION}/sdk"
    echo $path
}

dvm_build_editor_filename() {
    local filename="darteditor-$(dvm_build_os_arch).zip"
    echo $filename
}

dvm_build_editor_path() {
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_GS_CHANNELS_URI}/${CHANNEL}/release/${REVISION}/editor/$(dvm_build_editor_filename)"
    echo $path
}

dvm_build_local_editor_path() {
    # use mkdir -p $(dvm_build_local_editor_path)
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_LOCAL_CHANNELS_PATH}/${CHANNEL}/release/${REVISION}/editor"
    echo $path
}

dvm_build_api_docs_filename() {
    local filename="dart-api-docs.zip"
    echo $filename
}

dvm_build_api_docs_path() {
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_GS_CHANNELS_URI}/${CHANNEL}/release/${REVISION}/api-docs/$(dvm_build_api_docs_filename)"
    echo $path  
}

dvm_build_local_api_docs_path() {
    # use mkdir -p $(dvm_build_local_api_docs_path)
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_LOCAL_CHANNELS_PATH}/${CHANNEL}/release/${REVISION}/api-docs"
    echo $path  
}

dvm_build_dartium_filename() {
    local filename="dartium-$(dvm_build_os_arch)-release.zip"
    echo $filename
}

dvm_build_dartium_path() {
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_GS_CHANNELS_URI}/${CHANNEL}/release/${REVISION}/dartium/$(dvm_build_dartium_filename)"
    echo $path      
}

dvm_build_chromedriver_filename() {
    local filename="chromedriver-$(dvm_build_os_arch)-release.zip"
    echo $filename
}

dvm_build_chromedriver_path() {
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_GS_CHANNELS_URI}/${CHANNEL}/release/${REVISION}/dartium/$(dvm_build_chromedriver_filename)"
    echo $path  
}

dvm_build_content_shell_filename() {
    local filename="content_shell-$(dvm_build_os_arch)-release.zip"
    echo $filename
}

dvm_build_content_shell_path() {
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_GS_CHANNELS_URI}/${CHANNEL}/release/${REVISION}/dartium/$(dvm_build_content_shell_filename)"
    echo $path  
}

# this is for the paths of dartium, content_shell, chromedriver
dvm_build_local_dartium_path() {
    # use mkdir -p $(dvm_build_local_dartium_path)
    local CHANNEL=$1
    local REVISION=$2
    local path="${DVM_LOCAL_CHANNELS_PATH}/${CHANNEL}/release/${REVISION}/dartium"
    echo $path      
}

dvm_sdk_dev_install() {
    # TODO: check the version exists in the cache
    local VERSION=$1
    local REVISION=$(dvm_version_to_revision dev ${VERSION})
    local CHANNEL_PATH=$(dvm_build_local_sdk_path dev ${REVISION})
    mkdir -p ${CHANNEL_PATH}
    gsutil cp $(dvm_build_sdk_path dev ${REVISION}) $(dvm_build_local_sdk_path dev ${REVISION})
    pushd ${CHANNEL_PATH}
    unzip $(dvm_build_sdk_filename)
    popd

    # TODO: remove old dart path
    export PATH=${CHANNEL_PATH}/dart-sdk/bin:$PATH
    export DART_SDK=${CHANNEL_PATH}/dart-sdk
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
            echo "    svm sync                    Update the local cache of available versions"
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
        "sync")
            echo "Sync available versions"
            dvm_sync
            ;;
    	* )
        dvm help
        ;;
esac
}


