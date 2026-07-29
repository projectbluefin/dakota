# Native vkBasalt post-processing Vulkan layer.
#
# Complements MangoHud/GOverlay: users can enable CAS/FXAA/SMAA/colour LUTs
# for native host workloads and non-Flatpak games. Flatpak games still normally
# use Flathub's runtime extension, but having the host layer mirrors Bazzite's
# out-of-box gaming toolbox.
kind: meson

sources:
- kind: tar
  url: github-releases:DadSchoorse/vkBasalt/releases/download/v0.3.2.10/vkBasalt-0.3.2.10.tar.gz
  ref: eb196ff446fa36ec0ca99c4406d753c1fa210afddeec5e7a76e1c2e74ed605e3

build-depends:
- freedesktop-sdk.bst:public-stacks/buildsystem-meson.bst
- freedesktop-sdk.bst:components/glslang.bst
- freedesktop-sdk.bst:components/vulkan-headers.bst
- freedesktop-sdk.bst:components/spirv-headers.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/vulkan-icd-loader.bst
- freedesktop-sdk.bst:components/xorg-lib-x11.bst

variables:
  meson-local: >-
    -Dappend_libdir_vkbasalt=true
