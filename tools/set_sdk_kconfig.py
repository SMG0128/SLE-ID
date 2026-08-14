"""Set SDK Kconfig symbols without importing the curses menu UI."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

from kconfiglib import Kconfig


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sdk-source", required=True)
    parser.add_argument("--config", required=True)
    parser.add_argument("assignments", nargs="+")
    args = parser.parse_args()

    sdk_source = Path(args.sdk_source).resolve()
    config_path = Path(args.config).resolve()
    if not (sdk_source / "config.in").is_file():
        raise SystemExit(f"SDK config.in not found under {sdk_source}")
    if not config_path.is_file():
        raise SystemExit(f"Target config not found: {config_path}")

    os.environ["KCONFIG_CONFIG"] = str(config_path)
    os.environ["CONFIG_"] = "CONFIG_"
    original_cwd = Path.cwd()
    try:
        os.chdir(sdk_source)
        kconf = Kconfig(filename="config.in")
        kconf.load_config(str(config_path))
        for assignment in args.assignments:
            if "=" not in assignment:
                raise SystemExit(f"Invalid assignment: {assignment}")
            name, value = assignment.split("=", 1)
            symbol = kconf.syms.get(name)
            if symbol is None:
                raise SystemExit(f"Unknown Kconfig symbol: {name}")
            if not symbol.set_value(value):
                raise SystemExit(f"Invalid value for {name}: {value}")
        kconf.write_config(str(config_path))
    finally:
        os.chdir(original_cwd)


if __name__ == "__main__":
    main()
