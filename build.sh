#!/bin/bash

# Treat unset variables as errors.
set -u

program="build.sh"

function usage() {
    cat <<EOF
$program, simple tool for building Factorio mod releases

Usage: $program [OPTIONS] build

$program is a simple tool for building Factorio mod releases. Tool
accepts a single positional command for performing the build itself.

Release files are placed under the dist/ sub-directory, and built
under build/ sub-directory.

The tool will perform some basic file syntax checks on included JSON
and Lua files. Command 'jq' must be available locally in order to
perform these checks.

$program accepts the following options:

    -q
        Quiet mode. Output a message only if newer packages are available.
    -d
        Enable debug mode.
    -h
        Show usage help.

EOF
}

# Set-up colours for message printing if we're not piping and terminal is
# capable of outputting the colors.
_color_terminal=$(tput colors 2>&1)
if [[ -t 1 ]] && (( _color_terminal > 0 )); then
    _text_bold=$(tput bold)
    _text_white=$(tput setaf 7)
    _text_blue=$(tput setaf 6)
    _text_green=$(tput setaf 2)
    _text_yellow=$(tput setaf 3)
    _text_red=$(tput setaf 1)
    _text_reset=$(tput sgr0)
else
    _text_bold=""
    _text_white=""
    _text_blue=""
    _text_green=""
    _text_yellow=""
    _text_red=""
    _text_reset=""
fi

# Set-up functions for printing coloured messages.
function debug() {
    if [[ $debug != 0 ]]; then
        echo "${_text_bold}${_text_blue}[DEBUG]${_text_reset}" "$@"
    fi
}

function info() {
    if [[ $quiet == 0 ]]; then
        echo "${_text_bold}${_text_white}[INFO] ${_text_reset}" "$@"
    fi
}

function success() {
    if [[ $quiet == 0 ]]; then
        echo "${_text_bold}${_text_green}[OK]   ${_text_reset}" "$@"
    fi
}

function warning() {
    echo "${_text_bold}${_text_yellow}[WARN] ${_text_reset}" "$@" >&2
}

function error() {
    echo "${_text_bold}${_text_red}[ERROR]${_text_reset}" "$@" >&2
}

# Define error codes.
SUCCESS=0
ERROR_ARGUMENTS=1
ERROR_GENERAL=2
ERROR_VALIDATION_FAILED=3

# Disable debug and quiet modes by default.
debug=0
quiet=0

# If no arguments were given, just show usage help.
if [[ -z ${1-} ]]; then
    usage
    exit "$SUCCESS"
fi

# Parse the arguments
while getopts "qdh" opt; do
    case "$opt" in
	q) quiet=1;;
	d) debug=1;;
        h) usage
           exit "$SUCCESS";;
        *) usage
           exit "$ERROR_ARGUMENTS";;
    esac
done
i=$OPTIND
shift $(( i-1 ))

command="$1"

if [[ $command != "build" ]]; then
    error "Unsupported command: $command"
    exit "$ERROR_ARGUMENTS"
fi

# Check if the necessary tools are available.
if ! type jq &>/dev/null; then
    error "Could not locate the 'jq' command. Please install the relevant package before trying again."
    exit "$ERROR_GENERAL"
fi

# Set-up paths.
base_dir=$(dirname "$(readlink -f "$0")")
dist_dir="$base_dir/dist"
build_dir="$base_dir/build"
info_file="$base_dir/info.json"

# Extract modpack name and version
if ! jq . "$info_file" > /dev/null; then
    error "Could not parse mod info file: $info_file"
    exit "$ERROR_VALIDATION_FAILED"
fi

modpack_name=$(jq -r ".name" "$info_file")
modpack_version=$(jq -r ".version" "$info_file")

# Set-up target directory and archive paths.
target_dir="${build_dir}/${modpack_name}_${modpack_version}"
archive="${dist_dir}/${modpack_name}_${modpack_version}.zip"

# Create list of files to package. Exclude development files from the
# build.
ignore_paths=(".gitignore" ".dir-locals.el" "build.sh")
readarray -t file_list < <(git -C "$base_dir" ls-files)

for ignored_path in "${ignore_paths[@]}"; do
    for i in "${!file_list[@]}"; do
        if [[ -d $ignored_path && ${file_list[i]} == $ignored_path/* ]] || [[ ${file_list[i]} == "$ignored_path" ]]; then
            unset "file_list[i]"
        fi
    done
done

# Fix the index gaps in file list array.
file_list=("${file_list[@]}")

# Validate the files.
error_count=0

for mod_file in "${file_list[@]}"; do
    file_path="${base_dir}/${mod_file}"

    if [[ $file_path =~ .*\.lua ]] && ! luac -o /dev/null "$mod_file"; then
        (( error_count += 1 ))
        error "Validation failed for file: $mod_file"
    fi

    if [[ $file_path =~ .*\.json ]] && ! python -m json.tool "$mod_file" > /dev/null; then
        (( error_count += 1 ))
        error "Validation failed for file: $mod_file"
    fi
done

if [[ $error_count != 0 ]]; then
    exit "$ERROR_VALIDATION_FAILED"
fi

# Do some basic validation so we don't overwrite things by mistake.
if [[ -e $archive ]]; then
    error "Output archive already exists: $archive"
    exit "$ERROR_GENERAL"
fi

info "Building release: $modpack_version"

# Set-up the necessary directories.
rm -rf "$target_dir"
mkdir -p "$target_dir"
mkdir -p "$dist_dir"

# Copy the files.
if ! cd "$base_dir/"; then
    error "Failed to switch to base directory: $base_dir"
    exit "$ERROR_GENERAL"
fi
for mod_file in "${file_list[@]}"; do
    install -m 0644 -D "$mod_file" "${target_dir}/${mod_file}"
done

# Zip the files.
if ! cd "$build_dir/"; then
    error "Failed to switch to build directory: $build_dir"
    exit "$ERROR_GENERAL"
fi
if ! zip -q -r "$archive" "$(basename "$target_dir")"; then
    error "Could not prepare the release archive."
    exit "$ERROR_GENERAL"
fi

rm -rf "$target_dir"

success "Release built and placed under: $archive"
