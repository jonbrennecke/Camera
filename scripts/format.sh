#!/usr/bin/env zsh
set -x

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
project_dir=$(cd "$dir/" 2> /dev/null && pwd -P)

# run clang-format to format Objective C files
format=$(brew --prefix llvm)/bin/clang-format
$format -i $project_dir/Source/**/*.h $project_dir/ios/Source/**/*.m

# run swiftformat to format Swift files
swiftformat $project_dir --indent 2 --maxwidth 120

set +x
