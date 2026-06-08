# Vendored updates panel for downstream gnome-control-center builds.
# Drop this directory into panels/ inside a gnome-control-center checkout
# and add `subdir('updates')` to panels/meson.build. See ../README.md.

panel_name = 'updates'

i18n.merge_file(
        type: 'desktop',
       input: 'gnome-@0@-panel.desktop.in'.format(panel_name),
      output: 'gnome-@0@-panel.desktop'.format(panel_name),
  po_dir: po_dir,
     install: true,
  install_dir: control_center_desktopdir,
)

resource_files = files('updates.gresource.xml')
sources = files(
  'cc-updates-panel.c',
)

resources = gnome.compile_resources(
  'cc-' + panel_name + '-resources',
  resource_files,
  c_name: 'cc_' + panel_name,
  export: true,
  dependencies: files('cc-updates-panel.ui'),
)

# libfinupdate — the Rust backend cdylib. Pulled in via pkg-config so the
# downstream build can point at whichever build directory contains it
# (e.g. PKG_CONFIG_PATH=$FINUPDATE_REPO/target/release/pkgconfig meson …).
libfinupdate_dep = dependency('libfinupdate', version: '>= 0.1')

sources += resources

panels_libs += static_library(
  'updates-properties',
  sources: sources,
  include_directories: [ top_inc, common_inc ],
  dependencies: [
    common_deps,
    libfinupdate_dep,
  ],
  c_args: cflags,
)
