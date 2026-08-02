#!/bin/sh

set -eu

repository_path="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}"
config_path="$repository_path/NeutralNews/Config.xcconfig"

if [ -z "${REVENUECAT_API_KEY:-}" ]; then
    echo "REVENUECAT_API_KEY is missing from the Xcode Cloud environment." >&2
    exit 1
fi

cat > "$config_path" <<EOF
#include "SharedBuildSettings.xcconfig"

REVENUECAT_API_KEY = ${REVENUECAT_API_KEY}
EOF
