# go-cloud-hypervisor-client

A Go client for [cloud-hypervisor](https://github.com/cloud-hypervisor/cloud-hypervisor)'s HTTP
API: the full surface of its [OpenAPI 3.0 spec](https://github.com/cloud-hypervisor/cloud-hypervisor/blob/main/vmm/src/api/openapi/cloud-hypervisor.yaml),
generated with [oapi-codegen](https://github.com/oapi-codegen/oapi-codegen).

- Depends only on the Go standard library at runtime. No third-party HTTP library pulled into
  your build.
- Takes an injectable `http.Client`. This matters because cloud-hypervisor serves its API over a
  Unix domain socket, not TCP, so you'll want a client with a custom `DialContext`.

## Install

```sh
go get github.com/the127/go-cloud-hypervisor-client
```

This module's MINOR version tracks cloud-hypervisor's release number: `v0.53.1` is generated from
cloud-hypervisor `v53.0`. Pin to a specific cloud-hypervisor version with:

```sh
go get github.com/the127/go-cloud-hypervisor-client@v0.53.1
```

<!-- pinned-tag-notice:start -->
> **Note:** don't use `v0.53.0`. It was cached by the Go module proxy with stale content from
> before this repo's git history was rewritten during initial setup, so `go get ...@v0.53.0` can
> resolve to code that doesn't match `CH_VERSION` or what's on `main`. `v0.53.1` points at the
> same, correct `v53.0`-generated content under a tag the proxy hadn't already cached. This note
> is intentionally excluded from the version auto-sync in `justfile` and stays as-is.
<!-- pinned-tag-notice:end -->

## Usage

Point an `http.Client` at cloud-hypervisor's Unix socket and pass it to the generated client:

```go
package main

import (
	"context"
	"log"
	"net"
	"net/http"

	client "github.com/the127/go-cloud-hypervisor-client"
)

func main() {
	socketPath := "/run/cloud-hypervisor.sock"

	httpClient := &http.Client{
		Transport: &http.Transport{
			DialContext: func(ctx context.Context, _, _ string) (net.Conn, error) {
				var d net.Dialer
				return d.DialContext(ctx, "unix", socketPath)
			},
		},
	}

	// The host/path is a placeholder required by net/http's URL parsing. The actual
	// connection goes over the Unix socket via DialContext above.
	c, err := client.NewClientWithResponses("http://localhost/api/v1", client.WithHTTPClient(httpClient))
	if err != nil {
		log.Fatal(err)
	}

	resp, err := c.GetVmmPingWithResponse(context.Background())
	if err != nil {
		log.Fatal(err)
	}
	if resp.JSON200 == nil {
		log.Fatalf("ping failed: %s", resp.Status())
	}
	log.Printf("cloud-hypervisor version: %s", resp.JSON200.Version)
}
```

### Two client flavors

- `NewClientWithResponses` returns a `*ClientWithResponses`. Each call gives you back a typed
  result struct with a `JSON200`/`JSONDefault`/etc. field already unmarshalled for you. This is
  what you want in most cases (used above).
- `NewClient` returns a `*Client`. Each call gives you the raw `*http.Response`, and you decode
  the body yourself. Useful if you need streaming access or don't want the response buffered or
  parsed.

### Finding an operation

Every path in cloud-hypervisor's API (VM creation, boot, snapshot/restore, device hotplug,
migration, etc.) has a corresponding method on the client, named after the OpenAPI `operationId`,
e.g. `CreateVMWithResponse`, `BootVMWithResponse`, `PutVmAddDeviceWithResponse`,
`PutVmSnapshotWithResponse`. Browse them on
[pkg.go.dev](https://pkg.go.dev/github.com/the127/go-cloud-hypervisor-client) or grep
`client.gen.go` for `WithResponse` to see the full list, and cross-reference cloud-hypervisor's
[API docs](https://github.com/cloud-hypervisor/cloud-hypervisor/blob/main/docs/api.md) for request
and response semantics. This client only generates the transport, not documentation beyond what's
in the spec.

## Compatibility

This client is generated against a specific cloud-hypervisor release, currently
[`v53.0`](https://github.com/cloud-hypervisor/cloud-hypervisor/releases/tag/v53.0) (see
[`CH_VERSION`](./CH_VERSION)). This module stays on major version 0 (Go requires a `/vN` import
path suffix for major versions 2+, which isn't practical for a client that tracks a fast-moving
upstream release-by-release), so cloud-hypervisor's release number is encoded in the MINOR version
instead: `go get module@vX.Y` gives you the client matching cloud-hypervisor `vX.Y`. It should
also work against nearby cloud-hypervisor versions whose HTTP API hasn't changed incompatibly;
check the target version's release notes if you hit unexpected errors.

## License

Apache 2.0. See [LICENSE](./LICENSE). The upstream OpenAPI spec is also Apache 2.0 licensed by the
cloud-hypervisor project.

---

## Development

The generated client is committed to the repo, not built at consumers' `go get` time.

To regenerate it against the currently pinned cloud-hypervisor version:

```sh
just generate
```

To bump to a different cloud-hypervisor tag:

```sh
just generate <tag>   # <tag> is any cloud-hypervisor release tag
```

This re-fetches `openapi.yaml` at that tag, regenerates `client.gen.go`, updates `CH_VERSION`, and
rewrites the version references above in this README to match.

[`.github/workflows/bump-cloud-hypervisor.yml`](./.github/workflows/bump-cloud-hypervisor.yml) runs
daily, checks cloud-hypervisor's GitHub releases for a tag newer than `CH_VERSION`, and if found
opens a PR that bumps the pin and regenerates the client. Review the diff and cloud-hypervisor's
release notes for breaking API changes before merging.

Once such a PR is merged, [`.github/workflows/tag-release.yml`](./.github/workflows/tag-release.yml)
tags the merge commit `v0.<CH minor>.0`, keeping this module's tags in lockstep with
cloud-hypervisor's own release numbers.
