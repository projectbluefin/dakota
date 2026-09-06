# Icon fallback for common's fastfetch config, without replacing the text font.
# Architecture-independent upstream font data; keep sources on one release.
kind: manual

sources:
- kind: tar
  url: github_files:ryanoasis/nerd-fonts/releases/download/v3.5.1/NerdFontsSymbolsOnly.tar.xz
  ref: 01172f37db8543edb102e5cb5c64101c9f4686630804d49b419aa07b23a69996
  base-dir: ""
- kind: remote
  url: github-raw:ryanoasis/nerd-fonts/v3.5.1/10-nerd-font-symbols.conf
  ref: 883f3ea0ca0874c567d9414be319de7a54d64f4a30aaa87f2ad4066da1687c07
- kind: remote
  url: github-raw:ryanoasis/nerd-fonts/v3.5.1/LICENSE
  filename: LICENSE-NERD-FONTS
  ref: 1f6ad4edae6479aaace3112ede5279a23284ae54b2a34db66357aef5f64df160
- kind: remote
  url: github-raw:ryanoasis/nerd-fonts/v3.5.1/license-audit.md
  filename: LICENSE-AUDIT.md
  ref: c2a3f634fa1e5001912f4f19a42fa86fdef5654691b70000f936089325aa404f

build-depends:
- core/sandbox-tools.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

# Supplies the integration command that refreshes the composed font cache.
runtime-depends:
- freedesktop-sdk.bst:components/fontconfig.bst

variables:
  strip-binaries: ""
  # Preserve icon attribution as well as the license and multi-license inventory.
  license-files-extra: "README.md"

config:
  install-commands:
  - install -Dm644 -t "%{install-root}%{datadir}/fonts/nerd-fonts" SymbolsNerdFont-Regular.ttf SymbolsNerdFontMono-Regular.ttf
  - install -Dm644 10-nerd-font-symbols.conf "%{install-root}%{datadir}/fontconfig/conf.avail/10-nerd-font-symbols.conf"
  - mkdir -p "%{install-root}%{sysconfdir}/fonts/conf.d"
  - ln -s ../../../usr/share/fontconfig/conf.avail/10-nerd-font-symbols.conf "%{install-root}%{sysconfdir}/fonts/conf.d/10-nerd-font-symbols.conf"
  - "%{install-extra}"
