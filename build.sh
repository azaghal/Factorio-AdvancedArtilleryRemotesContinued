#!/bin/bash
#
# factorio_development.sh
#
# Copyright (C) 2022, Branko Majic <branko@majic.rs>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#

# Treat unset variables as errors.
set -u

PROGRAM="factorio_development.sh"
VERSION="1.1.0"

function usage() {
    cat <<EOF
$PROGRAM $VERSION, helper tool for development of Factorio mods

Usage:

  $PROGRAM [OPTIONS] init [MOD_DIRECTORY_PATH]
  $PROGRAM [OPTIONS] build [MOD_DIRECTORY_PATH]
  $PROGRAM [OPTIONS] release MOD_VERSION [MOD_DIRECTORY_PATH]
  $PROGRAM [OPTIONS] abort-release [MOD_DIRECTORY_PATH]

EOF
}

function short_help() {
    cat <<EOF
$(usage)

For more details see $PROGRAM -h.
EOF
}

function long_help() {
    cat <<EOF
$(usage)

$PROGRAM is a helper tool for development of Factorio mods.

The tool enforces certain conventions to make the mod development
fairly consistent across the board. The following conventions are
used:

- Development version is always 999.999.999 in order to guarantee that
  mod upgrade events get triggered properly and processed by event
  handlers. It also provides clear indicator to both developer and
  player that a development version is in use.

- Similar to version, development release date is set to 9999-99-99,
  thus guaranteeing that the changelog clearly indicates that the
  development version is currently in use.

Multiple commands are provided for covering the entire lifecycle of
Factorio mod development. Each command accepts its own set of
positional argument.


init MOD_DIRECTORY_PATH

  Arguments:

    MOD_DIRECTORY_PATH (path to base directory)

  Initialises directory for new mod development. Passed-in directory
  must be empty. Mod name is derived from the directory name. If the
  passed-in mod directory path does not point to an existing
  directory, it will be created. If not specified, default is to use
  working directory as mod directory path.

  During initialisation it is possible to select if mod sources should
  be kept in a separate directory or within the base directory. This
  can be helpful for separating non-Factorio assets and files (such as
  license, README file etc).

  The following files are created as part of the process ([src/]
  indicates optional placement under separate source directory):

    - build.sh, factorio_development.sh script itself.
    - README.md, provides detailed mod description and information.
    - LICENSE, contains license information for the mod.
    - .gitignore, for ignoring files and paths when working with git.
    - build.cfg, for configuring how the releases are built.
    - [src/]info.json, mod metadata.
    - [src/]changelog.txt, with changelog information for the mod.


build [MOD_DIRECTORY_PATH]

  Arguments:

    MOD_DIRECTORY_PATH (path to base directory)

  Builds release of a mod. Expects (optional) path to mod base
  directory. Default is to use working directory as mod directory
  path.

  Temporary files are stored under the "build" sub-directory, while
  the release zip archive is placed under the "dist" sub-directory
  (relative to mod base directory).

  By default, the build command includes all files in the release
  archive - even when separate directory for mod sources is
  used. Files can be excluded from the archive via "ignore_paths"
  option in build configuration file (build.cfg).


release MOD_VERSION [MOD_DIRECTORY_PATH]

  Arguments:

    MOD_VERSION (version to release)
    MOD_DIRECTORY_PATH (path to base directory)

  Builds release of a mod. Expects (optional) path to mod base
  directory. Default is to use working directory as mod directory
  path.

  Release process will:

  - Create new branch based on passed-in version.
  - Replace development version in info.json and changelog.txt with
    passed-in release version, and commit those changes.
  - Build the release.
  - Create annotated tag.
  - Switch back to development version in info.json and changelog.txt
    and commit those changes.

  When committing the changes, user will be prompted to modify the
  pre-defined commit message (if so desired).

  After this has been taken care of, the following manual steps are
  required:

  - Merge the release branch into main branch.
  - Push the changes and tags to repository origin.
  - Upload the release to mods portal.

  The release process can be configured to use a prefix for version
  tags using the git_version_tag_prefix option in the build
  configuration file (build.cfg). This can be used to, for example,
  have the tags created as "release/1.0.0" or "v1.0.0" instead of
  default "1.0.0".


abort-release [MOD_DIRECTORY_PATH]

  Arguments:

    MOD_DIRECTORY_PATH (path to base directory)

  Aborts release process (started with the release command) for a
  mod. Expects (optional) path to mod base directory. Default is to
  use working directory as mod directory path.

  Must be run from a release branch.

  Aborting the release will:

  - Undo all current changes to git-managed files.
  - Drop version tag associated with the release branch.
  - Switch back to main branch.
  - Drop the release branch.


$PROGRAM accepts the following options:

    -q
        Quiet mode.
    -d
        Enable debug mode.
    -v
        Show script version and licensing information.
    -h
        Show full help.

Please report bugs and send feature requests to <branko@majic.rs>.
EOF
}

