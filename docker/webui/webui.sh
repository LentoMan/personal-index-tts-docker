#!/usr/bin/env bash
#################################################
# Please do not make any changes to this file,  #
# change the variables in webui-user.sh instead #
#################################################

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )


# Read variables from webui-user.sh
# shellcheck source=/dev/null
if [[ -f "$SCRIPT_DIR"/webui-user.sh ]]
then
    source "$SCRIPT_DIR"/webui-user.sh
fi

# Index-TTS Checkpoint to use
if [[ -z "${checkpoint}" ]]
then
    checkpoint="IndexTeam/IndexTTS-2"
fi

# Checkpoint installation command
if [[ -z "${ckpt_install_cmd}" ]]
then
    ckpt_install_cmd="hf download ${checkpoint} --local-dir=checkpoints"
fi

# Set defaults
# Install directory without trailing slash
if [[ -z "${install_dir}" ]]
then
    install_dir="$SCRIPT_DIR"
fi

# Name of the subdirectory (defaults to index-tts)
if [[ -z "${clone_dir}" ]]
then
    clone_dir="index-tts"
fi

# python3 executable
if [[ -z "${python_cmd}" ]]
then
    python_cmd="python3.11"
fi
if [[ ! -x "$(command -v "${python_cmd}")" ]]
then
    python_cmd="python3"
fi

if [[ -z "${pip_cmd}" ]]
then
    pip_cmd="pip3.11"
fi

if [[ -z "${uv_cmd}" ]]
then
    uv_cmd="uv"
fi

# git executable
if [[ -z "${GIT}" ]]
then
    export GIT="git"
else
    export GIT_PYTHON_GIT_EXECUTABLE="${GIT}"
fi

# python3 uv .venv without trailing slash (defaults to ${install_dir}/${clone_dir}/.venv)
if [[ -z "${venv_dir}" ]] && [[ $use_venv -eq 1 ]]
then
    venv_dir=".venv"
fi

if [[ -z "${LAUNCH_SCRIPT}" ]]
then
    LAUNCH_SCRIPT="webui.py"
fi

# this script cannot be run as root by default
can_run_as_root=0

# read any command line flags to the webui.sh script
while getopts "f" flag > /dev/null 2>&1
do
    case ${flag} in
        f) can_run_as_root=1;;
        *) break;;
    esac
done

# disable gradio analytics
export GRADIO_ANALYTICS_ENABLED="False"

# disable huggingface hub telemetry
export HF_HUB_DISABLE_TELEMETRY=1

# Disable sentry logging
export ERROR_REPORTING=FALSE

# Do not reinstall existing pip packages on Debian/Ubuntu
export PIP_IGNORE_INSTALLED=0

# Pretty print
delimiter="################################################################"

printf "\n%s\n" "${delimiter}"
printf "\e[1m\e[32mInstall script for index-tts + Web UI\n"
printf "\n%s\n" "${delimiter}"

