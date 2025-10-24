#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <terraform-directory>" >&2
  exit 1
fi

dir="$1"

if [[ ! -d "$dir" ]]; then
  echo "Directory $dir not found" >&2
  exit 1
fi

echo "Initializing Terraform in $dir" >&2
terraform -chdir="$dir" init -backend=false >/dev/null
terraform -chdir="$dir" validate
