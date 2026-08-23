oapi_codegen_version := "v2.8.0"
default_ch_version := `cat CH_VERSION`

# Regenerate the client against the given cloud-hypervisor tag (defaults to the pinned version in CH_VERSION).
generate ch_version=default_ch_version:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Fetching openapi.yaml for cloud-hypervisor {{ch_version}}"
    curl -sL --fail -o openapi.yaml \
        "https://raw.githubusercontent.com/cloud-hypervisor/cloud-hypervisor/{{ch_version}}/vmm/src/api/openapi/cloud-hypervisor.yaml"
    go run github.com/oapi-codegen/oapi-codegen/v2/cmd/oapi-codegen@{{oapi_codegen_version}} \
        -config oapi-codegen.yaml openapi.yaml
    echo "{{ch_version}}" > CH_VERSION
    ch_major=$(echo "{{ch_version}}" | sed -E 's/^v([0-9]+).*/\1/')
    # Keep README's version references (module tag v0.N.0 and raw cloud-hypervisor tag vN.M) in
    # sync. Module tag pattern (v0.*.0) is replaced first so it can't be re-matched by the second,
    # broader vN.M pattern.
    sed -i -E "s/v0\.[0-9]+\.0/v0.${ch_major}.0/g" README.md
    sed -i -E "s/v[1-9][0-9]*\.[0-9]+/{{ch_version}}/g" README.md
    gofmt -l . && go build ./...

# Print the cloud-hypervisor tag this client is currently generated from.
version:
    @cat CH_VERSION

# Check GitHub for cloud-hypervisor releases newer than `current` (defaults to the pinned
# CH_VERSION; override only for testing the check itself). Exits 0 and prints the newest tag if
# an update is available, exits 1 (no output) if already up to date.
check-update current=default_ch_version:
    #!/usr/bin/env bash
    set -euo pipefail
    response=$(curl -sL --fail https://api.github.com/repos/cloud-hypervisor/cloud-hypervisor/releases/latest)
    latest=$(echo "$response" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/')
    if [ -z "$latest" ]; then
        echo "could not determine latest cloud-hypervisor release" >&2
        exit 2
    fi
    if [ "$latest" != "{{current}}" ]; then
        echo "$latest"
    else
        exit 1
    fi
