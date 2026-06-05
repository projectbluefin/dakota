import toml
import sys

def generate_sources(cargo_lock_path):
    with open(cargo_lock_path, 'r') as f:
        data = toml.load(f)

    print("sources:")
    # Add the local source first
    print("- kind: local")
    print("  path: files/uutils-coreutils")

    # Add cargo2 source definition
    print("- kind: cargo2")
    print("  build-args:")
    print("    - --release")
    print("    - --no-default-features")
    print("    - --features")
    print("    - feat_os_unix")
    print("  ref:")

    for package in data.get('package', []):
        source = package.get('source', '')
        if 'registry+https://github.com/rust-lang/crates.io-index' in source:
            name = package['name']
            version = package['version']
            checksum = package.get('checksum')

            if checksum:
                print(f"  - kind: registry")
                print(f"    name: {name}")
                print(f"    version: {version}")
                print(f"    sha: {checksum}")
        elif 'git+' in source:
             # Handle git dependencies if any
            pass

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python3 generate_bst.py <path_to_Cargo.lock>")
        sys.exit(1)

    generate_sources(sys.argv[1])
