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

# Index-TTS Checkpoint to use, either "1.0" or "1.5"
if [[ -z "${checkpoint}" ]]
then
    checkpoint="1.0"
fi

# If $venv_dir is "-", then disable venv support
use_venv=1
if [[ $venv_dir == "-" ]]; then
  use_venv=0
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
  python_cmd="python3.10"
fi
if [[ ! -x "$(command -v "${python_cmd}")" ]]
then
  python_cmd="python3"
fi

# git executable
if [[ -z "${GIT}" ]]
then
    export GIT="git"
else
    export GIT_PYTHON_GIT_EXECUTABLE="${GIT}"
fi

# python3 venv without trailing slash (defaults to ${install_dir}/${clone_dir}/venv)
if [[ -z "${venv_dir}" ]] && [[ $use_venv -eq 1 ]]
then
    venv_dir="venv"
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

if [[ $use_venv -eq 1 ]] && ! "${python_cmd}" -c "import venv" &>/dev/null
then
    printf "\n%s\n" "${delimiter}"
    printf "\e[1m\e[31mERROR: python3-venv is not installed, aborting...\e[0m"
    printf "\n%s\n" "${delimiter}"
    exit 1
fi

cd "${install_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/, aborting...\e[0m" "${install_dir}"; exit 1; }

if [[ $use_venv -eq 1 ]] && [[ -z "${VIRTUAL_ENV}" ]];
then
    printf "\n%s\n" "${delimiter}"
    printf "Create and activate python venv"
    printf "\n%s\n" "${delimiter}"
    cd "${install_dir}"/"${clone_dir}"/ || { printf "\e[1m\e[31mERROR: Can't cd to %s/%s/, aborting...\e[0m" "${install_dir}" "${clone_dir}"; exit 1; }
    if [[ ! -d "${venv_dir}" ]]
    then
        "${python_cmd}" -m venv "${venv_dir}"
        "${venv_dir}"/bin/python -m pip install --upgrade pip
        first_launch=1
    fi
    # shellcheck source=/dev/null
    if [[ -f "${venv_dir}"/bin/activate ]]
    then
        source "${venv_dir}"/bin/activate
        # ensure use of python from venv
        python_cmd="${venv_dir}"/bin/python
    else
        printf "\n%s\n" "${delimiter}"
        printf "\e[1m\e[31mERROR: Cannot activate python venv, aborting...\e[0m"
        printf "\n%s\n" "${delimiter}"
        exit 1
    fi
else
    printf "\n%s\n" "${delimiter}"
    printf "python venv already activate or run without venv: ${VIRTUAL_ENV}"
    printf "\n%s\n" "${delimiter}"
fi

printf "\n%s\n" "${delimiter}"
printf "Checking and installing python dependencies..."

if [[ "${reinstall_torch}" == "true" ]]
then
    echo "Reinstalling torch, to skip this in the future, comment or set reinstall_torch to false in webui-user.sh"
    torch_pip_params="--force-reinstall --upgrade"
fi

if [[ "${quiet_pip}" == "true" ]]
then
    extra_pip_params="-q"
fi

pip install $extra_pip_params $torch_pip_params torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
pip install $extra_pip_params -r requirements.txt
pip install $extra_pip_params deepspeed
printf "\n%s\n" "${delimiter}"

case "${checkpoint}" in
    1.0)
        ckpt_folder="checkpoints"

        printf "Checking \"${ckpt_folder}\" directory for models..."

        if [[ ! -f "${ckpt_folder}/config.yaml" ]]
        then
            wget https://huggingface.co/IndexTeam/Index-TTS/resolve/main/config.yaml -P $ckpt_folder
            sed -i 's|bpe_model: checkpoints/bpe.model|bpe_model: bpe.model|' $ckpt_folder/config.yaml
        fi

        if [[ ! -f "${ckpt_folder}/bigvgan_discriminator.pth" ]]
        then
            wget https://huggingface.co/IndexTeam/Index-TTS/resolve/main/bigvgan_discriminator.pth -P $ckpt_folder 
        fi

        if [[ ! -f "${ckpt_folder}/bigvgan_generator.pth" ]]
        then
            wget https://huggingface.co/IndexTeam/Index-TTS/resolve/main/bigvgan_generator.pth -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/bpe.model" ]]
        then
            wget https://huggingface.co/IndexTeam/Index-TTS/resolve/main/bpe.model -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/dvae.pth" ]]
        then
            wget https://huggingface.co/IndexTeam/Index-TTS/resolve/main/dvae.pth -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/gpt.pth" ]]
        then
            wget https://huggingface.co/IndexTeam/Index-TTS/resolve/main/gpt.pth -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/unigram_12000.vocab" ]]
        then
            wget https://huggingface.co/IndexTeam/Index-TTS/resolve/main/unigram_12000.vocab -P $ckpt_folder
        fi
        ;;
    1.5)
        ckpt_folder="checkpoints15"

        printf "Checking \"${ckpt_folder}\" directory for models..."

        if [ ! -d "$ckpt_folder" ]; then
            echo Creating \"$ckpt_folder\" directory.
            mkdir -p "$ckpt_folder"
        fi

        if [[ ! -f "${ckpt_folder}/bigvgan_discriminator.pth" ]]
        then
            wget https://huggingface.co/IndexTeam/IndexTTS-1.5/resolve/main/bigvgan_discriminator.pth -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/bigvgan_generator.pth" ]]
        then
            wget https://huggingface.co/IndexTeam/IndexTTS-1.5/resolve/main/bigvgan_generator.pth -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/bpe.model" ]]
        then
            wget https://huggingface.co/IndexTeam/IndexTTS-1.5/resolve/main/bpe.model -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/dvae.pth" ]]
        then
            wget https://huggingface.co/IndexTeam/IndexTTS-1.5/resolve/main/dvae.pth -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/gpt.pth" ]]
        then
            wget https://huggingface.co/IndexTeam/IndexTTS-1.5/resolve/main/gpt.pth -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/unigram_12000.vocab" ]]
        then
            wget https://huggingface.co/IndexTeam/IndexTTS-1.5/resolve/main/unigram_12000.vocab -P $ckpt_folder
        fi

        if [[ ! -f "${ckpt_folder}/config.yaml" ]]
        then
            wget https://huggingface.co/IndexTeam/IndexTTS-1.5/resolve/main/config.yaml -P $ckpt_folder
        fi
        ;;
esac

    printf "\n%s\n" "${delimiter}"

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

printf "\n%s\n" "${delimiter}"
printf "Launching ${LAUNCH_SCRIPT}..."
printf "\n%s\n" "${delimiter}"
prepare_tcmalloc
"${python_cmd}" -u "${LAUNCH_SCRIPT}" "$@" "--model_dir" "${ckpt_folder}"
