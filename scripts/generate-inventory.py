#!/usr/bin/env python3
"""Generate an Ansible inventory from Terraform outputs."""

import argparse
import json
import subprocess
from pathlib import Path


def terraform_output(directory: Path) -> dict:
    """Return terraform output as a dictionary."""
    result = subprocess.run(
        ["terraform", "output", "-json"],
        cwd=directory,
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def build_inventory(outputs: dict, wave: str) -> dict:
    """Build inventory structure from terraform outputs."""
    inventory = {
        "all": {"children": {"source_servers": {}, "target_servers": {}, "bastion": {}}},
        "source_servers": {"hosts": {}},
        "target_servers": {"hosts": {}},
        "bastion": {"hosts": {}},
        "_meta": {"hostvars": {}},
    }

    # Bastion
    if "bastion_ip" in outputs:
        ip = outputs["bastion_ip"]["value"]
        inventory["bastion"]["hosts"]["bastion"] = {"ansible_host": ip}

    # Subnets or server addresses should be filled by users; we place placeholders using outputs
    for role in ("source", "target"):
        subnet_key = f"{role}_subnet"
        if subnet_key in outputs:
            inventory[f"{role}_servers"]["hosts"][f"{role}-placeholder"] = {
                "ansible_host": "REPLACE_WITH_IP",
                "wave": wave,
                "subnet_id": outputs[subnet_key]["value"],
            }

    return inventory


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate inventory from terraform output")
    parser.add_argument("directory", type=Path, help="Terraform working directory")
    parser.add_argument("--wave", default="wave1", help="Wave identifier")
    parser.add_argument(
        "--output", type=Path, default=Path("ansible/inventory/generated.json"),
        help="Path to save inventory JSON",
    )
    args = parser.parse_args()

    outputs = terraform_output(args.directory)
    inventory = build_inventory(outputs, args.wave)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(inventory, indent=2))
    print(f"Inventory written to {args.output}")


if __name__ == "__main__":
    main()
