kind: manual

build-depends:
- freedesktop-sdk.bst:components/rust.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
# Provides the /dev/uinput udev rule (group input, 0660) and loads the
# uinput module at boot; kanata.service needs both to create its virtual
# keyboard.
- bluefin/ydotool.bst

config:
  build-commands:
  - cargo build --release --frozen --offline --bin kanata

  # kanata.service is opt-in. Dakota's presets have no catch-all `disable *`,
  # so a unit with an [Install] section is enabled unless a preset disables
  # it; 80-kanata.preset does that. ConditionPathExists keeps the unit a
  # silent no-op when it is enabled before a config exists, instead of a
  # restart loop. It runs as a transient DynamicUser with only the input group, so
  # keyboards are readable by the remapper and not by every process in the
  # user's session. Users write /etc/kanata/kanata.kbd and opt in with:
  # sudo systemctl enable --now kanata
  install-commands:
  - install -Dm755 target/release/kanata "%{install-root}%{bindir}/kanata"
  - install -Dm644 LICENSE "%{install-root}%{datadir}/licenses/kanata/LICENSE"
  - install -Dm644 README.md "%{install-root}%{datadir}/doc/kanata/README.md"
  - install -Dm644 docs/config.adoc "%{install-root}%{datadir}/doc/kanata/config.adoc"
  - install -Dm644 cfg_samples/minimal.kbd "%{install-root}%{datadir}/doc/kanata/examples/minimal.kbd"
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system/kanata.service"
    cat > "%{install-root}%{indep-libdir}/systemd/system/kanata.service" <<'EOF'
    [Unit]
    Description=Kanata keyboard remapper
    Documentation=file:///usr/share/doc/kanata/config.adoc
    ConditionPathExists=/etc/kanata/kanata.kbd

    [Service]
    ExecStart=/usr/bin/kanata --cfg /etc/kanata/kanata.kbd
    DynamicUser=yes
    SupplementaryGroups=input
    DevicePolicy=closed
    DeviceAllow=char-input rw
    DeviceAllow=/dev/uinput rw
    PrivateNetwork=yes
    ProtectHome=yes
    Restart=on-failure
    RestartSec=2

    [Install]
    WantedBy=multi-user.target
    EOF
  - |
    install -Dm644 /dev/null "%{install-root}%{indep-libdir}/systemd/system-preset/80-kanata.preset"
    cat > "%{install-root}%{indep-libdir}/systemd/system-preset/80-kanata.preset" <<'EOF'
    disable kanata.service
    EOF
  - '%{install-extra}'

sources:
- kind: git_repo
  url: github:jtroo/kanata.git
  track: 'v[0-9]*.[0-9]*.[0-9]*'
  ref: v1.12.0-0-g02242ef761ef43b860eac30067ce86904be7d466
