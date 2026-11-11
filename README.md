# Cloud Clipboard

The Docker build compiles the application and uses a maintained Java 11 runtime. CI verifies the final OS and Java trust stores before publishing `ghcr.io/vtichy/cloud-clipboard` images. The temporary source-controlled root distrust policy is in `security/distrust-emudhra.sh`; remove it only after a replacement vendor runtime passes the same checks without it.

The Container workflow also exports `container-image` for deployment without giving a server a registry credential. Download it using `gh run download RUN_ID -n container-image`, copy `image.tar.gz` to the server, and load it with `docker load -i image.tar.gz`. Select the immutable commit tag in the base Compose file. Do not use host-local certificate-patched image overrides.
