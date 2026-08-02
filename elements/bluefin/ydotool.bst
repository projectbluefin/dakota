# ydotool provides input injection for Wayland sessions through /dev/uinput.
# Keep the daemon unit disabled by default; users opt in with systemctl --user.
kind: cmake

sources:
- kind: git_repo
  url: github:ReimuNotMoe/ydotool.git
  track: v1.0.4
  ref: v1.0.4-0-g57ba7d0af525e82da2de0e275d169477f293b197

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-cmake.bst
- freedesktop-sdk.bst:components/scdoc.bst
- freedesktop-sdk.bst:components/systemd.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  cmake-local: >-
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5
    -DCMAKE_INSTALL_MANDIR=%{mandir}

config:
  install-commands:
    (>):
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/udev/rules.d/80-ydotool.rules"
      cat > "%{install-root}%{indep-libdir}/udev/rules.d/80-ydotool.rules" <<'EOF'
      KERNEL=="uinput", GROUP="input", MODE="0660", TAG+="uaccess", OPTIONS+="static_node=uinput"
      EOF
    - |
      install -Dm644 /dev/null "%{install-root}%{indep-libdir}/modules-load.d/ydotool.conf"
      printf '%s\n' uinput > "%{install-root}%{indep-libdir}/modules-load.d/ydotool.conf"
    - |
      install -d "%{install-root}%{indep-libdir}/systemd/user"
      ln -s ydotool.service "%{install-root}%{indep-libdir}/systemd/user/ydotoold.service"