function version() {
    cat <<EOF
$PROGRAM, version $VERSION

+-----------------------------------------------------------------------+
| Copyright (C) 2022, Branko Majic <branko@majic.rs>                    |
|                                                                       |
| This program is free software: you can redistribute it and/or modify  |
| it under the terms of the GNU General Public License as published by  |
| the Free Software Foundation, either version 3 of the License, or     |
| (at your option) any later version.                                   |
|                                                                       |
| This program is distributed in the hope that it will be useful,       |
| but WITHOUT ANY WARRANTY; without even the implied warranty of        |
| MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         |
| GNU General Public License for more details.                          |
|                                                                       |
| You should have received a copy of the GNU General Public License     |
| along with this program.  If not, see <http://www.gnu.org/licenses/>. |
+-----------------------------------------------------------------------+

EOF
}


# Utilities
# =========

#
# Finds the source directory under the passed-in base directory.
#
# Arguments:
#
#   $1 (base_dir)
#     Base mod directory.
#
# Outputs:
#
#   Path to mod sources directory.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function get_source_directory() {
    local base_dir="$1"

    local source_dir

    if [[ -d $base_dir/src ]]; then
        source_dir="src"
    else
        source_dir="."
    fi

    if [[ ! -d $source_dir ]]; then
        error "Could not locate source directory."
        return 1
    fi

    echo "$source_dir"
    return 0
}


#
# Finds the info file under the passed-in base directory.
#
# Arguments:
#
#   $1 (base_dir)
#     Base mod directory.
#
# Outputs:
#
#   Path to info file.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function get_info_file() {
    local base_dir="$1"

    local info_file

    if [[ -d $base_dir/src ]]; then
        info_file="$base_dir/src/info.json"
    else
        info_file="$base_dir/info.json"
    fi

    if [[ ! -f $info_file ]]; then
        error "Could not locate info file under: $info_file"
        return 1
    fi

    echo "$info_file"
    return 0
}


#
# Finds the changelog file under the passed-in base directory.
#
# Arguments:
#
#   $1 (base_dir)
#     Base mod directory.
#
# Outputs:
#
#   Path to changelog file.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function get_changelog_file() {
    local base_dir="$1"

    local changelog_file

    if [[ -d $base_dir/src ]]; then
        changelog_file="$base_dir/src/changelog.txt"
    else
        changelog_file="$base_dir/changelog.txt"
    fi

    if [[ ! -f $changelog_file ]]; then
        error "Could not locate changelog file under: $changelog_file"
        return 1
    fi

    echo "$changelog_file"
    return 0
}


#
# Loads build configuration from the passed-in base directory.
#
# Arguments:
#
#   $1 (base_dir)
#     Base mod directory.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function load_build_configuration() {
    build_config="$base_dir/build.cfg"

    # Set default values to ensure they are set.
    declare -g IGNORE_PATHS=()
    declare -g GIT_VERSION_TAG_PREFIX=""

    # Read build configuration.
    # shellcheck disable=SC1090 # build configuration file is create per-mod directory
    if [[ -f $build_config ]] && ! source "$build_config"; then
        error "Failed to load build configuration from: $build_config"
        return 1
    fi

    return 0
}


#
# Determines the main branch name (should be master/main/devel).
#
#
# Arguments:
#
#   $1 (base_dir)
#     Mod base directory.
#
# Outputs:
#
#   Branch name.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function get_main_branch() {
    local base_dir="$1"

    local candidates=(
        "master"
        "main"
        "devel"
    )

    local candidate

    for candidate in "${candidates[@]}"; do
        if git -C "$base_dir" rev-parse --abbrev-ref "$candidate" >/dev/null 2>&1; then
            echo "$candidate"
            return 0
        fi
    done

    error "Could not determine main branch."

    return 1
}


