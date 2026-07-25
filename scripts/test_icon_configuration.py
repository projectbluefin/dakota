#!/usr/bin/env python3
"""
Test icon configuration and custom command menu logo settings.
Verifies that:
1. dconf/05-dakota-custom-command-menu configures menuicon-setting='ublue-logo-symbolic'
2. elements/bluefin/common.bst copies ublue-logo-symbolic.svg across icon categories (status, apps)
   and updates the hicolor icon cache.
"""
from pathlib import Path
import sys

def main():
    errors = []
    
    # 1. Check dconf custom command menu keyfile
    dconf_path = Path("files/dconf/05-dakota-custom-command-menu")
    if not dconf_path.exists():
        errors.append("missing files/dconf/05-dakota-custom-command-menu")
    else:
        content = dconf_path.read_text()
        if "menuicon-setting='ublue-logo-symbolic'" not in content:
            errors.append("files/dconf/05-dakota-custom-command-menu must set menuicon-setting='ublue-logo-symbolic'")

    # 2. Check common.bst element
    common_path = Path("elements/bluefin/common.bst")
    if not common_path.exists():
        errors.append("missing elements/bluefin/common.bst")
    else:
        content = common_path.read_text()
        if "ublue-logo-symbolic.svg" not in content:
            errors.append("elements/bluefin/common.bst must manage ublue-logo-symbolic.svg")
        if "gtk-update-icon-cache" not in content and "gtk4-update-icon-cache" not in content:
            errors.append("elements/bluefin/common.bst must update hicolor icon cache")

    if errors:
        for err in errors:
            print(f"FAIL: {err}", file=sys.stderr)
        sys.exit(1)

    print("PASS: custom command menu icon configuration looks sane")

if __name__ == "__main__":
    main()