# Do not run as root
if [[ $(id -u) -eq 0 && can_run_as_root -eq 0 ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERROR: This script must not be launched as root, aborting...\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
else
    printf "\n%s\n" "${delimiter}"
    printf "Running on \e[1m\e[32m%s\e[0m user" "$(whoami)"
    printf "\n%s\n" "${delimiter}"
fi

if [[ $(getconf LONG_BIT) = 32 ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERROR: Unsupported Running on a 32bit OS\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
fi

if [[ -d "$SCRIPT_DIR/.git" ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "Repo already cloned, using it as install directory"
    printf "\n%s\n" "${delimiter}"
    install_dir="${SCRIPT_DIR}/../"
    clone_dir="${SCRIPT_DIR##*/}"
fi

# Check prerequisites
for preq in "${GIT}" "${python_cmd}"
do
    if ! hash "${preq}" &>/dev/null
    then
        printf "\n%s\n" "${delimiter}"
        printf "\e[1m\e[31mERROR: %s is not installed, aborting...\e[0m" "${preq}"
        printf "\n%s\n" "${delimiter}"
        exit 1
    fi
done

# Add local bin to path (required for pip)
PATH=$HOME/.local/bin:$PATH

# Pip installation, see: https://pip.pypa.io/en/stable/installation/
if ! command -v "${pip_cmd}" &> /dev/null
then
    printf "\n%s\n" "${delimiter}"
    printf "Installing pip...\n"
    "${python_cmd}" -m ensurepip --upgrade
    printf "Pip installation complete..."
    printf "\n%s\n" "${delimiter}"
fi

# uv installation
if ! command -v "${uv_cmd}"  &> /dev/null
then
    printf "\n%s\n" "${delimiter}"
    printf "Installing uv using pip...\n"
    "${pip_cmd}" install -U uv
    printf "UV installation complete..."
    printf "\n%s\n" "${delimiter}"
fi

cd "${install_dir}"/"${clone_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/%s/, aborting...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }

if [[ ! "$OFFLINE_MODE" == "true" ]]
then
    # Installation of files using git large file storage
    printf "\n%s\n" "${delimiter}"
    printf "Checking and retriveing files from Git LFS...\n"
    git lfs install
    git lfs pull
    printf "Git LFS update complete\n"
    printf "\n%s\n" "${delimiter}"

    # Installation of dependencies using uv
    printf "\n%s\n" "${delimiter}"
    printf "Checking and updating dependencies using uv...\n"
    ${uv_cmd} sync --all-extras
    printf "Dependency update using uv complete\n"
    printf "\n%s\n" "${delimiter}"

    # Installation of huggingfacehub command line interface
    printf "\n%s\n" "${delimiter}"
    printf "Checking and updating huggingface hub cli...\n"
    ${uv_cmd} tool install "huggingface_hub[cli]"
    printf "Huggingface hub cli update complete\n"
    printf "\n%s\n" "${delimiter}"

    # Download and installation of checkpoints from huggingface
    printf "\n%s\n" "${delimiter}"
    printf "Downloading and verifying checkpoints...\n"
    ${ckpt_install_cmd}
    printf "Checkpoints installation complete\n"
    printf "\n%s\n" "${delimiter}"

fi

# Try using TCMalloc on Linux
prepare_tcmalloc() {
    if [[ "${OSTYPE}" == "linux"* ]] && [[ -z "${NO_TCMALLOC}" ]] && [[ -z "${LD_PRELOAD}" ]]; then
        # check glibc version
        LIBC_VER=$(echo $(ldd --version | awk 'NR==1 {print $NF}') | grep -oP '\d+\.\d+')
        echo "glibc version is $LIBC_VER"
        libc_vernum=$(expr $LIBC_VER)
        # Since 2.34 libpthread is integrated into libc.so
        libc_v234=2.34
        # Define Tcmalloc Libs arrays
        TCMALLOC_LIBS=("libtcmalloc(_minimal|)\.so\.\d" "libtcmalloc\.so\.\d")
        # Traversal array
        for lib in "${TCMALLOC_LIBS[@]}"
        do
            # Determine which type of tcmalloc library the library supports
            TCMALLOC="$(PATH=/sbin:/usr/sbin:$PATH ldconfig -p | grep -P $lib | head -n 1)"
            TC_INFO=(${TCMALLOC//=>/})
            if [[ ! -z "${TC_INFO}" ]]; then
                echo "Check TCMalloc: ${TC_INFO}"
                # Determine if the library is linked to libpthread and resolve undefined symbol: pthread_key_create
                if [ $(echo "$libc_vernum < $libc_v234" | bc) -eq 1 ]; then
                    # glibc < 2.34 pthread_key_create into libpthread.so. check linking libpthread.so...
                    if ldd ${TC_INFO[2]} | grep -q 'libpthread'; then
                        echo "$TC_INFO is linked with libpthread,execute LD_PRELOAD=${TC_INFO[2]}"
                        # set fullpath LD_PRELOAD (To be on the safe side)
                        export LD_PRELOAD="${TC_INFO[2]}"
                        break
                    else
                        echo "$TC_INFO is not linked with libpthread will trigger undefined symbol: pthread_Key_create error"
                    fi
                else
                    # Version 2.34 of libc.so (glibc) includes the pthread library IN GLIBC. (USE ubuntu 22.04 and modern linux system and WSL)
                    # libc.so(glibc) is linked with a library that works in ALMOST ALL Linux userlands. SO NO CHECK!
                    echo "$TC_INFO is linked with libc.so,execute LD_PRELOAD=${TC_INFO[2]}"
                    # set fullpath LD_PRELOAD (To be on the safe side)
                    export LD_PRELOAD="${TC_INFO[2]}"
                    break
                fi
            fi
        done
        if [[ -z "${LD_PRELOAD}" ]]; then
            printf "\e[1m\e[31mCannot locate TCMalloc. Do you have tcmalloc or google-perftool installed on your system? (improves CPU memory usage)\e[0m\n"
        fi
    fi
}

build_lock_file="indextts/BigVGAN/alias_free_activation/cuda/build/lock"

# If nvcc compilation is aborted, it will leave a lock file which is used to prevent parallel builds, the lock file must be deleted to allow launch
if [[ -f "$build_lock_file" ]]
then
    printf "\n%s\n" "${delimiter}"
    printf "Removing nvcc build lock file at ${build_lock_file}"
    rm $build_lock_file
    printf "\n%s\n" "${delimiter}"
fi

if [[ "$OFFLINE_MODE" == "true" ]]; then
    export HF_HUB_OFFLINE=1
fi

printf "\n%s\n" "${delimiter}"
printf "Launching ${LAUNCH_SCRIPT}..."
printf "\n%s\n" "${delimiter}"
prepare_tcmalloc
"${uv_cmd}" run "${LAUNCH_SCRIPT}"