#
# Determines the current branch name.
#
#
# Arguments:
#
#   $1 (base_dir)
#     Mod base directory.
#
# Outputs:
#
#   Branch name.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function get_current_branch() {
    local base_dir="$1"

    if ! git -C "$base_dir" rev-parse --abbrev-ref "HEAD"; then
        error "Could not determine current branch name."
        return 1
    fi

    return 0
}


#
# Retrieves the mod name, as set in the info file.
#
# Arguments:
#
#   $1 (base_dir)
#     Base mod directory.
#
# Outputs:
#
#   Mod name.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function get_mod_name() {
    local base_dir="$1"

    local info_file mod_name

    info_file=$(get_info_file "$base_dir") || return 1

    if ! mod_name=$(jq -r ".name" "$info_file") || [[ -z $mod_name ]]; then
        error "Failed to obtain mod name from: $info_file"
        return 1
    fi

    echo "$mod_name"
    return 0
}


# Commands
# ========

#
# Initialises mod directory structure.
#
# Arguments:
#
#   $1 (base_dir)
#     Base directory under which the structure should be created.
#
#   $2 (development_script)
#     Path to build/development script to include in the repository.
#
# Returns:
#   0 on success, 1 otherwise.
#
function command_init() {
    local base_dir="$1"
    local development_script="$2"

    local mod_name separate_source source_dir

    # Normalise the path.
    base_dir=$(readlink -f "$base_dir")

    # Determine the mod name.
    mod_name=$(basename "$base_dir")

    # Read list of all files in destination directory.
    shopt -s nullglob
    local base_dir_files=("$base_dir"/* "$base_dir"/.*)
    shopt -u nullglob

    if [[ -e $base_dir && ! -d $base_dir ]]; then
        error "Specified path is not a directory."
        return 1
    fi

    # Only . and .. entries are allowed in the listing (directory must be empty or non-existant).
    if (( ${#base_dir_files[@]} > 2 )); then
        error "Directory must be empty."
        return 1
    fi

    # Set-up the base directory (if it does not exist).
    if ! mkdir -p "$base_dir"; then
        error "Failed to create the base mod directory."
        return 1
    fi

    # Create separate source directory if the user requests it.
    while [[ ${separate_source-} == "" || ${separate_source,,} != y && ${separate_source,,} != n ]]; do
        read -r -p "Separate mod source under \"src/\" sub-directory? (y/n) " separate_source
    done

    [[ ${separate_source,,} == y ]] && source_dir="$base_dir/src" || source_dir="$base_dir"
    mkdir -p "$source_dir"

    # Include the development script itself into the repository (for ease of use).
    cp "$development_script" "$base_dir/build.sh"

    # Create initial set of files.
    cat <<EOF > "$base_dir/README.md"
MOD_TITLE
=========


About
-----


Features
--------


Known issues
------------

There are no known issues at this time.


Contributions
-------------

Bugs and feature requests can be reported through discussion threads or through project's issue tracker. For general questions, please use discussion threads.

Pull requests for implementing new features and fixing encountered issues are always welcome.


Credits
-------


License
-------

All code, documentation, and assets implemented as part of this mod are released under the terms of MIT license (see the accompanying \`LICENSE\` file), with the following exceptions:

-   [build.sh (factorio_development.sh)](https://code.majic.rs/majic-scripts/), by Branko Majic, under [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html).
EOF

    cat <<EOF > "$base_dir/LICENSE"
Copyright (c) $(date +%Y) YOUR_NAME

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

    cat <<EOF > "$base_dir/build.cfg"
# -*- mode: sh-mode; sh-shell: bash -*-

# Specify list of paths to exclude from the built release archives.
IGNORE_PATHS=(
    ".dir-locals.el"
    ".gitignore"
    "build.cfg"
    "build.sh"
)

# Specify prefix to use in front of versions when tagging releases
# (for example if tags should be of format vX.Y.Z as opposed to
# X.Y.Z).
GIT_VERSION_TAG_PREFIX=""
EOF

    cat <<EOF > "$base_dir/.gitignore"
# Ignore IDE and backup files.
*~
.#*

# Ignore build artefacts.
dist/
build/

# Ignore project temporary directory.
tmp/
EOF

    cat <<EOF > "$base_dir/.dir-locals.el"
;; Set wrapping column for Emacs lua-mode.
((lua-mode . ((fill-column . 120))))
EOF

    cat <<EOF > "$source_dir/info.json"
{
    "name": "$mod_name",
    "version": "999.999.999",
    "title": "MOD_TITLE",
    "author": "YOUR_NAME",
    "homepage": "HOMEPAGE",
    "description": "DESCRIPTION",
    "factorio_version": "1.1",
    "dependencies": [
        "? base >= 1.1.0"
     ]
}
EOF

    cat <<EOF > "$source_dir/changelog.txt"
---------------------------------------------------------------------------------------------------
Version: 999.999.999
Date: 9999-99-99
  Changes:
  Features:
  Bugfixes:
EOF

    cat <<EOF > "$source_dir/control.lua"
-- Copyright (c) $(date +%Y) YOUR_NAME
-- Provided under MIT license. See LICENSE for details.
EOF

    git init "$base_dir"
    git -C "$base_dir" add .

    success "Mod structure initialised."

    return 0
}


#
# Builds mod relase archive.
#
# Arguments:
#
#   $1 (base_dir)
#     Base (top-level) directory with the mod files.
#
# Returns:
#   0 on success, 1 otherwise.
#
function command_build() {
    local base_dir="$1"

    local error_count=0

    declare -a mod_files

    local source_dir dist_dir build_dir info_file target_dir archive_file build_config
    local mod_name mod_version
    local path mod_file mod_file_path

    # Calculate absolute paths to various directories and artifacts.
    base_dir=$(readlink -f "$base_dir")
    build_dir="$base_dir/build"
    dist_dir="$base_dir/dist"

    load_build_configuration "$base_dir" || return 1

    source_dir=$(get_source_directory "$base_dir") || return 1
    info_file=$(get_info_file "$base_dir") || return 1

    # Extract modpack name and version
    if ! jq . "$info_file" > /dev/null; then
        error "Could not parse mod info file: $info_file"
        return 1
    fi
    mod_name=$(get_mod_name "$base_dir") || return 1
    mod_version=$(jq -r ".version" "$info_file")

    # Validate version string format.
    if [[ ! $mod_version =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$ ]]; then
        error "Invalid mod version read from info file: $mod_version"
        return 1
    fi

    target_dir="${build_dir}/${mod_name}_${mod_version}"
    archive_file="${dist_dir}/${mod_name}_${mod_version}.zip"

    # Create list of files to package. Exclude development files from the
    # build.
    readarray -t mod_files < <(git -C "$base_dir" ls-files)

    # IGNORE_PATHS comes from build configuration.
    for path in "${IGNORE_PATHS[@]}"; do
        for i in "${!mod_files[@]}"; do
            if [[ -d $path && ${mod_files[i]} == $path/* ]] || [[ ${mod_files[i]} == "$path" ]]; then
                unset "mod_files[i]"
            fi
        done
    done

    # Fix the index gaps in file list array.
    mod_files=("${mod_files[@]}")

    # Validate the files.
    error_count=0

    for mod_file in "${mod_files[@]}"; do
        mod_file_path="${base_dir}/${mod_file}"

        if [[ $mod_file_path =~ .*\.lua ]] && ! luac -o /dev/null "$mod_file_path"; then
            (( error_count += 1 ))
            error "Validation failed for file: $mod_file"
        fi

        if [[ $mod_file_path =~ .*\.json ]] && ! python -m json.tool "$mod_file_path" > /dev/null; then
            (( error_count += 1 ))
            error "Validation failed for file: $mod_file"
        fi
    done

    if [[ $error_count != 0 ]]; then
        return 1
    fi

    # Do some basic validation so we do not overwrite things by mistake.
    if [[ -e $archive_file ]]; then
        error "Output archive already exists: $archive_file"
        return 1
    fi

    info "Building release: $mod_version"

    # Set-up the necessary directories.
    rm -rf "$target_dir"
    mkdir -p "$target_dir"
    mkdir -p "$dist_dir"

    # Copy the files.
    for mod_file in "${mod_files[@]}"; do
        if ! (cd "$base_dir" && install -m 0644 -D "$mod_file" "${target_dir}/${mod_file%%${source_dir}/}"); then
            error "Failed to copy the file: $mod_file"
            return 1
        fi
    done

    # Move sources to base directory.
    if [[ $source_dir != . ]]; then
        mv -n "${target_dir}/${source_dir}"/* "${target_dir}"
        if ! rmdir "${target_dir}/${source_dir}"; then
            error "Failed to remove directory: ${target_dir}/${source_dir}"
            return 1
        fi
    fi

    # Zip the files.
    if ! (cd "$build_dir/" && zip -q -r "$archive_file" "$(basename "$target_dir")"); then
        error "Could not prepare the release archive."
        return 1
    fi

    rm -rf "$target_dir"

    success "Release built and placed under: $archive_file"
}


#
# Releases a mod version. Takes care of creating separate branch,
# making versioning changes/updates to mod information file and
# changelog, creating the tags, and even switching back the mod to
# development version.
#
# Arguments:
#
#   $1 (version)
#     Version of mod to release.
#
#   $2 (base_dir)
#     Base (top-level) directory with the mod files.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function command_release() {
    local version="$1"
    local base_dir="$2"

    local info_file changelog_file build_config changelog
    local main_branch current_branch release_branch

    build_config="$base_dir/build.cfg"

    # Read build configuration.
    # shellcheck disable=SC1090 # build configuration file is create per-mod directory
    if [[ -f $build_config ]] && ! source "$build_config"; then
        error "Failed to load build configuration from: $build_config"
        return 1
    fi

    current_branch=$(git -C "$base_dir" rev-parse --abbrev-ref HEAD)
    release_branch="release-${version}"

    source_dir=$(get_source_directory "$base_dir") || return 1
    info_file=$(get_info_file "$base_dir") || return 1
    changelog_file=$(get_changelog_file "$base_dir") || return 1
    current_branch=$(get_current_branch "$base_dir") || return 1
    main_branch=$(get_main_branch "$base_dir") || return 1

    if [[ $current_branch != "$main_branch" ]]; then
        error "Releases must be based off of the main branch."
        return 1
    fi

    if [[ $(git -C "$base_dir" status --short) != "" ]]; then
        error "Releases must be based off of a clean git working tree."
        return 1
    fi

    if ! git -C "$base_dir" checkout -b "$release_branch"; then
        error "Failed to create release branch: $release_branch"
        return 1
    fi

    # Update versioning information in info file and changelog.
    sed -i -e "s/999.999.999/$version/" "$info_file" "$changelog_file"

    # Update release date.
    sed -i -e "s/9999-99-99/$(date +%Y-%m-%d)/" "$changelog_file"

    # Drop empty changelog sections. Changelog sections begin with two
    # whitespaces at line beginning, followed by a non-whitespace
    # character.
    #
    # First sed expression:
    #
    # 1. Finds a section line.
    # 2. Reads the next line and adds it to pattern space. If the next
    #    line is not a section line, outputs the section it found
    #    (P). Otherwise it deletes the matched section line (D).
    # 3. Finally, it checks if the next line read (in step 2) is also
    #    a section line, and if it is, repeats the process for it (has
    #    to be done via goto directive since sed cannot be told to
    #    re-read the lines once they have been read with the N
    #    directive).
    #
    # Second sed expression deals with empty sections at the end of
    # the file (special case).
    sed -i -E -e '/^  [^ ]/{: checknext; N; /\n   /P; D; /^  [^ ]/b checknext}' "$changelog_file"
    sed -i -z -E -e 's/\n  [^ \n]+\n$/\n/' "$changelog_file"

    # Build the release.
    if ! command_build "$base_dir"; then
        return 1
    fi

    # @WORKAROUND: For using git tag signing on older versions of git.
    if [[ $(git -C "$base_dir" config --get tag.gpgSign) == true ]]; then
        local git_tag_gpgsign=("--sign")
    else
        local git_tag_gpgsign=()
    fi

    # Commit the changes and create a tag. GIT_VERSION_TAG_PREFIX
    # comes from build configuration.
    if ! git -C "$base_dir" add "$changelog_file" "$info_file" || \
       ! git -C "$base_dir" commit --edit --message "Prepared release $version." || \
       ! git -C "$base_dir" tag "${git_tag_gpgsign[@]}" --annotate --message "Release $version." "${GIT_VERSION_TAG_PREFIX}${version}"; then

        error "Failed to create release commit and tag."
        return 1
    fi

    # Switch back to development version.
    sed -i -e "s/$version/999.999.999/" "$info_file"
    changelog=$(cat <<EOF
---------------------------------------------------------------------------------------------------
Version: 999.999.999
Date: 9999-99-99
  Changes:
  Features:
  Bugfixes:
$(cat "$changelog_file")
EOF
                )
    echo "$changelog" > "$changelog_file"

    # Commit the changes.
    if ! git -C "$base_dir" add "$changelog_file" "$info_file" || \
       ! git -C "$base_dir" commit --message "Switched back to development version."; then
        error "Failed to create developement commit."
        return 1
    fi

    return 0
}


#
# Aborts the current release process.
#
# Arguments:
#
#   $1 (base_dir)
#     Base (top-level) directory with the mod files.
#
# Returns:
#
#   0 on success, 1 otherwise.
#
function command_abort_release() {
    local base_dir="$1"

    local info_file changelog_file build_config mod_name release_archive
    local current_branch release_branch version

    load_build_configuration "$base_dir" || return 1
    main_branch=$(get_main_branch "$base_dir") || return 1
    release_branch=$(get_current_branch "$base_dir") || return 1
    mod_name=$(get_mod_name "$base_dir") || return 1
    version="${release_branch##release-}"
    release_archive="${base_dir}/dist/${mod_name}_${version}.zip"

    if [[ ! $release_branch =~ ^release-[[:digit:]]+\.[[:digit:]]+\.[[:digit:]] ]]; then
        error "Current branch is not a release branch."
        return 1
    fi

    # Drop the release archive.
    if [[ -f "${base_dir}/dist/${mod_name}_${version}.zip" ]] &&
       ! rm "$release_archive"; then

        error "Failed to remove the release file: $release_archive"
        return 1
    fi

    # Drop the tag.
    if [[ -n $(git -C "$base_dir" tag --list "${GIT_VERSION_TAG_PREFIX}${version}") ]] &&
       ! git tag --delete "${GIT_VERSION_TAG_PREFIX}${version}"; then

        error "Failed to drop the git tag: ${GIT_VERSION_TAG_PREFIX}${version}"
        return 1
    fi

    # Reset working directory, dropping eventual local changes.
    if ! git -C "$base_dir" reset --hard HEAD; then
        error "Failed to reset working directory."
        return 1
    fi

    # Switch back to main branch.
    if ! git -C "$base_dir" checkout "$main_branch"; then
        error "Failed to switch to main branch."
        return 1
    fi

    # Drop the release branch.
    if ! git -C "$base_dir" branch --delete --force "$release_branch"; then
        error "Failed to remove the release branch."
        return 1
    fi

    return 0
}


# Set-up colours for message printing if we're not piping and terminal is
# capable of outputting the colors.
_COLOR_TERMINAL=$(tput colors 2>&1)
if [[ -t 1 ]] && (( _COLOR_TERMINAL > 0 )); then
    _TEXT_BOLD=$(tput bold)
    _TEXT_WHITE=$(tput setaf 7)
    _TEXT_BLUE=$(tput setaf 6)
    _TEXT_GREEN=$(tput setaf 2)
    _TEXT_YELLOW=$(tput setaf 3)
    _TEXT_RED=$(tput setaf 1)
    _TEXT_RESET=$(tput sgr0)
else
    _TEXT_BOLD=""
    _TEXT_WHITE=""
    _TEXT_BLUE=""
    _TEXT_GREEN=""
    _TEXT_YELLOW=""
    _TEXT_RED=""
    _TEXT_RESET=""
fi

# Set-up functions for printing coloured messages.
function debug() {
    if [[ $DEBUG != 0 ]]; then
        echo "${_TEXT_BOLD}${_TEXT_BLUE}[DEBUG]${_TEXT_RESET}" "$@"
    fi
}

function info() {
    if [[ $QUIET == 0 ]]; then
        echo "${_TEXT_BOLD}${_TEXT_WHITE}[INFO] ${_TEXT_RESET}" "$@"
    fi
}

function success() {
    if [[ $QUIET == 0 ]]; then
        echo "${_TEXT_BOLD}${_TEXT_GREEN}[OK]   ${_TEXT_RESET}" "$@"
    fi
}

function warning() {
    echo "${_TEXT_BOLD}${_TEXT_YELLOW}[WARN] ${_TEXT_RESET}" "$@" >&2
}

function error() {
    echo "${_TEXT_BOLD}${_TEXT_RED}[ERROR]${_TEXT_RESET}" "$@" >&2
}

# Define error codes.
SUCCESS=0
ERROR_ARGUMENTS=1
ERROR_GENERAL=2

# Disable debug and quiet modes by default.
DEBUG=0
QUIET=0

# If no arguments were given, just show usage help.
if [[ -z ${1-} ]]; then
    short_help
    exit "$SUCCESS"
fi

# Parse the arguments
while getopts "qdvh" opt; do
    case "$opt" in
	q) QUIET=1;;
	d) DEBUG=1;;
        v) version
           exit "$SUCCESS";;
        h) long_help
           exit "$SUCCESS";;
        *) short_help
           exit "$ERROR_ARGUMENTS";;
    esac
done
i=$OPTIND
shift $(( i-1 ))

# Quiet and debug are mutually exclusive.
if [[ $QUIET != 0 && $DEBUG != 0 ]]; then
    error "Quiet and debug options are mutually exclusive."
    exit "$ERROR_ARGUMENTS"
fi

COMMAND="${1-}"
shift

if [[ $COMMAND == init ]]; then

    MOD_DIRECTORY_PATH="${1:-.}"
    shift

    DEVELOPMENT_SCRIPT_PATH=$(readlink -f "$0")

    if [[ -e $MOD_DIRECTORY_PATH && ! -d $MOD_DIRECTORY_PATH ]]; then
        error "Passed-in path must be a directory."
        exit "$ERROR_ARGUMENTS"
    fi

    if ! command_init "$MOD_DIRECTORY_PATH" "$DEVELOPMENT_SCRIPT_PATH"; then
        exit "$ERROR_GENERAL"
    fi

elif [[ $COMMAND == build ]]; then

    MOD_DIRECTORY_PATH="${1:-.}"
    shift

    # Ensure that passed-in base directory is the repository root.
    if [[ ! -d $MOD_DIRECTORY_PATH/.git ]]; then
        error "Passed-in path does not point to base directory of the mod (must contain the .git sub-directory)."
        exit "$ERROR_ARGUMENTS"
    fi

    if ! command_build "$MOD_DIRECTORY_PATH"; then
        exit "$ERROR_GENERAL"
    fi

elif [[ $COMMAND == release ]]; then

    MOD_VERSION="${1-}"
    MOD_DIRECTORY_PATH="${2:-.}"
    shift 2

    if [[ -z $MOD_VERSION ]]; then
        error "Mod version must be specified."
        exit "$ERROR_ARGUMENTS"
    elif [[ ! $MOD_VERSION =~ ^[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+$ ]]; then
        error "Mod version must be specified in x.y.z format (where x, y, and z are non-negative integers)."
        exit "$ERROR_ARGUMENTS"
    fi

    # Ensure that passed-in base directory is the repository root.
    if [[ ! -d $MOD_DIRECTORY_PATH/.git ]]; then
        error "Passed-in path does not point to base directory of the mod (must contain the .git sub-directory)."
        exit "$ERROR_ARGUMENTS"
    fi

    if ! command_release "$MOD_VERSION" "$MOD_DIRECTORY_PATH"; then
        exit "$ERROR_GENERAL"
    fi

elif [[ $COMMAND == abort-release ]]; then

    MOD_DIRECTORY_PATH="${1:-.}"
    shift

    # Ensure that passed-in base directory is the repository root.
    if [[ ! -d $MOD_DIRECTORY_PATH/.git ]]; then
        error "Passed-in path does not point to base directory of the mod (must contain the .git sub-directory)."
        exit "$ERROR_ARGUMENTS"
    fi

    if ! command_abort_release "$MOD_DIRECTORY_PATH"; then
        exit "$ERROR_GENERAL"
    fi

else

    error "Unsupported command: $COMMAND"
    exit "$ERROR_ARGUMENTS"

fi
