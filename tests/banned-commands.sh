#!/usr/bin/env bash

PLUGIN_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."

# shellcheck disable=SC2329 # export -f makes it reachable by find
check_file() {
    ## Taken from https://github.com/asdf-vm/asdf/blob/master/test/banned_commands.bats
    banned_commands=(
        # Process substitution isn't POSIX compliant and cause trouble
        "<("
        # Command isn't included in the Ubuntu packages asdf depends on. Also not
        # defined in POSIX
        column
        # echo isn't consistent across operating systems, and sometimes output can
        # be confused with echo flags. printf does everything echo does and more.
        echo
        # It's best to avoid eval as it makes it easier to accidentally execute
        # arbitrary strings
        eval
        # realpath not available by default on OSX.
        realpath
        # source isn't POSIX compliant. . behaves the same and is POSIX compliant
        # Except in fish, where . is deprecated, and will be removed in the future.
        source
        # For consistency, [ should be used instead. There is a leading space so 'fail_test', etc. is not matched
        ' test'
        # OSX != Unix
        "sed.* -i"
    )
    banned_commands_regex=(
        # grep -y does not work on alpine and should be "grep -i" either way
        "grep.* -y"
        # grep -P is not a valid option in OSX.
        "grep.* -P"
        # Ban grep long commands as they do not work on alpine
        "grep[^|]+--\w{2,}"
        # readlink -f on OSX behaves differently from readlink -f on other Unix systems
        'readlink.+-.*f.+["$]'
        # sort --sort-version isn't supported everywhere
        "sort.*-V"
        "sort.*--sort-versions"

        # ls often gets used when we want to glob for files that match a pattern
        # or when we want to find all files/directories that match a pattern or are
        # found in a certain location. Using shell globs is preferred over ls, and
        # find is better at locating files that are in a certain location or that
        # match certain filename patterns.
        # https://github-wiki-see.page/m/koalaman/shellcheck/wiki/SC2012
        '\bls '

        # Ban recursive asdf calls as they are inefficient and may introduce bugs.
        # If you find yourself needing to invoke an `asdf` command from within
        # asdf code, please source the appropriate file and invoke the
        # corresponding function.
        '\basdf '
    )

    local file="$1"
    local file_name="${file##*/../}"
    # Read file content and strip comments
    local file_content
    file_content=$(grep -v '^[[:space:]]*#' "$file")

    for cmd in "${banned_commands[@]}"; do
        if echo "$file_content" | grep -nHq "$cmd"; then
            echo "File '$file_name' contains banned command: $cmd"
            return 1
        fi
    done

    for regex in "${banned_commands_regex[@]}"; do
        if echo "$file_content" | grep -nHqE "$regex"; then
            echo "File '$file_name' contains banned pattern: $regex"
            return 1
        fi
    done

    return 0
}
export -f check_file

# Use find and store results
exit_status=0
while IFS= read -r -d '' file; do
    if ! bash -c "check_file \"$file\""; then
        exit_status=1
    fi
done < <(find "$PLUGIN_DIR/lib" "$PLUGIN_DIR/bin" -type f -print0)

if [[ $exit_status -eq 1 ]]; then
    echo "Illegal commands or patterns found. Exiting."
    exit 1
fi

echo "No illegal commands or patterns found."
exit 0