- kind: cargo2
  url: crates:crates
  ref:
  - kind: registry
    name: addr2line
    version: 0.24.2
    sha: dfbe277e56a376000877090da837660b4427aad530e3028d44e0bffe4f89a1c1
  - kind: registry
    name: adler2
    version: 2.0.0
    sha: 512761e0bb2578dd7380c6baaa0f4ce03e84f95e960231d1dec8bf4d7d6e2627
  - kind: registry
    name: aho-corasick
    version: 1.1.3
    sha: 8e60d3430d3a69478ad0993f19238d2df97c507009a52b3c10addcd7f6bcb916
  - kind: registry
    name: anstream
    version: 0.6.17
    sha: 23a1e53f0f5d86382dafe1cf314783b2044280f406e7e1506368220ad11b1338
  - kind: registry
    name: anstyle
    version: 1.0.9
    sha: 8365de52b16c035ff4fcafe0092ba9390540e3e352870ac09933bebcaa2c8c56
  - kind: registry
    name: anstyle-parse
    version: 0.2.6
    sha: 3b2d16507662817a6a20a9ea92df6652ee4f94f914589377d69f3b21bc5798a9
  - kind: registry
    name: anstyle-query
    version: 1.1.2
    sha: 79947af37f4177cfead1110013d678905c37501914fba0efea834c3fe9a8d60c
  - kind: registry
    name: anstyle-wincon
    version: 3.0.6
    sha: 2109dbce0e72be3ec00bed26e6a7479ca384ad226efdd66db8fa2e3a38c83125
  - kind: registry
    name: anyhow
    version: 1.0.91
    sha: c042108f3ed77fd83760a5fd79b53be043192bb3b9dba91d8c574c0ada7850c8
  - kind: registry
    name: arboard
    version: 3.4.1
    sha: df099ccb16cd014ff054ac1bf392c67feeef57164b05c42f037cd40f5d4357f4
  - kind: registry
    name: arraydeque
    version: 0.5.1
    sha: 7d902e3d592a523def97af8f317b08ce16b7ab854c1985a0c671e6f15cebc236
  - kind: registry
    name: atomic-polyfill
    version: 1.0.3
    sha: 8cf2bce30dfe09ef0bfaef228b9d414faaf7e563035494d7fe092dba54b300f4
  - kind: registry
    name: autocfg
    version: 1.4.0
    sha: ace50bade8e6234aa140d9a2f552bbee1db4d353f69b8217bc503490fc1a9f26
  - kind: registry
    name: backtrace
    version: 0.3.74
    sha: 8d82cb332cdfaed17ae235a638438ac4d4839913cc2af585c3c6746e8f8bee1a
  - kind: registry
    name: backtrace-ext
    version: 0.2.1
    sha: 537beee3be4a18fb023b570f80e3ae28003db9167a751266b259926e25539d50
  - kind: registry
    name: bitflags
    version: 1.3.2
    sha: bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a
  - kind: registry
    name: bitflags
    version: 2.9.1
    sha: 1b8e56985ec62d17e9c1001dc89c88ecd7dc08e47eba5ec7c29c7b5eeecde967
  - kind: registry
    name: bitvec
    version: 1.0.1
    sha: 1bc2832c24239b0141d5674bb9174f9d68a8b5b3f2753311927c172ca46f7e9c
  - kind: registry
    name: block2
    version: 0.5.1
    sha: 2c132eebf10f5cad5289222520a4a058514204aed6d791f1cf4fe8088b82d15f
  - kind: registry
    name: bumpalo
    version: 3.19.0
    sha: 46c5e41b57b8bba42a04676d81cb89e9ee8e859a1a66f80a5a72e1cb76b34d43
  - kind: registry
    name: bytemuck
    version: 1.19.0
    sha: 8334215b81e418a0a7bdb8ef0849474f40bb10c8b71f1c4ed315cff49f32494d
  - kind: registry
    name: byteorder
    version: 1.5.0
    sha: 1fd0f2584146f6f2ef48085050886acf353beff7305ebd1ae69500e27c67f64b
  - kind: registry
    name: byteorder-lite
    version: 0.1.0
    sha: 8f1fe948ff07f4bd06c30984e69f5b4899c516a3ef74f34df92a2df2ab535495
  - kind: registry
    name: cc
    version: 1.1.31
    sha: c2e7962b54006dcfcc61cb72735f4d89bb97061dd6a7ed882ec6b8ee53714c6f
  - kind: registry
    name: cfg-if
    version: 1.0.0
    sha: baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd
  - kind: registry
    name: cfg_aliases
    version: 0.2.1
    sha: 613afe47fcd5fac7ccf1db93babcb082c5994d996f20b8b159f2ad1658eb5724
  - kind: registry
    name: clap
    version: 4.5.20
    sha: b97f376d85a664d5837dbae44bf546e6477a679ff6610010f17276f686d867e8
  - kind: registry
    name: clap_builder
    version: 4.5.20
    sha: 19bc80abd44e4bed93ca373a0704ccbd1b710dc5749406201bb018272808dc54
  - kind: registry
    name: clap_derive
    version: 4.5.18
    sha: 4ac6a0c7b1a9e9a5186361f67dfa1b88213572f427fb9ab038efb2bd8c582dab
  - kind: registry
    name: clap_lex
    version: 0.7.2
    sha: 1462739cb27611015575c0c11df5df7601141071f07518d56fcc1be504cbec97
  - kind: registry
    name: clipboard-win
    version: 5.4.0
    sha: 15efe7a882b08f34e38556b14f2fb3daa98769d06c7f0c1b076dfd0d983bc892
  - kind: registry
    name: colorchoice
    version: 1.0.3
    sha: 5b63caa9aa9397e2d9480a9b13673856c78d8ac123288526c37d7839f2a86990
  - kind: registry
    name: console_error_panic_hook
    version: 0.1.7
    sha: a06aeb73f470f66dcdbf7223caeebb85984942f22f1adb2a088cf9668146bbbc
  - kind: registry
    name: core-foundation
    version: 0.9.4
    sha: 91e195e091a93c46f7102ec7818a2aa394e1e1771c3ab4825963fa03e45afb8f
  - kind: registry
    name: core-foundation
    version: 0.10.1
    sha: b2a6cd9ae233e7f62ba4e9353e81a88df7fc8a5987b8d445b4d90c879bd156f6
  - kind: registry
    name: core-foundation-sys
    version: 0.8.7
    sha: 773648b94d0e5d620f64f280777445740e61fe701025087ec8b57f45c791888b
  - kind: registry
    name: core-graphics
    version: 0.23.2
    sha: c07782be35f9e1140080c6b96f0d44b739e2278479f64e02fdab4e32dfd8b081
  - kind: registry
    name: core-graphics
    version: 0.24.0
    sha: fa95a34622365fa5bbf40b20b75dba8dfa8c94c734aea8ac9a5ca38af14316f1
  - kind: registry
    name: core-graphics-types
    version: 0.1.3
    sha: 45390e6114f68f718cc7a830514a96f903cccd70d02a8f6d9f643ac4ba45afaf
  - kind: registry
    name: core-graphics-types
    version: 0.2.0
    sha: 3d44a101f213f6c4cdc1853d4b78aef6db6bdfa3468798cc1d9912f4735013eb
  - kind: registry
    name: crc32fast
    version: 1.4.2
    sha: a97769d94ddab943e4510d138150169a2758b5ef3eb191a9ee688de3e23ef7b3
  - kind: registry
    name: critical-section
    version: 1.2.0
    sha: 790eea4361631c5e7d22598ecd5723ff611904e3344ce8720784c93e3d83d40b
  - kind: registry
    name: deranged
    version: 0.5.5
    sha: ececcb659e7ba858fb4f10388c250a7252eb0a27373f1a72b8748afdd248e587
  - kind: registry
    name: dirs
    version: 5.0.1
    sha: 44c45a9d03d6676652bcb5e724c7e988de1acad23a711b5217ab9cbecbec2225
  - kind: registry
    name: dirs-sys
    version: 0.4.1
    sha: 520f05a5cbd335fae5a99ff7a6ab8627577660ee5cfd6a94a6a929b52ff0321c
  - kind: registry
    name: embed-resource
    version: 2.5.0
    sha: f4e24052d7be71f0efb50c201557f6fe7d237cfd5a64fd5bcd7fd8fe32dbbffa
  - kind: registry
    name: encode_unicode
    version: 0.3.6
    sha: a357d28ed41a50f9c765dbfe56cbc04a64e53e5fc58ba79fbc34c10ef3df831f
  - kind: registry
    name: endian-type
    version: 0.1.2
    sha: c34f04666d835ff5d62e058c3995147c06f42fe86ff053337632bca83e42702d
  - kind: registry
    name: equivalent
    version: 1.0.1
    sha: 5443807d6dff69373d433ab9ef5378ad8df50ca6298caf15de6e52e24aaf54d5
  - kind: registry
    name: errno
    version: 0.3.10
    sha: 33d852cb9b869c2a9b3df2f71a3074817f01e1844f839a144f5fcef059a4eb5d
  - kind: registry
    name: error-code
    version: 3.3.1
    sha: a5d9305ccc6942a704f4335694ecd3de2ea531b114ac2d51f5f843750787a92f
  - kind: registry
    name: evdev
    version: 0.13.1
    sha: a3c10865aeab1a7399b3c2d6046e8dcc7f5227b656f235ed63ef5ee45a47b8f8
  - kind: registry
    name: fdeflate
    version: 0.3.7
    sha: 1e6853b52649d4ac5c0bd02320cddc5ba956bdb407c4b75a2c6b75bf51500f8c
  - kind: registry
    name: flate2
    version: 1.0.35
    sha: c936bfdafb507ebbf50b8074c54fa31c5be9a1e7e5f467dd659697041407d07c
  - kind: registry
    name: foreign-types
    version: 0.5.0
    sha: d737d9aa519fb7b749cbc3b962edcf310a8dd1f4b67c91c4f83975dbdd17d965
  - kind: registry
    name: foreign-types-macros
    version: 0.2.3
    sha: 1a5c6c585bc94aaf2c7b51dd4c2ba22680844aba4c687be581871a6f518c5742
  - kind: registry
    name: foreign-types-shared
    version: 0.3.1
    sha: aa9a19cbb55df58761df49b23516a86d432839add4af60fc256da840f66ed35b
  - kind: registry
    name: funty
    version: 2.0.0
    sha: e6d5a32815ae3f33302d95fdcb2ce17862f8c65363dcfd29360480ba1001fc9c
  - kind: registry
    name: gethostname
    version: 0.4.3
    sha: 0176e0459c2e4a1fe232f984bca6890e681076abb9934f6cea7c326f3fc47818
  - kind: registry
    name: getrandom
    version: 0.2.15
    sha: c4567c8db10ae91089c99af84c68c38da3ec2f087c3f82960bcdbf3656b6f4d7
  - kind: registry
    name: gimli
    version: 0.31.1
    sha: 07e28edb80900c19c28f1072f2e8aeca7fa06b23cd4169cefe1af5aa3260783f
  - kind: registry
    name: hash32
    version: 0.2.1
    sha: b0c35f58762feb77d74ebe43bdbc3210f09be9fe6742234d573bacc26ed92b67
  - kind: registry
    name: hashbrown
    version: 0.15.0
    sha: 1e087f84d4f86bf4b218b927129862374b72199ae7d8657835f1e89000eea4fb
  - kind: registry
    name: heapless
    version: 0.7.17
    sha: cdc6457c0eb62c71aac4bc17216026d8410337c4126773b9c5daba343f17964f
  - kind: registry
    name: heck
    version: 0.5.0
    sha: 2304e00983f87ffb38b55b444b5e3b60a884b5d30c0fca7d82fe33449bbe55ea
  - kind: registry
    name: hermit-abi
    version: 0.4.0
    sha: fbf6a919d6cf397374f7dfeeea91d974c7c0a7221d0d0f4f20d859d329e53fcc
  - kind: registry
    name: image
    version: 0.25.5
    sha: cd6f44aed642f18953a158afeb30206f4d50da59fbc66ecb53c66488de73563b
  - kind: registry
    name: indexmap
    version: 2.6.0
    sha: 707907fe3c25f5424cce2cb7e1cbcafee6bdbe735ca90ef77c29e84591e5b9da
  - kind: registry
    name: indoc
    version: 2.0.5
    sha: b248f5224d1d606005e02c97f5aa4e88eeb230488bcc03bc9ca4d7991399f2b5
  - kind: registry
    name: inotify
    version: 0.10.2
    sha: fdd168d97690d0b8c412d6b6c10360277f4d7ee495c5d0d5d5fe0854923255cc
  - kind: registry
    name: inotify-sys
    version: 0.1.5
    sha: e05c02b5e89bff3b946cedeca278abc628fe811e604f027c45a8aa3cf793d0eb
  - kind: registry
    name: interception-sys
    version: 0.1.3
    sha: abe875cf6439eb5d98f0fdbcc6128fdef4870c47e0f898735105ff77685dfcd1
  - kind: registry
    name: is-docker
    version: 0.2.0
    sha: 928bae27f42bc99b60d9ac7334e3a21d10ad8f1835a4e12ec3ec0464765ed1b3
  - kind: registry
    name: is-terminal
    version: 0.4.13
    sha: 261f68e344040fbd0edea105bef17c66edf46f984ddb1115b775ce31be948f4b
  - kind: registry
    name: is-wsl
    version: 0.4.0
    sha: 173609498df190136aa7dea1a91db051746d339e18476eed5ca40521f02d7aa5
  - kind: registry
    name: is_ci
    version: 1.2.0
    sha: 7655c9839580ee829dfacba1d1278c2b7883e50a277ff7541299489d6bdfdc45
  - kind: registry
    name: is_terminal_polyfill
    version: 1.70.1
    sha: 7943c866cc5cd64cbc25b2e01621d07fa8eb2a1a23160ee81ce38704e97b8ecf
  - kind: registry
    name: itoa
    version: 1.0.11
    sha: 49f1f14873335454500d59611f1cf4a4b0f786f9ac11f4312a78e4cf2566695b
  - kind: registry
    name: jobserver
    version: 0.1.32
    sha: 48d1dbcbbeb6a7fec7e059840aa538bd62aaccf972c7346c4d9d2059312853d0
  - kind: registry
    name: jpeg-decoder
    version: 0.3.1
    sha: f5d4a7da358eff58addd2877a45865158f0d78c911d43a5784ceb7bbf52833b0
  - kind: registry
    name: js-sys
    version: 0.3.77
    sha: 1cfaf33c695fc6e08064efbc1f72ec937429614f25eef83af942d0e227c3a28f
  - kind: registry
    name: kanata-interception
    version: 0.3.0
    sha: e2e57b9b964d19ac86906ea56e8a88001eb03c2b9cb96e4127225438750bb606
  - kind: registry
    name: kanata-keyberon-macros
    version: 0.2.0
    sha: 73f6f83f03390a5c13bbf68abea76a2b9527e197f5c00026805fd7af62a34752
  - kind: registry
    name: karabiner-driverkit
    version: 0.3.1
    sha: 97e4fc764f78a4a5cbf705c9502a51a0ba4931dbee25f4fbc59654059f6ca9e9
  - kind: registry
    name: lazy_static
    version: 1.5.0
    sha: bbd2bcb4c963f2ddae06a2efc7e9f3591312473c50c6685e1f298068316e66fe
  - kind: registry
    name: libc
    version: 0.2.161
    sha: 8e9489c2807c139ffd9c1794f4af0ebe86a828db53ecdc7fea2111d0fed085d1
  - kind: registry
    name: libredox
    version: 0.1.3
    sha: c0ff37bd590ca25063e35af745c343cb7a0271906fb7b37e4813e8f79f00268d
  - kind: registry
    name: linux-raw-sys
    version: 0.4.15
    sha: d26c52dbd32dccf2d10cac7725f8eae5296885fb5703b261f7d0a0739ec807ab
  - kind: registry
    name: lock_api
    version: 0.4.12
    sha: 07af8b9cdd281b7915f413fa73f29ebd5d55d0d3f0155584dade1ff18cea1b17
  - kind: registry
    name: log
    version: 0.4.22
    sha: a7a70ba024b9dc04c27ea2f0c0548feb474ec5c54bba33a7f72f873a39d07b24
  - kind: registry
    name: malloc_buf
    version: 0.0.6
    sha: 62bb907fe88d54d8d9ce32a3cceab4218ed2f6b7d35617cafe9adf84e43919cb
  - kind: registry
    name: memchr
    version: 2.7.4
    sha: 78ca9ab1a0babb1e7d5695e3530886289c18cf2f87ec19a575a0abdce112e3a3
  - kind: registry
    name: memoffset
    version: 0.7.1
    sha: 5de893c32cde5f383baa4c04c5d6dbdd735cfd4a794b0debdb2bb1b421da5ff4
  - kind: registry
    name: miette
    version: 5.10.0
    sha: 59bb584eaeeab6bd0226ccf3509a69d7936d148cf3d036ad350abe35e8c6856e
  - kind: registry
    name: miette-derive
    version: 5.10.0
    sha: 49e7bc1560b95a3c4a25d03de42fe76ca718ab92d1a22a55b9b4cf67b3ae635c
  - kind: registry
    name: miniz_oxide
    version: 0.8.0
    sha: e2d80299ef12ff69b16a84bb182e3b9df68b5a91574d3d4fa6e41b65deec4df1
  - kind: registry
    name: mio
    version: 0.8.11
    sha: a4a650543ca06a924e8b371db273b2756685faae30f8487da1b56505a8f78b0c
  - kind: registry
    name: muldiv
    version: 0.2.1
    sha: 0419348c027fa7be448d2ae7ea0e4e04c2334c31dc4e74ab29f00a2a7ca69204
  - kind: registry
    name: muldiv
    version: 1.0.1
    sha: 956787520e75e9bd233246045d19f42fb73242759cc57fba9611d940ae96d4b0
  - kind: registry
    name: native-windows-gui
    version: 1.0.13
    sha: 4f7003a669f68deb6b7c57d74fff4f8e533c44a3f0b297492440ef4ff5a28454
  - kind: registry
    name: nibble_vec
    version: 0.1.0
    sha: 77a5d83df9f36fe23f0c3648c6bbb8b0298bb5f1939c8f2704431371f4b84d43
  - kind: registry
    name: nix
    version: 0.26.4
    sha: 598beaf3cc6fdd9a5dfb1630c2800c7acd31df7aaf0f565796fba2b53ca1af1b
  - kind: registry
    name: nix
    version: 0.29.0
    sha: 71e2746dc3a24dd78b3cfcb7be93368c6de9963d30f43a6a73998a9cf4b17b46
  - kind: registry
    name: num-conv
    version: 0.2.0
    sha: cf97ec579c3c42f953ef76dbf8d55ac91fb219dde70e49aa4a6b7d74e9919050
  - kind: registry
    name: num-traits
    version: 0.2.19
    sha: 071dfc062690e90b734c0b2273ce72ad0ffa95f0c74596bc250dcfd960262841
  - kind: registry
    name: num_enum
    version: 0.6.1
    sha: 7a015b430d3c108a207fd776d2e2196aaf8b1cf8cf93253e3a097ff3085076a1
  - kind: registry
    name: num_enum_derive
    version: 0.6.1
    sha: 96667db765a921f7b295ffee8b60472b686a51d4f21c2ee4ffdb94c7013b65a6
  - kind: registry
    name: num_threads
    version: 0.1.7
    sha: 5c7398b9c8b70908f6371f47ed36737907c87c52af34c268fed0bf0ceb92ead9
  - kind: registry
    name: objc
    version: 0.2.7
    sha: 915b1b472bc21c53464d6c8461c9d3af805ba1ef837e1cac254428f4a77177b1
  - kind: registry
    name: objc-sys
    version: 0.3.5
    sha: cdb91bdd390c7ce1a8607f35f3ca7151b65afc0ff5ff3b34fa350f7d7c7e4310
  - kind: registry
    name: objc2
    version: 0.5.2
    sha: 46a785d4eeff09c14c487497c162e92766fbb3e4059a71840cecc03d9a50b804
  - kind: registry
    name: objc2-app-kit
    version: 0.2.2
    sha: e4e89ad9e3d7d297152b17d39ed92cd50ca8063a89a9fa569046d41568891eff
  - kind: registry
    name: objc2-core-data
    version: 0.2.2
    sha: 617fbf49e071c178c0b24c080767db52958f716d9eabdf0890523aeae54773ef
  - kind: registry
    name: objc2-core-image
    version: 0.2.2
    sha: 55260963a527c99f1819c4f8e3b47fe04f9650694ef348ffd2227e8196d34c80
  - kind: registry
    name: objc2-encode
    version: 4.1.0
    sha: ef25abbcd74fb2609453eb695bd2f860d389e457f67dc17cafc8b8cbc89d0c33
  - kind: registry
    name: objc2-foundation
    version: 0.2.2
    sha: 0ee638a5da3799329310ad4cfa62fbf045d5f56e3ef5ba4149e7452dcf89d5a8
  - kind: registry
    name: objc2-metal
    version: 0.2.2
    sha: dd0cba1276f6023976a406a14ffa85e1fdd19df6b0f737b063b95f6c8c7aadd6
  - kind: registry
    name: objc2-quartz-core
    version: 0.2.2
    sha: e42bee7bff906b14b167da2bac5efe6b6a07e6f7c0a21a7308d40c960242dc7a
  - kind: registry
    name: object
    version: 0.36.5
    sha: aedf0a2d09c573ed1d8d85b30c119153926a2b36dce0ab28322c09a117a4683e
  - kind: registry
    name: once_cell
    version: 1.20.2
    sha: 1261fe7e33c73b354eab43b1273a57c8f967d0391e80353e51f764ac02cf6775
  - kind: registry
    name: open
    version: 5.3.0
    sha: 61a877bf6abd716642a53ef1b89fb498923a4afca5c754f9050b4d081c05c4b3
  - kind: registry
    name: option-ext
    version: 0.2.0
    sha: 04744f49eae99ab78e0d5c0b603ab218f515ea8cfe5a456d7629ad883a3b6e7d
  - kind: registry
    name: ordered-float
    version: 5.1.0
    sha: 7f4779c6901a562440c3786d08192c6fbda7c1c2060edd10006b05ee35d10f2d
  - kind: registry
    name: os_info
    version: 3.8.2
    sha: ae99c7fa6dd38c7cafe1ec085e804f8f555a2f8659b0dbe03f1f9963a9b51092
  - kind: registry
    name: os_pipe
    version: 1.2.1
    sha: 5ffd2b0a5634335b135d5728d84c5e0fd726954b87111f7506a61c502280d982
  - kind: registry
    name: owo-colors
    version: 3.5.0
    sha: c1b04fb49957986fdce4d6ee7a65027d55d4b6d2265e5848bbb507b58ccfdb6f
  - kind: registry
    name: parking_lot
    version: 0.12.3
    sha: f1bf18183cf54e8d6059647fc3063646a1801cf30896933ec2311622cc4b9a27
  - kind: registry
    name: parking_lot_core
    version: 0.9.10
    sha: 1e401f977ab385c9e4e3ab30627d6f26d00e2c73eef317493c4ec6d468726cf8
  - kind: registry
    name: pathdiff
    version: 0.2.2
    sha: d61c5ce1153ab5b689d0c074c4e7fc613e942dfb7dd9eea5ab202d2ad91fe361
  - kind: registry
    name: patricia_tree
    version: 0.9.0
    sha: edb45b6331bbdbb54c9a29413703e892ab94f83a31e4a546c778495a91e7fbca
  - kind: registry
    name: pin-utils
    version: 0.1.0
    sha: 8b870d8c151b6f2fb93e84a13146138f05d02ed11c7e7c54f8826aaaf7c9f184
  - kind: registry
    name: png
    version: 0.17.16
    sha: 82151a2fc869e011c153adc57cf2789ccb8d9906ce52c0b39a6b5697749d7526
  - kind: registry
    name: powerfmt
    version: 0.2.0
    sha: 439ee305def115ba05938db6eb1644ff94165c5ab5e9420d1c1bcedbba909391
  - kind: registry
    name: proc-macro-crate
    version: 1.3.1
    sha: 7f4c021e1093a56626774e81216a4ce732a735e5bad4868a03f3ed65ca0c3919
  - kind: registry
    name: proc-macro2
    version: 1.0.89
    sha: f139b0662de085916d1fb67d2b4169d1addddda1919e696f3252b740b629986e
  - kind: registry
    name: quote
    version: 1.0.37
    sha: b5b9d34b8991d19d98081b46eacdd8eb58c6f2b201139f7c5f643cc155a633af
  - kind: registry
    name: radium
    version: 0.7.0
    sha: dc33ff2d4973d518d823d61aa239014831e521c75da58e3df4840d3f47749d09
  - kind: registry
    name: radix_trie
    version: 0.2.1
    sha: c069c179fcdc6a2fe24d8d18305cf085fdbd4f922c041943e203685d6a1c58fd
  - kind: registry
    name: redox_syscall
    version: 0.5.7
    sha: 9b6dfecf2c74bce2466cabf93f6664d6998a69eb21e39f4207930065b27b771f
  - kind: registry
    name: redox_users
    version: 0.4.6
    sha: ba009ff324d1fc1b900bd1fdb31564febe58a8ccc8a6fdbb93b543d33b13ca43
  - kind: registry
    name: regex
    version: 1.11.1
    sha: b544ef1b4eac5dc2db33ea63606ae9ffcfac26c1416a2806ae0bf5f56b201191
  - kind: registry
    name: regex-automata
    version: 0.4.8
    sha: 368758f23274712b504848e9d5a6f010445cc8b87a7cdb4d7cbee666c1288da3
  - kind: registry
    name: regex-syntax
    version: 0.8.5
    sha: 2b15c43186be67a4fd63bee50d0303afffcef381492ebe2c5d87f324e1b8815c
  - kind: registry
    name: rustc-demangle
    version: 0.1.24
    sha: 719b953e2095829ee67db738b3bfa9fa368c94900df327b3f07fe6e794d2fe1f
  - kind: registry
    name: rustc-hash
    version: 1.1.0
    sha: 08d43f7aa6b08d49f382cde6a7982047c3426db949b1424bc4b7ec9ae12c6ce2
  - kind: registry
    name: rustc_version
    version: 0.4.1
    sha: cfcb3a22ef46e85b45de6ee7e79d063319ebb6594faafcf1c225ea92ab6e9b92
  - kind: registry
    name: rustix
    version: 0.38.44
    sha: fdb5bc1ae2baa591800df16c9ca78619bf65c0488b41b96ccec5d11220d8c154
  - kind: registry
    name: rustversion
    version: 1.0.22
    sha: b39cdef0fa800fc44525c84ccb54a029961a8215f9619753635a9c0d2538d46d
  - kind: registry
    name: ryu
    version: 1.0.18
    sha: f3cb5ba0dc43242ce17de99c180e96db90b235b8a9fdc9543c96d2209116bd9f
  - kind: registry
    name: scopeguard
    version: 1.2.0
    sha: 94143f37725109f92c262ed2cf5e59bce7498c01bcc1502d7b9afe439a4e9f49
  - kind: registry
    name: sd-notify
    version: 0.4.3
    sha: 1be20c5f7f393ee700f8b2f28ea35812e4e212f40774b550cd2a93ea91684451
  - kind: registry
    name: semver
    version: 1.0.23
    sha: 61697e0a1c7e512e84a621326239844a24d8207b4669b41bc18b32ea5cbf988b
  - kind: registry
    name: serde
    version: 1.0.228
    sha: 9a8e94ea7f378bd32cbbd37198a4a91436180c5bb472411e48b5ec2e2124ae9e
  - kind: registry
    name: serde_core
    version: 1.0.228
    sha: 41d385c7d4ca58e59fc732af25c3983b67ac852c1a25000afe1175de458b67ad
  - kind: registry
    name: serde_derive
    version: 1.0.228
    sha: d540f220d3187173da220f885ab66608367b6574e925011a9353e4badda91d79
  - kind: registry
    name: serde_json
    version: 1.0.132
    sha: d726bfaff4b320266d395898905d0eba0345aae23b54aee3a737e260fd46db03
  - kind: registry
    name: serde_spanned
    version: 0.6.8
    sha: 87607cb1398ed59d48732e575a4c28a7a8ebf2454b964fe3f224f2afc07909e1
  - kind: registry
    name: shlex
    version: 1.3.0
    sha: 0fda2ff0d084019ba4d7c6f371c95d8fd75ce3524c3cb8fb653a3023f6323e64
  - kind: registry
    name: signal-hook
    version: 0.3.17
    sha: 8621587d4798caf8eb44879d42e56b9a93ea5dcd315a6487c357130095b62801
  - kind: registry
    name: signal-hook-registry
    version: 1.4.2
    sha: a9e9e0b4211b72e7b8b6e85c807d36c212bdb33ea8587f7569562a84df5465b1
  - kind: registry
    name: simd-adler32
    version: 0.3.7
    sha: d66dc143e6b11c1eddc06d5c423cfc97062865baf299914ab64caa38182078fe
  - kind: registry
    name: simplelog
    version: 0.12.2
    sha: 16257adbfaef1ee58b1363bdc0664c9b8e1e30aed86049635fb5f147d065a9c0
  - kind: registry
    name: smallvec
    version: 1.13.2
    sha: 3c5e1a9a646d36c3599cd173a41282daf47c44583ad367b8e6837255952e5c67
  - kind: registry
    name: smawk
    version: 0.3.2
    sha: b7c388c1b5e93756d0c740965c41e8822f866621d41acbdf6336a6a168f8840c
  - kind: registry
    name: spin
    version: 0.9.8
    sha: 6980e8d7511241f8acf4aebddbb1ff938df5eebe98691418c4468d0b72a96a67
  - kind: registry
    name: stable_deref_trait
    version: 1.2.0
    sha: a8f112729512f8e442d81f95a8a7ddf2b7c6b8a1a6f509a95864142b30cab2d3
  - kind: registry
    name: strip-ansi-escapes
    version: 0.2.0
    sha: 55ff8ef943b384c414f54aefa961dd2bd853add74ec75e7ac74cf91dba62bcfa
  - kind: registry
    name: strsim
    version: 0.11.1
    sha: 7da8b5736845d9f2fcb837ea5d9e2628564b3b043a70948a3f0b778838c5fb4f
  - kind: registry
    name: supports-color
    version: 2.1.0
    sha: d6398cde53adc3c4557306a96ce67b302968513830a77a95b2b17305d9719a89
  - kind: registry
    name: supports-hyperlinks
    version: 2.1.0
    sha: f84231692eb0d4d41e4cdd0cabfdd2e6cd9e255e65f80c9aa7c98dd502b4233d
  - kind: registry
    name: supports-unicode
    version: 2.1.0
    sha: f850c19edd184a205e883199a261ed44471c81e39bd95b1357f5febbef00e77a
  - kind: registry
    name: syn
    version: 2.0.85
    sha: 5023162dfcd14ef8f32034d8bcd4cc5ddc61ef7a247c024a33e24e1f24d21b56
  - kind: registry
    name: tap
    version: 1.0.1
    sha: 55937e1799185b12863d447f42597ed69d9928686b8d88a1df17376a097d8369
  - kind: registry
    name: termcolor
    version: 1.4.1
    sha: 06794f8f6c5c898b3275aebefa6b8a1cb24cd2c6c79397ab15774837a0bc5755
  - kind: registry
    name: terminal_size
    version: 0.1.17
    sha: 633c1a546cee861a1a6d0dc69ebeca693bf4296661ba7852b9d21d159e0506df
  - kind: registry
    name: textwrap
    version: 0.15.2
    sha: b7b3e525a49ec206798b40326a44121291b530c963cfb01018f63e135bac543d
  - kind: registry
    name: thiserror
    version: 1.0.65
    sha: 5d11abd9594d9b38965ef50805c5e469ca9cc6f197f883f717e0269a3057b3d5
  - kind: registry
    name: thiserror-impl
    version: 1.0.65
    sha: ae71770322cbd277e69d762a16c444af02aa0575ac0d174f0b9562d3b37f8602
  - kind: registry
    name: tiff
    version: 0.9.1
    sha: ba1310fcea54c6a9a4fd1aad794ecc02c31682f6bfbecdf460bf19533eed1e3e
  - kind: registry
    name: time
    version: 0.3.47
    sha: 743bd48c283afc0388f9b8827b976905fb217ad9e647fae3a379a9283c4def2c
  - kind: registry
    name: time-core
    version: 0.1.8
    sha: 7694e1cfe791f8d31026952abf09c69ca6f6fa4e1a1229e18988f06a04a12dca
  - kind: registry
    name: time-macros
    version: 0.2.27
    sha: 2e70e4c5a0e0a8a4823ad65dfe1a6930e4f4d756dcd9dd7939022b5e8c501215
  - kind: registry
    name: toml
    version: 0.8.19
    sha: a1ed1f98e3fdc28d6d910e6737ae6ab1a93bf1985935a1193e68f93eeb68d24e
  - kind: registry
    name: toml_datetime
    version: 0.6.8
    sha: 0dd7358ecb8fc2f8d014bf86f6f638ce72ba252a2c3a2572f2a795f1d23efb41
  - kind: registry
    name: toml_edit
    version: 0.19.15
    sha: 1b5bb770da30e5cbfde35a2d7b9b8a2c4b8ef89548a7a6aeab5c9a576e3e7421
  - kind: registry
    name: toml_edit
    version: 0.22.22
    sha: 4ae48d6208a266e853d946088ed816055e556cc6028c5e8e2b84d9fa5dd7c7f5
  - kind: registry
    name: unicode-ident
    version: 1.0.13
    sha: e91b56cd4cadaeb79bbf1a5645f6b4f8dc5bde8834ad5894a8db35fda9efa1fe
  - kind: registry
    name: unicode-linebreak
    version: 0.1.5
    sha: 3b09c83c3c29d37506a3e260c08c03743a6bb66a9cd432c6934ab501a190571f
  - kind: registry
    name: unicode-width
    version: 0.1.14
    sha: 7dd6e30e90baa6f72411720665d41d89b9a3d039dc45b8faea1ddd07f617f6af
  - kind: registry
    name: utf8parse
    version: 0.2.2
    sha: 06abde3611657adf66d383f00b093d7faecc7fa57071cce2578660c9f1010821
  - kind: registry
    name: vswhom
    version: 0.1.0
    sha: be979b7f07507105799e854203b470ff7c78a1639e330a58f183b5fea574608b
  - kind: registry
    name: vswhom-sys
    version: 0.1.2
    sha: d3b17ae1f6c8a2b28506cd96d412eebf83b4a0ff2cbefeeb952f2f9dfa44ba18
  - kind: registry
    name: vte
    version: 0.11.1
    sha: f5022b5fbf9407086c180e9557be968742d839e68346af7792b8592489732197
  - kind: registry
    name: vte_generate_state_changes
    version: 0.1.2
    sha: 2e369bee1b05d510a7b4ed645f5faa90619e05437111783ea5848f28d97d3c2e
  - kind: registry
    name: wasi
    version: 0.11.0+wasi-snapshot-preview1
    sha: 9c8d87e72b64a3b4db28d11ce29237c246188f4f51057d65a7eab63b7987e423
  - kind: registry
    name: wasm-bindgen
    version: 0.2.100
    sha: 1edc8929d7499fc4e8f0be2262a241556cfc54a0bea223790e71446f2aab1ef5
  - kind: registry
    name: wasm-bindgen-backend
    version: 0.2.100
    sha: 2f0a0651a5c2bc21487bde11ee802ccaf4c51935d0d3d42a6101f98161700bc6
  - kind: registry
    name: wasm-bindgen-macro
    version: 0.2.100
    sha: 7fe63fc6d09ed3792bd0897b314f53de8e16568c2b3f7982f468c0bf9bd0b407
  - kind: registry
    name: wasm-bindgen-macro-support
    version: 0.2.100
    sha: 8ae87ea40c9f689fc23f209965b6fb8a99ad69aeeb0231408be24920604395de
  - kind: registry
    name: wasm-bindgen-shared
    version: 0.2.100
    sha: 1a05d73b933a847d6cccdda8f838a22ff101ad9bf93e33684f39c1f5f0eece3d
  - kind: registry
    name: web-time
    version: 1.1.0
    sha: 5a6580f308b1fad9207618087a65c04e7a10bc77e02c8e84e9b00dd4b12fa0bb
  - kind: registry
    name: weezl
    version: 0.1.8
    sha: 53a85b86a771b1c87058196170769dd264f66c0782acf1ae6cc51bfd64b39082
  - kind: registry
    name: widestring
    version: 1.1.0
    sha: 7219d36b6eac893fa81e84ebe06485e7dcbb616177469b142df14f1f4deb1311
  - kind: registry
    name: win_dbg_logger
    version: 0.1.0
    sha: 7d1b4c22244dc27534d81e2f6fc3efd6b20e50c010f177efc20b719ec759a779
  - kind: registry
    name: winapi
    version: 0.3.9
    sha: 5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419
  - kind: registry
    name: winapi-build
    version: 0.1.1
    sha: 2d315eee3b34aca4797b2da6b13ed88266e6d612562a0c46390af8299fc699bc
  - kind: registry
    name: winapi-i686-pc-windows-gnu
    version: 0.4.0
    sha: ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6
  - kind: registry
    name: winapi-util
    version: 0.1.9
    sha: cf221c93e13a30d793f7645a0e7762c55d169dbb0a49671918a2319d289b10bb
  - kind: registry
    name: winapi-x86_64-pc-windows-gnu
    version: 0.4.0
    sha: 712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f
  - kind: registry
    name: windows-sys
    version: 0.48.0
    sha: 677d2418bec65e3338edb076e806bc1ec15693c5d0104683f2efe857f61056a9
  - kind: registry
    name: windows-sys
    version: 0.52.0
    sha: 282be5f36a8ce781fad8c8ae18fa3f9beff57ec1b52cb3de0789201425d9a33d
  - kind: registry
    name: windows-sys
    version: 0.59.0
    sha: 1e38bc4d79ed67fd075bcc251a1c39b32a1776bbe92e5bef1f0bf1f8c531853b
  - kind: registry
    name: windows-targets
    version: 0.48.5
    sha: 9a2fa6e2155d7247be68c096456083145c183cbbbc2764150dda45a87197940c
  - kind: registry
    name: windows-targets
    version: 0.52.6
    sha: 9b724f72796e036ab90c1021d4780d4d3d648aca59e491e6b98e725b84e99973
  - kind: registry
    name: windows_aarch64_gnullvm
    version: 0.48.5
    sha: 2b38e32f0abccf9987a4e3079dfb67dcd799fb61361e53e2882c3cbaf0d905d8
  - kind: registry
    name: windows_aarch64_gnullvm
    version: 0.52.6
    sha: 32a4622180e7a0ec044bb555404c800bc9fd9ec262ec147edd5989ccd0c02cd3
  - kind: registry
    name: windows_aarch64_msvc
    version: 0.48.5
    sha: dc35310971f3b2dbbf3f0690a219f40e2d9afcf64f9ab7cc1be722937c26b4bc
  - kind: registry
    name: windows_aarch64_msvc
    version: 0.52.6
    sha: 09ec2a7bb152e2252b53fa7803150007879548bc709c039df7627cabbd05d469
  - kind: registry
    name: windows_i686_gnu
    version: 0.48.5
    sha: a75915e7def60c94dcef72200b9a8e58e5091744960da64ec734a6c6e9b3743e
  - kind: registry
    name: windows_i686_gnu
    version: 0.52.6
    sha: 8e9b5ad5ab802e97eb8e295ac6720e509ee4c243f69d781394014ebfe8bbfa0b
  - kind: registry
    name: windows_i686_gnullvm
    version: 0.52.6
    sha: 0eee52d38c090b3caa76c563b86c3a4bd71ef1a819287c19d586d7334ae8ed66
  - kind: registry
    name: windows_i686_msvc
    version: 0.48.5
    sha: 8f55c233f70c4b27f66c523580f78f1004e8b5a8b659e05a4eb49d4166cca406
  - kind: registry
    name: windows_i686_msvc
    version: 0.52.6
    sha: 240948bc05c5e7c6dabba28bf89d89ffce3e303022809e73deaefe4f6ec56c66
  - kind: registry
    name: windows_x86_64_gnu
    version: 0.48.5
    sha: 53d40abd2583d23e4718fddf1ebec84dbff8381c07cae67ff7768bbf19c6718e
  - kind: registry
    name: windows_x86_64_gnu
    version: 0.52.6
    sha: 147a5c80aabfbf0c7d901cb5895d1de30ef2907eb21fbbab29ca94c5b08b1a78
  - kind: registry
    name: windows_x86_64_gnullvm
    version: 0.48.5
    sha: 0b7b52767868a23d5bab768e390dc5f5c55825b6d30b86c844ff2dc7414044cc
  - kind: registry
    name: windows_x86_64_gnullvm
    version: 0.52.6
    sha: 24d5b23dc417412679681396f2b49f3de8c1473deb516bd34410872eff51ed0d
  - kind: registry
    name: windows_x86_64_msvc
    version: 0.48.5
    sha: ed94fce61571a4006852b7389a063ab983c02eb1bb37b47f8272ce92d06d9538
  - kind: registry
    name: windows_x86_64_msvc
    version: 0.52.6
    sha: 589f6da84c646204747d1270a2a5661ea66ed1cced2631d546fdfb155959f9ec
  - kind: registry
    name: winnow
    version: 0.5.40
    sha: f593a95398737aeed53e489c785df13f3618e41dbcd6718c6addbf1395aa6876
  - kind: registry
    name: winnow
    version: 0.6.20
    sha: 36c1fec1a2bb5866f07c25f68c26e565c4c200aebb96d7e55710c19d3e8ac49b
  - kind: registry
    name: winreg
    version: 0.52.0
    sha: a277a57398d4bfa075df44f501a17cfdf8542d224f0d36095a2adc7aee4ef0a5
  - kind: registry
    name: wyz
    version: 0.5.1
    sha: 05f360fc0b24296329c78fda852a1e9ae82de9cf7b27dae4b7f62f118f77b9ed
  - kind: registry
    name: x11rb
    version: 0.13.1
    sha: 5d91ffca73ee7f68ce055750bf9f6eca0780b8c85eff9bc046a3b0da41755e12
  - kind: registry
    name: x11rb-protocol
    version: 0.13.1
    sha: ec107c4503ea0b4a98ef47356329af139c0a4f7750e621cf2973cd3385ebcb3d
