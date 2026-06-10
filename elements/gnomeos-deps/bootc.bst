kind: make

sources:
- kind: git_repo
  url: github:bootc-dev/bootc.git
  track: v*
  ref: v1.16.0-0-gd3f885e3c69f2194059329ac1685273197e6b1f7
- kind: cargo2
  ref:
  - kind: registry
    name: addr2line
    version: 0.25.1
    sha: 1b5d307320b3181d6d7954e663bd7c774a838b8220fe0593c86d9fb09f498b4b
  - kind: registry
    name: adler2
    version: 2.0.1
    sha: 320119579fcad9c21884f5c4861d16174d0e06250625266f50fe6898340abefa
  - kind: registry
    name: aho-corasick
    version: 1.1.4
    sha: ddd31a130427c27518df266943a5308ed92d4b226cc639f5a8f1002816174301
  - kind: registry
    name: ambient-authority
    version: 0.0.2
    sha: e9d4ee0d472d1cd2e28c97dfa124b3d8d992e10eb0a035f33f5d12e3a177ba3b
  - kind: registry
    name: android_system_properties
    version: 0.1.5
    sha: 819e7219dbd41043ac279b19830f2efc897156490d7fd6ea916720117ee66311
  - kind: registry
    name: anstream
    version: 1.0.0
    sha: 824a212faf96e9acacdbd09febd34438f8f711fb84e09a8916013cd7815ca28d
  - kind: registry
    name: anstyle
    version: 1.0.14
    sha: 940b3a0ca603d1eade50a4846a2afffd5ef57a9feac2c0e2ec2e14f9ead76000
  - kind: registry
    name: anstyle-parse
    version: 1.0.0
    sha: 52ce7f38b242319f7cabaa6813055467063ecdc9d355bbb4ce0c68908cd8130e
  - kind: registry
    name: anstyle-query
    version: 1.1.5
    sha: 40c48f72fd53cd289104fc64099abca73db4166ad86ea0b4341abe65af83dadc
  - kind: registry
    name: anstyle-wincon
    version: 3.0.11
    sha: 291e6a250ff86cd4a820112fb8898808a366d8f9f58ce16d1f538353ad55747d
  - kind: registry
    name: anyhow
    version: 1.0.102
    sha: 7f202df86484c868dbad7eaa557ef785d5c66295e41b460ef922eca0723b842c
  - kind: registry
    name: async-compression
    version: 0.4.42
    sha: e79b3f8a79cccc2898f31920fc69f304859b3bd567490f75ebf51ae1c792a9ac
  - kind: registry
    name: async-trait
    version: 0.1.89
    sha: 9035ad2d096bed7955a320ee7e2230574d28fd3c3a0f186cbea1ff3c7eed5dbb
  - kind: registry
    name: atomic-waker
    version: 1.1.2
    sha: 1505bd5d3d116872e7271a6d4e16d81d0c8570876c8de68093a09ac269d8aac0
  - kind: registry
    name: autocfg
    version: 1.5.0
    sha: c08606f8c3cbf4ce6ec8e28fb0014a2c086708fe954eaa885384a6165172e7e8
  - kind: registry
    name: backtrace
    version: 0.3.76
    sha: bb531853791a215d7c62a30daf0dde835f381ab5de4589cfe7c649d2cbe92bd6
  - kind: registry
    name: base64
    version: 0.20.0
    sha: 0ea22880d78093b0cbe17c89f64a7d457941e65759157ec6cb31a31d652b05e5
  - kind: registry
    name: base64
    version: 0.21.7
    sha: 9d297deb1925b89f2ccc13d7635fa0714f12c87adce1c75356b39ca9b7178567
  - kind: registry
    name: base64
    version: 0.22.1
    sha: 72b3254f16251a8381aa12e40e3c4d2f0199f8c6508fbecb9d91f575e0fbb8c6
  - kind: git
    commit: c1adfa9834aec219ea3c015e04871a46b375b0f0
    repo: https://github.com/bootc-dev/bcvk
    query:
      rev: c1adfa9834aec219ea3c015e04871a46b375b0f0
    name: bcvk-qemu
    version: 0.1.0
  - kind: registry
    name: bitflags
    version: 1.3.2
    sha: bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a
  - kind: registry
    name: bitflags
    version: 2.11.1
    sha: c4512299f36f043ab09a583e57bceb5a5aab7a73db1805848e8fef3c9e8c78b3
  - kind: registry
    name: block-buffer
    version: 0.10.4
    sha: 3078c7629b62d3f0439517fa394996acacc5cbc91c5a20d8c658e77abd503a71
  - kind: registry
    name: block-buffer
    version: 0.12.0
    sha: cdd35008169921d80bc60d3d0ab416eecb028c4cd653352907921d95084790be
  - kind: registry
    name: bstr
    version: 1.12.1
    sha: 63044e1ae8e69f3b5a92c736ca6269b8d12fa7efe39bf34ddb06d102cf0e2cab
  - kind: registry
    name: bumpalo
    version: 3.20.2
    sha: 5d20789868f4b01b2f2caec9f5c4e0213b41e3e5702a50157d699ae31ced2fcb
  - kind: registry
    name: byteorder
    version: 1.5.0
    sha: 1fd0f2584146f6f2ef48085050886acf353beff7305ebd1ae69500e27c67f64b
  - kind: registry
    name: bytes
    version: 1.11.1
    sha: 1e748733b7cbc798e1434b6ac524f0c1ff2ab456fe201501e6497c8417a4fc33
  - kind: registry
    name: camino
    version: 1.2.2
    sha: e629a66d692cb9ff1a1c664e41771b3dcaf961985a9774c0eb0bd1b51cf60a48
  - kind: registry
    name: canon-json
    version: 0.2.1
    sha: b5ae9f90437d2e2efba2a6c75b8279aa6b8f2f4017e0a4aeb64a76cd9d3a2bab
  - kind: registry
    name: cap-primitives
    version: 3.4.5
    sha: b6cf3aea8a5081171859ef57bc1606b1df6999df4f1110f8eef68b30098d1d3a
  - kind: registry
    name: cap-primitives
    version: 4.0.2
    sha: cdadbd7c002d3a484b35243669abdae85a0ebaded5a61117169dc3400f9a7ff0
  - kind: registry
    name: cap-std
    version: 3.4.5
    sha: b6dc3090992a735d23219de5c204927163d922f42f575a0189b005c62d37549a
  - kind: registry
    name: cap-std
    version: 4.0.2
    sha: 7281235d6e96d3544ca18bba9049be92f4190f8d923e3caef1b5f66cfa752608
  - kind: registry
    name: cap-std-ext
    version: 4.0.7
    sha: 6fe962d42e07c22aec2618191c3683412735b7e6dcd7bab2eec811ab4697c58e
  - kind: registry
    name: cap-std-ext
    version: 5.1.2
    sha: 6c6c5ac70c4465b47c3a322330f87c2df31e42ac527497d94dc1f1d1cb8989f9
  - kind: registry
    name: cap-tempfile
    version: 3.4.5
    sha: 68d8ad5cfac469e58e632590f033d45c66415ef7a8aa801409884818036706f5
  - kind: registry
    name: cap-tempfile
    version: 4.0.2
    sha: 42f22d5c0b1147e8bd9105fa004450f673c139d7e632f7edc3980f94a51f20f3
  - kind: registry
    name: cargo-platform
    version: 0.3.3
    sha: dd0061da739915fae12ea00e16397555ed4371a6bb285431aab930f61b0aa4ba
  - kind: registry
    name: cargo_metadata
    version: 0.23.1
    sha: ef987d17b0a113becdd19d3d0022d04d7ef41f9efe4f3fb63ac44ba61df3ade9
  - kind: registry
    name: cc
    version: 1.2.61
    sha: d16d90359e986641506914ba71350897565610e87ce0ad9e6f28569db3dd5c6d
  - kind: registry
    name: cfg-expr
    version: 0.20.7
    sha: 3c6b04e07d8080154ed4ac03546d9a2b303cc2fe1901ba0b35b301516e289368
  - kind: registry
    name: cfg-if
    version: 1.0.4
    sha: 9330f8b2ff13f34540b44e946ef35111825727b38d33286ef986142615121801
  - kind: registry
    name: cfg_aliases
    version: 0.2.1
    sha: 613afe47fcd5fac7ccf1db93babcb082c5994d996f20b8b159f2ad1658eb5724
  - kind: registry
    name: chacha20
    version: 0.10.0
    sha: 6f8d983286843e49675a4b7a2d174efe136dc93a18d69130dd18198a6c167601
  - kind: registry
    name: chrono
    version: 0.4.44
    sha: c673075a2e0e5f4a1dde27ce9dee1ea4558c7ffe648f576438a20ca1d2acc4b0
  - kind: registry
    name: clap
    version: 4.6.1
    sha: 1ddb117e43bbf7dacf0a4190fef4d345b9bad68dfc649cb349e7d17d28428e51
  - kind: registry
    name: clap_builder
    version: 4.6.0
    sha: 714a53001bf66416adb0e2ef5ac857140e7dc3a0c48fb28b2f10762fc4b5069f
  - kind: registry
    name: clap_complete
    version: 4.6.2
    sha: 3ff7a1dccbdd8b078c2bdebff47e404615151534d5043da397ec50286816f9cb
  - kind: registry
    name: clap_derive
    version: 4.6.1
    sha: f2ce8604710f6733aa641a2b3731eaa1e8b3d9973d5e3565da11800813f997a9
  - kind: registry
    name: clap_lex
    version: 1.1.0
    sha: c8d4a3bb8b1e0c1050499d1815f5ab16d04f0959b233085fb31653fbfc9d98f9
  - kind: registry
    name: clap_mangen
    version: 0.3.0
    sha: d82842b45bf9f6a3be090dd860095ac30728042c08e0d6261ca7259b5d850f07
  - kind: registry
    name: color-eyre
    version: 0.6.5
    sha: e5920befb47832a6d61ee3a3a846565cfa39b331331e68a3b1d1116630f2f26d
  - kind: registry
    name: color-spantrace
    version: 0.3.0
    sha: b8b88ea9df13354b55bc7234ebcce36e6ef896aca2e42a15de9e10edce01b427
  - kind: registry
    name: colorchoice
    version: 1.0.5
    sha: 1d07550c9036bf2ae0c684c4297d503f838287c83c53686d05370d0e139ae570
  - kind: registry
    name: comfy-table
    version: 7.2.2
    sha: 958c5d6ecf1f214b4c2bbbbf6ab9523a864bd136dcf71a7e8904799acfe1ad47
  - kind: registry
    name: comma
    version: 1.0.0
    sha: 55b672471b4e9f9e95499ea597ff64941a309b2cdbffcc46f2cc5e2d971fd335
  - kind: git
    commit: e2770757762ec5091bb183bf0e778fe97c8d5694
    repo: https://github.com/composefs/composefs-rs
    query:
      rev: e2770757762ec5091bb183bf0e778fe97c8d5694
    name: composefs
    version: 0.4.0
  - kind: git
    commit: e2770757762ec5091bb183bf0e778fe97c8d5694
    repo: https://github.com/composefs/composefs-rs
    query:
      rev: e2770757762ec5091bb183bf0e778fe97c8d5694
    name: composefs-boot
    version: 0.4.0
  - kind: git
    commit: e2770757762ec5091bb183bf0e778fe97c8d5694
    repo: https://github.com/composefs/composefs-rs
    query:
      rev: e2770757762ec5091bb183bf0e778fe97c8d5694
    name: composefs-ctl
    version: 0.4.0
  - kind: git
    commit: e2770757762ec5091bb183bf0e778fe97c8d5694
    repo: https://github.com/composefs/composefs-rs
    query:
      rev: e2770757762ec5091bb183bf0e778fe97c8d5694
    name: composefs-ioctls
    version: 0.4.0
  - kind: git
    commit: e2770757762ec5091bb183bf0e778fe97c8d5694
    repo: https://github.com/composefs/composefs-rs
    query:
      rev: e2770757762ec5091bb183bf0e778fe97c8d5694
    name: composefs-oci
    version: 0.4.0
  - kind: git
    commit: e2770757762ec5091bb183bf0e778fe97c8d5694
    repo: https://github.com/composefs/composefs-rs
    query:
      rev: e2770757762ec5091bb183bf0e778fe97c8d5694
    name: composefs-storage
    version: 0.4.0
  - kind: registry
    name: compression-codecs
    version: 0.4.38
    sha: ce2548391e9c1929c21bf6aa2680af86fe4c1b33e6cea9ac1cfeec0bd11218cf
  - kind: registry
    name: compression-core
    version: 0.4.32
    sha: cc14f565cf027a105f7a44ccf9e5b424348421a1d8952a8fc9d499d313107789
  - kind: registry
    name: console
    version: 0.15.11
    sha: 054ccb5b10f9f2cbf51eb355ca1d05c2d279ce1804688d0db74b4733a5aeafd8
  - kind: registry
    name: console
    version: 0.16.3
    sha: d64e8af5551369d19cf50138de61f1c42074ab970f74e99be916646777f8fc87
  - kind: registry
    name: const_format
    version: 0.2.36
    sha: 4481a617ad9a412be3b97c5d403fef8ed023103368908b9c50af598ff467cc1e
  - kind: registry
    name: const_format_proc_macros
    version: 0.2.34
    sha: 1d57c2eccfb16dbac1f4e61e206105db5820c9d26c3c472bc17c774259ef7744
  - kind: registry
    name: containers-image-proxy
    version: 0.10.1
    sha: 75af58c668f3331f80098044f39832e4bde15e5a58b4c9fb4beb0afa78bc3466
  - kind: registry
    name: convert_case
    version: 0.10.0
    sha: 633458d4ef8c78b72454de2d54fd6ab2e60f9e02be22f3c6104cdc8a4e0fceb9
  - kind: registry
    name: core-foundation-sys
    version: 0.8.7
    sha: 773648b94d0e5d620f64f280777445740e61fe701025087ec8b57f45c791888b
  - kind: registry
    name: cpufeatures
    version: 0.2.17
    sha: 59ed5838eebb26a2bb2e58f6d5b5316989ae9d08bab10e0e6d103e656d1b0280
  - kind: registry
    name: cpufeatures
    version: 0.3.0
    sha: 8b2a41393f66f16b0823bb79094d54ac5fbd34ab292ddafb9a0456ac9f87d201
  - kind: registry
    name: crc
    version: 3.4.0
    sha: 5eb8a2a1cd12ab0d987a5d5e825195d372001a4094a0376319d5a0ad71c1ba0d
  - kind: registry
    name: crc-catalog
    version: 2.4.0
    sha: 19d374276b40fb8bbdee95aef7c7fa6b5316ec764510eb64b8dd0e2ed0d7e7f5
  - kind: registry
    name: crc32fast
    version: 1.5.0
    sha: 9481c1c90cbf2ac953f07c8d4a58aa3945c425b7185c9154d67a65e4230da511
  - kind: registry
    name: crossterm
    version: 0.29.0
    sha: d8b9f2e4c67f833b660cdb0a3523065869fb35570177239812ed4c905aeff87b
  - kind: registry
    name: crossterm_winapi
    version: 0.9.1
    sha: acdd7c62a3665c7f6830a51635d9ac9b23ed385797f70a83bb8bafe9c572ab2b
  - kind: registry
    name: crypto-common
    version: 0.1.7
    sha: 78c8292055d1c1df0cce5d180393dc8cce0abec0a7102adb6c7b1eef6016d60a
  - kind: registry
    name: crypto-common
    version: 0.2.1
    sha: 77727bb15fa921304124b128af125e7e3b968275d1b108b379190264f4423710
  - kind: registry
    name: darling
    version: 0.20.11
    sha: fc7f46116c46ff9ab3eb1597a45688b6715c6e628b5c133e288e709a29bcb4ee
  - kind: registry
    name: darling_core
    version: 0.20.11
    sha: 0d00b9596d185e565c2207a0b01f8bd1a135483d02d9b7b0a54b11da8d53412e
  - kind: registry
    name: darling_macro
    version: 0.20.11
    sha: fc34b93ccb385b40dc71c6fceac4b2ad23662c7eeb248cf10d529b7e055b6ead
  - kind: registry
    name: data-encoding
    version: 2.11.0
    sha: a4ae5f15dda3c708c0ade84bfee31ccab44a3da4f88015ed22f63732abe300c8
  - kind: registry
    name: derive_builder
    version: 0.20.2
    sha: 507dfb09ea8b7fa618fcf76e953f4f5e192547945816d5358edffe39f6f94947
  - kind: registry
    name: derive_builder_core
    version: 0.20.2
    sha: 2d5bcf7b024d6835cfb3d473887cd966994907effbe9227e8c8219824d06c4e8
  - kind: registry
    name: derive_builder_macro
    version: 0.20.2
    sha: ab63b0e2bf4d5928aff72e83a7dace85d7bba5fe12dcc3c5a572d78caffd3f3c
  - kind: registry
    name: derive_more
    version: 2.1.1
    sha: d751e9e49156b02b44f9c1815bcb94b984cdcc4396ecc32521c739452808b134
  - kind: registry
    name: derive_more-impl
    version: 2.1.1
    sha: 799a97264921d8623a957f6c3b9011f3b5492f557bbb7a5a19b7fa6d06ba8dcb
  - kind: registry
    name: deunicode
    version: 1.6.2
    sha: abd57806937c9cc163efc8ea3910e00a62e2aeb0b8119f1793a978088f8f6b04
  - kind: registry
    name: dialoguer
    version: 0.12.0
    sha: 25f104b501bf2364e78d0d3974cbc774f738f5865306ed128e1e0d7499c0ad96
  - kind: registry
    name: digest
    version: 0.10.7
    sha: 9ed9a281f7bc9b7576e61468ba615a66a5c8cfdff42420a70aa82701a3b1e292
  - kind: registry
    name: digest
    version: 0.11.2
    sha: 4850db49bf08e663084f7fb5c87d202ef91a3907271aff24a94eb97ff039153c
  - kind: registry
    name: document-features
    version: 0.2.12
    sha: d4b8a88685455ed29a21542a33abd9cb6510b6b129abadabdcef0f4c55bc8f61
  - kind: registry
    name: dyn-clone
    version: 1.0.20
    sha: d0881ea181b1df73ff77ffaaf9c7544ecc11e82fba9b5f27b262a3c73a332555
  - kind: registry
    name: either
    version: 1.15.0
    sha: 48c757948c5ede0e46177b7add2e67155f70e33c07fea8284df6576da70b3719
  - kind: registry
    name: encode_unicode
    version: 1.0.0
    sha: 34aa73646ffb006b8f5147f3dc182bd4bcb190227ce861fc4a4844bf8e3cb2c0
  - kind: registry
    name: env_filter
    version: 1.0.1
    sha: 32e90c2accc4b07a8456ea0debdc2e7587bdd890680d71173a15d4ae604f6eef
  - kind: registry
    name: env_logger
    version: 0.11.10
    sha: 0621c04f2196ac3f488dd583365b9c09be011a4ab8b9f37248ffcc8f6198b56a
  - kind: registry
    name: equivalent
    version: 1.0.2
    sha: 877a4ace8713b0bcf2a4e7eec82529c029f1d0619886d18145fea96c3ffe5c0f
  - kind: registry
    name: errno
    version: 0.3.14
    sha: 39cab71617ae0d63f51a36d69f866391735b51691dbda63cf6f96d042b63efeb
  - kind: registry
    name: escape8259
    version: 0.5.3
    sha: 5692dd7b5a1978a5aeb0ce83b7655c58ca8efdcb79d21036ea249da95afec2c6
  - kind: registry
    name: eyre
    version: 0.6.12
    sha: 7cd915d99f24784cdc19fd37ef22b97e3ff0ae756c7e492e9fbfe897d61e2aec
  - kind: registry
    name: fastrand
    version: 2.4.1
    sha: 9f1f227452a390804cdb637b74a86990f2a7d7ba4b7d5693aac9b4dd6defd8d6
  - kind: registry
    name: filetime
    version: 0.2.27
    sha: f98844151eee8917efc50bd9e8318cb963ae8b297431495d3f758616ea5c57db
  - kind: registry
    name: find-msvc-tools
    version: 0.1.9
    sha: 5baebc0774151f905a1a2cc41989300b1e6fbb29aff0ceffa1064fdd3088d582
  - kind: registry
    name: flate2
    version: 1.1.9
    sha: 843fba2746e448b37e26a819579957415c8cef339bf08564fe8b7ddbd959573c
  - kind: registry
    name: fn-error-context
    version: 0.2.1
    sha: 2cd66269887534af4b0c3e3337404591daa8dc8b9b2b3db71f9523beb4bafb41
  - kind: registry
    name: fnv
    version: 1.0.7
    sha: 3f9eec918d3f24069decb9af1554cad7c880e2da24a9afd88aca000531ab82c1
  - kind: registry
    name: foldhash
    version: 0.1.5
    sha: d9c4f5dac5e15c24eb999c26181a6ca40b39fe946cbe4c263c7209467bc83af2
  - kind: registry
    name: foreign-types
    version: 0.3.2
    sha: f6f339eb8adc052cd2ca78910fda869aefa38d22d5cb648e6485e4d3fc06f3b1
  - kind: registry
    name: foreign-types-shared
    version: 0.1.1
    sha: 00b0228411908ca8685dba7fc2cdd70ec9990a6e753e89b6ac91a84c40fbaf4b
  - kind: registry
    name: fs-set-times
    version: 0.20.3
    sha: 94e7099f6313ecacbe1256e8ff9d617b75d1bcb16a6fddef94866d225a01a14a
  - kind: registry
    name: futures
    version: 0.3.32
    sha: 8b147ee9d1f6d097cef9ce628cd2ee62288d963e16fb287bd9286455b241382d
  - kind: registry
    name: futures-channel
    version: 0.3.32
    sha: 07bbe89c50d7a535e539b8c17bc0b49bdb77747034daa8087407d655f3f7cc1d
  - kind: registry
    name: futures-core
    version: 0.3.32
    sha: 7e3450815272ef58cec6d564423f6e755e25379b217b0bc688e295ba24df6b1d
  - kind: registry
    name: futures-executor
    version: 0.3.32
    sha: baf29c38818342a3b26b5b923639e7b1f4a61fc5e76102d4b1981c6dc7a7579d
  - kind: registry
    name: futures-io
    version: 0.3.32
    sha: cecba35d7ad927e23624b22ad55235f2239cfa44fd10428eecbeba6d6a717718
  - kind: registry
    name: futures-macro
    version: 0.3.32
    sha: e835b70203e41293343137df5c0664546da5745f82ec9b84d40be8336958447b
  - kind: registry
    name: futures-sink
    version: 0.3.32
    sha: c39754e157331b013978ec91992bde1ac089843443c49cbc7f46150b0fad0893
  - kind: registry
    name: futures-task
    version: 0.3.32
    sha: 037711b3d59c33004d3856fbdc83b99d4ff37a24768fa1be9ce3538a1cde4393
  - kind: registry
    name: futures-timer
    version: 3.0.3
    sha: f288b0a4f20f9a56b5d1da57e2227c661b7b16168e2f72365f57b63326e29b24
  - kind: registry
    name: futures-util
    version: 0.3.32
    sha: 389ca41296e6190b48053de0321d02a77f32f8a5d2461dd38762c0593805c6d6
  - kind: registry
    name: generic-array
    version: 0.14.7
    sha: 85649ca51fd72272d7821adaf274ad91c288277713d9c18820d8499a7ff69e9a
  - kind: registry
    name: getopts
    version: 0.2.24
    sha: cfe4fbac503b8d1f88e6676011885f34b7174f46e59956bba534ba83abded4df
  - kind: registry
    name: getrandom
    version: 0.2.17
    sha: ff2abc00be7fca6ebc474524697ae276ad847ad0a6b3faa4bcb027e9a4614ad0
  - kind: registry
    name: getrandom
    version: 0.3.4
    sha: 899def5c37c4fd7b2664648c28120ecec138e4d395b459e5ca34f9cce2dd77fd
  - kind: registry
    name: getrandom
    version: 0.4.2
    sha: 0de51e6874e94e7bf76d726fc5d13ba782deca734ff60d5bb2fb2607c7406555
  - kind: registry
    name: getset
    version: 0.1.6
    sha: 9cf0fc11e47561d47397154977bc219f4cf809b2974facc3ccb3b89e2436f912
  - kind: registry
    name: gimli
    version: 0.32.3
    sha: e629b9b98ef3dd8afe6ca2bd0f89306cec16d43d907889945bc5d6687f2f13c7
  - kind: registry
    name: gio
    version: 0.20.12
    sha: 8e27e276e7b6b8d50f6376ee7769a71133e80d093bdc363bd0af71664228b831
  - kind: registry
    name: gio-sys
    version: 0.20.10
    sha: 521e93a7e56fc89e84aea9a52cfc9436816a4b363b030260b699950ff1336c83
  - kind: registry
    name: glib
    version: 0.20.12
    sha: ffc4b6e352d4716d84d7dde562dd9aee2a7d48beb872dd9ece7f2d1515b2d683
  - kind: registry
    name: glib-macros
    version: 0.20.12
    sha: e8084af62f09475a3f529b1629c10c429d7600ee1398ae12dd3bf175d74e7145
  - kind: registry
    name: glib-sys
    version: 0.20.10
    sha: 8ab79e1ed126803a8fb827e3de0e2ff95191912b8db65cee467edb56fc4cc215
  - kind: registry
    name: gobject-sys
    version: 0.20.10
    sha: ec9aca94bb73989e3cfdbf8f2e0f1f6da04db4d291c431f444838925c4c63eda
  - kind: registry
    name: gvariant
    version: 0.5.1
    sha: 748b888e9db06c42fef01ec5958d0955fd8813b3d6b5d3bb8b21713806abca04
  - kind: registry
    name: gvariant-macro
    version: 0.5.1
    sha: 88bee3fdb16eb087e08c38ea50f796c75085659c8a70b6928a8c9f3c7449beb5
  - kind: registry
    name: h2
    version: 0.4.13
    sha: 2f44da3a8150a6703ed5d34e164b875fd14c2cdab9af1252a9a1020bde2bdc54
  - kind: registry
    name: hashbrown
    version: 0.15.5
    sha: 9229cfe53dfd69f0609a49f65461bd93001ea1ef889cd5529dd176593f5338a1
  - kind: registry
    name: hashbrown
    version: 0.17.0
    sha: 4f467dd6dccf739c208452f8014c75c18bb8301b050ad1cfb27153803edb0f51
  - kind: registry
    name: heck
    version: 0.5.0
    sha: 2304e00983f87ffb38b55b444b5e3b60a884b5d30c0fca7d82fe33449bbe55ea
  - kind: registry
    name: hex
    version: 0.4.3
    sha: 7f24254aa9a54b5c858eaee2f5bccdb46aaf0e486a595ed5fd8f86ba55232a70
  - kind: registry
    name: hmac
    version: 0.12.1
    sha: 6c49c37c09c17a53d937dfbb742eb3a961d65a994e6bcdcf37e7399d0cc8ab5e
  - kind: registry
    name: http
    version: 1.4.0
    sha: e3ba2a386d7f85a81f119ad7498ebe444d2e22c2af0b86b069416ace48b3311a
  - kind: registry
    name: http-body
    version: 1.0.1
    sha: 1efedce1fb8e6913f23e0c92de8e62cd5b772a67e7b3946df930a62566c93184
  - kind: registry
    name: http-body-util
    version: 0.1.3
    sha: b021d93e26becf5dc7e1b75b1bed1fd93124b374ceb73f43d4d4eafec896a64a
  - kind: registry
    name: httparse
    version: 1.10.1
    sha: 6dbf3de79e51f3d586ab4cb9d5c3e2c14aa28ed23d180cf89b4df0454a69cc87
  - kind: registry
    name: httpdate
    version: 1.0.3
    sha: df3b46402a9d5adb4c86a0cf463f42e19994e3ee891101b1841f30a545cb49a9
  - kind: registry
    name: hybrid-array
    version: 0.4.11
    sha: 08d46837a0ed51fe95bd3b05de33cd64a1ee88fc797477ca48446872504507c5
  - kind: registry
    name: hyper
    version: 1.9.0
    sha: 6299f016b246a94207e63da54dbe807655bf9e00044f73ded42c3ac5305fbcca
  - kind: registry
    name: hyper-util
    version: 0.1.20
    sha: 96547c2556ec9d12fb1578c4eaf448b04993e7fb79cbaad930a656880a6bdfa0
  - kind: registry
    name: iana-time-zone
    version: 0.1.65
    sha: e31bc9ad994ba00e440a8aa5c9ef0ec67d5cb5e5cb0cc7f8b744a35b389cc470
  - kind: registry
    name: iana-time-zone-haiku
    version: 0.1.2
    sha: f31827a206f56af32e590ba56d5d2d085f558508192593743f16b2306495269f
  - kind: registry
    name: id-arena
    version: 2.3.0
    sha: 3d3067d79b975e8844ca9eb072e16b31c3c1c36928edf9c6789548c524d0d954
  - kind: registry
    name: ident_case
    version: 1.0.1
    sha: b9e0384b61958566e926dc50660321d12159025e767c18e043daf26b70104c39
  - kind: registry
    name: indenter
    version: 0.3.4
    sha: 964de6e86d545b246d84badc0fef527924ace5134f30641c203ef52ba83f58d5
  - kind: registry
    name: indexmap
    version: 2.14.0
    sha: d466e9454f08e4a911e14806c24e16fba1b4c121d1ea474396f396069cf949d9
  - kind: registry
    name: indicatif
    version: 0.17.11
    sha: 183b3088984b400f4cfac3620d5e076c84da5364016b4f49473de574b2586235
  - kind: registry
    name: indicatif
    version: 0.18.4
    sha: 25470f23803092da7d239834776d653104d551bc4d7eacaf31e6837854b8e9eb
  - kind: registry
    name: indoc
    version: 2.0.7
    sha: 79cf5c93f93228cf8efb3ba362535fb11199ac548a09ce117c9b1adc3030d706
  - kind: registry
    name: io-extras
    version: 0.18.4
    sha: 2285ddfe3054097ef4b2fe909ef8c3bcd1ea52a8f0d274416caebeef39f04a65
  - kind: registry
    name: io-extras
    version: 0.19.0
    sha: 20fd6de4ccfcc187e38bc21cfa543cb5a302cb86a8b114eb7f0bf0dc9f8ac00f
  - kind: registry
    name: io-lifetimes
    version: 2.0.4
    sha: 06432fb54d3be7964ecd3649233cddf80db2832f47fec34c01f65b3d9d774983
  - kind: registry
    name: io-lifetimes
    version: 3.0.1
    sha: 2f0fb0570afe1fed943c5c3d4102d5358592d8625fda6a0007fdbe65a92fba96
  - kind: registry
    name: ipnet
    version: 2.12.0
    sha: d98f6fed1fde3f8c21bc40a1abb88dd75e67924f9cffc3ef95607bad8017f8e2
  - kind: registry
    name: is_terminal_polyfill
    version: 1.70.2
    sha: a6cb138bb79a146c1bd460005623e142ef0181e3d0219cb493e02f7d08a35695
  - kind: registry
    name: itertools
    version: 0.14.0
    sha: 2b192c782037fadd9cfa75548310488aabdbf3d2da73885b31bd0abd03351285
  - kind: registry
    name: itoa
    version: 1.0.18
    sha: 8f42a60cbdf9a97f5d2305f08a87dc4e09308d1276d28c869c684d7777685682
  - kind: registry
    name: jobserver
    version: 0.1.34
    sha: 9afb3de4395d6b3e67a780b6de64b51c978ecf11cb9a462c66be7d4ca9039d33
  - kind: registry
    name: js-sys
    version: 0.3.95
    sha: 2964e92d1d9dc3364cae4d718d93f227e3abb088e747d92e0395bfdedf1c12ca
  - kind: registry
    name: jsonrpc-fdpass
    version: 0.1.1
    sha: 804f932133a0dce65a229a506a417eeafd160401a54aa05d67c2e5eb108ca603
  - kind: registry
    name: jsonrpsee
    version: 0.24.10
    sha: e281ae70cc3b98dac15fced3366a880949e65fc66e345ce857a5682d152f3e62
  - kind: registry
    name: jsonrpsee-core
    version: 0.24.10
    sha: 348ee569eaed52926b5e740aae20863762b16596476e943c9e415a6479021622
  - kind: registry
    name: jsonrpsee-server
    version: 0.24.10
    sha: 21429bcdda37dcf2d43b68621b994adede0e28061f816b038b0f18c70c143d51
  - kind: registry
    name: jsonrpsee-types
    version: 0.24.10
    sha: b0f05e0028e55b15dbd2107163b3c744cd3bb4474f193f95d9708acbf5677e44
  - kind: registry
    name: konst
    version: 0.2.20
    sha: 128133ed7824fcd73d6e7b17957c5eb7bacb885649bd8c69708b2331a10bcefb
  - kind: registry
    name: konst_macro_rules
    version: 0.2.19
    sha: a4933f3f57a8e9d9da04db23fb153356ecaf00cbd14aee46279c33dc80925c37
  - kind: registry
    name: lazy_static
    version: 1.5.0
    sha: bbd2bcb4c963f2ddae06a2efc7e9f3591312473c50c6685e1f298068316e66fe
  - kind: registry
    name: leb128fmt
    version: 0.1.0
    sha: 09edd9e8b54e49e587e4f6295a7d29c3ea94d469cb40ab8ca70b288248a81db2
  - kind: registry
    name: libc
    version: 0.2.186
    sha: 68ab91017fe16c622486840e4c83c9a37afeff978bd239b5293d61ece587de66
  - kind: registry
    name: liboverdrop
    version: 0.1.0
    sha: 08e5373d7512834e2fbbe4100111483a99c28ca3818639f67ab2337672301f8e
  - kind: registry
    name: libredox
    version: 0.1.16
    sha: e02f3bb43d335493c96bf3fd3a321600bf6bd07ed34bc64118e9293bdffea46c
  - kind: registry
    name: libsystemd
    version: 0.7.2
    sha: 19c97a761fc86953c5b885422b22c891dbf5bcb9dcc99d0110d6ce4c052759f0
  - kind: registry
    name: libtest-mimic
    version: 0.8.2
    sha: 14e6ba06f0ade6e504aff834d7c34298e5155c6baca353cc6a4aaff2f9fd7f33
  - kind: registry
    name: libz-sys
    version: 1.1.28
    sha: fc3a226e576f50782b3305c5ccf458698f92798987f551c6a02efe8276721e22
  - kind: registry
    name: linkme
    version: 0.3.36
    sha: e83272d46373fb8decca684579ac3e7c8f3d71d4cc3aa693df8759e260ae41cf
  - kind: registry
    name: linkme-impl
    version: 0.3.36
    sha: 32d59e20403c7d08fe62b4376edfe5c7fb2ef1e6b1465379686d0f21c8df444b
  - kind: registry
    name: linux-raw-sys
    version: 0.12.1
    sha: 32a66949e030da00e8c7d4434b251670a91556f4144941d37452769c25d58a53
  - kind: registry
    name: litrs
    version: 1.0.0
    sha: 11d3d7f243d5c5a8b9bb5d6dd2b1602c0cb0b9db1621bafc7ed66e35ff9fe092
  - kind: registry
    name: lock_api
    version: 0.4.14
    sha: 224399e74b87b5f3557511d98dff8b14089b3dadafcab6bb93eab67d3aace965
  - kind: registry
    name: log
    version: 0.4.29
    sha: 5e5032e24019045c762d3c0f28f5b6b8bbf38563a65908389bf7978758920897
  - kind: registry
    name: mandown
    version: 1.1.0
    sha: 9edef1e8731732e8977534921abcef085c2308096092e7294b1bb2629589908f
  - kind: registry
    name: matchers
    version: 0.2.0
    sha: d1525a2a28c7f4fa0fc98bb91ae755d1e2d1505079e05539e35bc876b5d65ae9
  - kind: registry
    name: maybe-owned
    version: 0.3.4
    sha: 4facc753ae494aeb6e3c22f839b158aebd4f9270f55cd3c79906c45476c47ab4
  - kind: registry
    name: md-5
    version: 0.10.6
    sha: d89e7ee0cfbedfc4da3340218492196241d89eefb6dab27de5df917a6d2e78cf
  - kind: registry
    name: memchr
    version: 2.8.0
    sha: f8ca58f447f06ed17d5fc4043ce1b10dd205e060fb3ce5b979b8ed8e59ff3f79
  - kind: registry
    name: memoffset
    version: 0.9.1
    sha: 488016bfae457b036d996092f6cb448677611ce4449e970ceaf42695203f218a
  - kind: registry
    name: miniz_oxide
    version: 0.8.9
    sha: 1fa76a2c86f704bdb222d66965fb3d63269ce38518b83cb0575fca855ebb6316
  - kind: registry
    name: mio
    version: 1.2.0
    sha: 50b7e5b27aa02a74bac8c3f23f448f8d87ff11f92d3aac1a6ed369ee08cc56c1
  - kind: registry
    name: nix
    version: 0.29.0
    sha: 71e2746dc3a24dd78b3cfcb7be93368c6de9963d30f43a6a73998a9cf4b17b46
  - kind: registry
    name: nix
    version: 0.31.2
    sha: 5d6d0705320c1e6ba1d912b5e37cf18071b6c2e9b7fa8215a1e8a7651966f5d3
  - kind: registry
    name: nom
    version: 8.0.0
    sha: df9761775871bdef83bee530e60050f7e54b1105350d6884eb0fb4f46c2f9405
  - kind: registry
    name: nu-ansi-term
    version: 0.50.3
    sha: 7957b9740744892f114936ab4a57b3f487491bbeafaf8083688b16841a4240e5
  - kind: registry
    name: num-traits
    version: 0.2.19
    sha: 071dfc062690e90b734c0b2273ce72ad0ffa95f0c74596bc250dcfd960262841
  - kind: registry
    name: number_prefix
    version: 0.4.0
    sha: 830b246a0e5f20af87141b25c173cd1b609bd7779a4617d6ec582abaf90870f3
  - kind: registry
    name: object
    version: 0.37.3
    sha: ff76201f031d8863c38aa7f905eca4f53abbfa15f609db4277d44cd8938f33fe
  - kind: registry
    name: oci-spec
    version: 0.10.0
    sha: 3df6f876ad774d6a676f7e968f5c3edacc32f90e65fe680a8b686235396556fb
  - kind: registry
    name: oci-spec
    version: 0.9.0
    sha: e8445a2631507cec628a15fdd6154b54a3ab3f20ed4fe9d73a3b8b7a4e1ba03a
  - kind: registry
    name: ocidir
    version: 0.7.2
    sha: bdb92f511503ca78a6b3c2a5415c49aa9bb03169d2715f67b1c0dc1654ed9636
  - kind: registry
    name: once_cell
    version: 1.21.4
    sha: 9f7c3e4beb33f85d45ae3e3a1792185706c8e16d043238c593331cc7cd313b50
  - kind: registry
    name: once_cell_polyfill
    version: 1.70.2
    sha: 384b8ab6d37215f3c5301a95a4accb5d64aa607f1fcb26a11b5303878451b4fe
  - kind: registry
    name: openssh-keys
    version: 0.6.5
    sha: 351339c4d45e6bdf2defef3ef1ce0b153810bd59b171b92b6a42e7bb0f32a4ad
  - kind: registry
    name: openssl
    version: 0.10.78
    sha: f38c4372413cdaaf3cc79dd92d29d7d9f5ab09b51b10dded508fb90bb70b9222
  - kind: registry
    name: openssl-macros
    version: 0.1.1
    sha: a948666b637a0f465e8564c73e89d4dde00d72d4d473cc972f390fc3dcee7d9c
  - kind: registry
    name: openssl-sys
    version: 0.9.114
    sha: 13ce1245cd07fcc4cfdb438f7507b0c7e4f3849a69fd84d52374c66d83741bb6
  - kind: registry
    name: ostree
    version: 0.20.5
    sha: fc7b42858b9c42999daefaf06f2a60a0dfbb6995a7b87deb0a873f2fb447c269
  - kind: registry
    name: ostree-sys
    version: 0.15.3
    sha: 7aaaff741a79d31706e713a3971cfc670dfd969321e758b758b3fe79e3cdad49
  - kind: registry
    name: owo-colors
    version: 4.3.0
    sha: d211803b9b6b570f68772237e415a029d5a50c65d382910b879fb19d3271f94d
  - kind: registry
    name: parking_lot
    version: 0.12.5
    sha: 93857453250e3077bd71ff98b6a65ea6621a19bb0f559a85248955ac12c45a1a
  - kind: registry
    name: parking_lot_core
    version: 0.9.12
    sha: 2621685985a2ebf1c516881c026032ac7deafcda1a2c9b7850dc81e3dfcb64c1
  - kind: registry
    name: percent-encoding
    version: 2.3.2
    sha: 9b4f627cb1b25917193a259e49bdad08f671f8d9708acfd5fe0a8c1455d87220
  - kind: registry
    name: pin-project
    version: 1.1.11
    sha: f1749c7ed4bcaf4c3d0a3efc28538844fb29bcdd7d2b67b2be7e20ba861ff517
  - kind: registry
    name: pin-project-internal
    version: 1.1.11
    sha: d9b20ed30f105399776b9c883e68e536ef602a16ae6f596d2c473591d6ad64c6
  - kind: registry
    name: pin-project-lite
    version: 0.2.17
    sha: a89322df9ebe1c1578d689c92318e070967d1042b512afbe49518723f4e6d5cd
  - kind: registry
    name: pkg-config
    version: 0.3.33
    sha: 19f132c84eca552bf34cab8ec81f1c1dcc229b811638f9d283dceabe58c5569e
  - kind: registry
    name: plain
    version: 0.2.3
    sha: b4596b6d070b27117e987119b4dac604f3c58cfb0b191112e24771b2faeac1a6
  - kind: registry
    name: portable-atomic
    version: 1.13.1
    sha: c33a9471896f1c69cecef8d20cbe2f7accd12527ce60845ff44c153bb2a21b49
  - kind: registry
    name: ppv-lite86
    version: 0.2.21
    sha: 85eae3c4ed2f50dcfe72643da4befc30deadb458a9b590d720cde2f2b1e97da9
  - kind: registry
    name: prettyplease
    version: 0.2.37
    sha: 479ca8adacdd7ce8f1fb39ce9ecccbfe93a3f1344b3d0d97f20bc0196208f62b
  - kind: registry
    name: proc-macro-crate
    version: 3.5.0
    sha: e67ba7e9b2b56446f1d419b1d807906278ffa1a658a8a5d8a39dcb1f5a78614f
  - kind: registry
    name: proc-macro-error-attr2
    version: 2.0.0
    sha: 96de42df36bb9bba5542fe9f1a054b8cc87e172759a1868aa05c1f3acc89dfc5
  - kind: registry
    name: proc-macro-error2
    version: 2.0.1
    sha: 11ec05c52be0a07b08061f7dd003e7d7092e0472bc731b4af7bb1ef876109802
  - kind: registry
    name: proc-macro2
    version: 1.0.106
    sha: 8fd00f0bb2e90d81d1044c2b32617f68fcb9fa3bb7640c23e9c748e53fb30934
  - kind: registry
    name: pulldown-cmark
    version: 0.13.3
    sha: 7c3a14896dfa883796f1cb410461aef38810ea05f2b2c33c5aded3649095fdad
  - kind: registry
    name: pulldown-cmark-escape
    version: 0.11.0
    sha: 007d8adb5ddab6f8e3f491ac63566a7d5002cc7ed73901f72057943fa71ae1ae
  - kind: registry
    name: quickcheck
    version: 1.1.0
    sha: 95c589f335db0f6aaa168a7cd27b1fc6920f5e1470c804f814d9cd6e62a0f70b
  - kind: registry
    name: quote
    version: 1.0.45
    sha: 41f2619966050689382d2b44f664f4bc593e129785a36d6ee376ddf37259b924
  - kind: registry
    name: r-efi
    version: 5.3.0
    sha: 69cdb34c158ceb288df11e18b4bd39de994f6657d83847bdffdbd7f346754b0f
  - kind: registry
    name: r-efi
    version: 6.0.0
    sha: f8dcc9c7d52a811697d2151c701e0d08956f92b0e24136cf4cf27b57a6a0d9bf
  - kind: registry
    name: rand
    version: 0.10.1
    sha: d2e8e8bcc7961af1fdac401278c6a831614941f6164ee3bf4ce61b7edb162207
  - kind: registry
    name: rand
    version: 0.8.6
    sha: 5ca0ecfa931c29007047d1bc58e623ab12e5590e8c7cc53200d5202b69266d8a
  - kind: registry
    name: rand
    version: 0.9.4
    sha: 44c5af06bb1b7d3216d91932aed5265164bf384dc89cd6ba05cf59a35f5f76ea
  - kind: registry
    name: rand_chacha
    version: 0.3.1
    sha: e6c10a63a0fa32252be49d21e7709d4d4baf8d231c2dbce1eaa8141b9b127d88
  - kind: registry
    name: rand_chacha
    version: 0.9.0
    sha: d3022b5f1df60f26e1ffddd6c66e8aa15de382ae63b3a0c1bfc0e4d3e3f325cb
  - kind: registry
    name: rand_core
    version: 0.10.1
    sha: 63b8176103e19a2643978565ca18b50549f6101881c443590420e4dc998a3c69
  - kind: registry
    name: rand_core
    version: 0.6.4
    sha: ec0be4795e2f6a28069bec0b5ff3e2ac9bafc99e6a9a7dc3547996c5c816922c
  - kind: registry
    name: rand_core
    version: 0.9.5
    sha: 76afc826de14238e6e8c374ddcc1fa19e374fd8dd986b0d2af0d02377261d83c
  - kind: registry
    name: redox_syscall
    version: 0.5.18
    sha: ed2bf2547551a7053d6fdfafda3f938979645c44812fbfcda098faae3f1a362d
  - kind: registry
    name: redox_syscall
    version: 0.7.4
    sha: f450ad9c3b1da563fb6948a8e0fb0fb9269711c9c73d9ea1de5058c79c8d643a
  - kind: registry
    name: ref-cast
    version: 1.0.25
    sha: f354300ae66f76f1c85c5f84693f0ce81d747e2c3f21a45fef496d89c960bf7d
  - kind: registry
    name: ref-cast-impl
    version: 1.0.25
    sha: b7186006dcb21920990093f30e3dea63b7d6e977bf1256be20c3563a5db070da
  - kind: registry
    name: regex
    version: 1.12.3
    sha: e10754a14b9137dd7b1e3e5b0493cc9171fdd105e0ab477f51b72e7f3ac0e276
  - kind: registry
    name: regex-automata
    version: 0.4.14
    sha: 6e1dd4122fc1595e8162618945476892eefca7b88c52820e74af6262213cae8f
  - kind: registry
    name: regex-syntax
    version: 0.8.10
    sha: dc897dd8d9e8bd1ed8cdad82b5966c3e0ecae09fb1907d58efaa013543185d0a
  - kind: registry
    name: rexpect
    version: 0.7.0
    sha: e459b12e442eb95f78b7e69bb2c3a64fc96f24d90dbc47fb028d94ffb26ce1e8
  - kind: registry
    name: roff
    version: 1.1.1
    sha: 323c417e1d9665a65b263ec744ba09030cfb277e9daa0b018a4ab62e57bc8189
  - kind: registry
    name: route-recognizer
    version: 0.3.1
    sha: afab94fb28594581f62d981211a9a4d53cc8130bbcbbb89a0440d9b8e81a7746
  - kind: registry
    name: rustc-demangle
    version: 0.1.27
    sha: b50b8869d9fc858ce7266cce0194bd74df58b9d0e3f6df3a9fc8eb470d95c09d
  - kind: registry
    name: rustc-hash
    version: 2.1.2
    sha: 94300abf3f1ae2e2b8ffb7b58043de3d399c73fa6f4b73826402a5c457614dbe
  - kind: registry
    name: rustc_version
    version: 0.4.1
    sha: cfcb3a22ef46e85b45de6ee7e79d063319ebb6594faafcf1c225ea92ab6e9b92
  - kind: registry
    name: rustix
    version: 1.1.4
    sha: b6fe4565b9518b83ef4f91bb47ce29620ca828bd32cb7e408f0062e9930ba190
  - kind: registry
    name: rustix-linux-procfs
    version: 0.1.1
    sha: 2fc84bf7e9aa16c4f2c758f27412dc9841341e16aa682d9c7ac308fe3ee12056
  - kind: registry
    name: rustversion
    version: 1.0.22
    sha: b39cdef0fa800fc44525c84ccb54a029961a8215f9619753635a9c0d2538d46d
  - kind: registry
    name: ryu
    version: 1.0.23
    sha: 9774ba4a74de5f7b1c1451ed6cd5285a32eddb5cccb8cc655a4e50009e06477f
  - kind: registry
    name: schemars
    version: 1.2.1
    sha: a2b42f36aa1cd011945615b92222f6bf73c599a102a300334cd7f8dbeec726cc
  - kind: registry
    name: schemars_derive
    version: 1.2.1
    sha: 7d115b50f4aaeea07e79c1912f645c7513d81715d0420f8bc77a18c6260b307f
  - kind: registry
    name: scopeguard
    version: 1.2.0
    sha: 94143f37725109f92c262ed2cf5e59bce7498c01bcc1502d7b9afe439a4e9f49
  - kind: registry
    name: semver
    version: 1.0.28
    sha: 8a7852d02fc848982e0c167ef163aaff9cd91dc640ba85e263cb1ce46fae51cd
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
    name: serde_derive_internals
    version: 0.29.1
    sha: 18d26a20a969b9e3fdf2fc2d9f21eda6c40e2de84c9408bb5d3b05d499aae711
  - kind: registry
    name: serde_ignored
    version: 0.1.14
    sha: 115dffd5f3853e06e746965a20dcbae6ee747ae30b543d91b0e089668bb07798
  - kind: registry
    name: serde_json
    version: 1.0.149
    sha: 83fc039473c5595ace860d8c4fafa220ff474b3fc6bfdb4293327f1a37e94d86
  - kind: registry
    name: serde_spanned
    version: 0.6.9
    sha: bf41e0cfaf7226dca15e8197172c295a782857fcb97fad1808a166870dee75a3
  - kind: registry
    name: serde_spanned
    version: 1.1.1
    sha: 6662b5879511e06e8999a8a235d848113e942c9124f211511b16466ee2995f26
  - kind: registry
    name: serde_yaml
    version: 0.9.34+deprecated
    sha: 6a8b1a1a2ebf674015cc02edccce75287f1a0130d394307b36743c2f5d504b47
  - kind: registry
    name: sha1
    version: 0.10.6
    sha: e3bf829a2d51ab4a5ddf1352d8470c140cadc8301b2ae1789db023f01cedd6ba
  - kind: registry
    name: sha2
    version: 0.10.9
    sha: a7507d819769d01a365ab707794a4084392c824f54a7a6a7862f8c3d0892b283
  - kind: registry
    name: sha2
    version: 0.11.0
    sha: 446ba717509524cb3f22f17ecc096f10f4822d76ab5c0b9822c5f9c284e825f4
  - kind: registry
    name: sharded-slab
    version: 0.1.7
    sha: f40ca3c46823713e0d4209592e8d6e826aa57e928f09752619fc696c499637f6
  - kind: registry
    name: shell-words
    version: 1.1.1
    sha: dc6fe69c597f9c37bfeeeeeb33da3530379845f10be461a66d16d03eca2ded77
  - kind: registry
    name: shlex
    version: 1.3.0
    sha: 0fda2ff0d084019ba4d7c6f371c95d8fd75ce3524c3cb8fb653a3023f6323e64
  - kind: registry
    name: shlex
    version: 2.0.0
    sha: 7f70fe4c6ac787e57441913f82b210e668fb2033613bc7a76909cd8afce8bb1f
  - kind: registry
    name: signal-hook
    version: 0.3.18
    sha: d881a16cf4426aa584979d30bd82cb33429027e42122b169753d6ef1085ed6e2
  - kind: registry
    name: signal-hook-mio
    version: 0.2.5
    sha: b75a19a7a740b25bc7944bdee6172368f988763b744e3d4dfe753f6b4ece40cc
  - kind: registry
    name: signal-hook-registry
    version: 1.4.8
    sha: c4db69cba1110affc0e9f7bcd48bbf87b3f4fc7c61fc9155afd4c469eb3d6c1b
  - kind: registry
    name: simd-adler32
    version: 0.3.9
    sha: 703d5c7ef118737c72f1af64ad2f6f8c5e1921f818cdcb97b8fe6fc69bf66214
  - kind: registry
    name: similar
    version: 3.1.0
    sha: 04d93e861ede2e497b47833469b8ec9d5c07fa4c78ce7a00f6eb7dd8168b4b3f
  - kind: registry
    name: similar-asserts
    version: 2.0.0
    sha: 997e6ca38e97437973fc9f7f50a50d1274cacd874341a4960fea90067291038c
  - kind: registry
    name: slab
    version: 0.4.12
    sha: 0c790de23124f9ab44544d7ac05d60440adc586479ce501c1d6d7da3cd8c9cf5
  - kind: registry
    name: smallvec
    version: 1.15.1
    sha: 67b1b7a3b5fe4f1376887184045fcf45c69e92af734b7aaddc05fb777b6fbd03
  - kind: registry
    name: socket2
    version: 0.6.3
    sha: 3a766e1110788c36f4fa1c2b71b387a7815aa65f88ce0229841826633d93723e
  - kind: registry
    name: soketto
    version: 0.8.1
    sha: 2e859df029d160cb88608f5d7df7fb4753fd20fdfb4de5644f3d8b8440841721
  - kind: registry
    name: static_assertions
    version: 1.1.0
    sha: a2eb9349b6444b326872e140eb1cf5e7c522154d69e7a0ffb0fb81c06b37543f
  - kind: registry
    name: strsim
    version: 0.11.1
    sha: 7da8b5736845d9f2fcb837ea5d9e2628564b3b043a70948a3f0b778838c5fb4f
  - kind: registry
    name: strum
    version: 0.27.2
    sha: af23d6f6c1a224baef9d3f61e287d2761385a5b88fdab4eb4c6f11aeb54c4bcf
  - kind: registry
    name: strum_macros
    version: 0.27.2
    sha: 7695ce3845ea4b33927c055a39dc438a45b059f7c1b3d91d38d10355fb8cbca7
  - kind: registry
    name: subtle
    version: 2.6.1
    sha: 13c2bddecc57b384dee18652358fb23172facb8a2c51ccc10d74c157bdea3292
  - kind: registry
    name: syn
    version: 1.0.109
    sha: 72b64191b275b66ffe2469e8af2c1cfe3bafa67b529ead792a6d0160888b4237
  - kind: registry
    name: syn
    version: 2.0.117
    sha: e665b8803e7b1d2a727f4023456bbbbe74da67099c585258af0ad9c5013b9b99
  - kind: registry
    name: system-deps
    version: 7.0.8
    sha: 396a35feb67335377e0251fcbc1092fc85c484bd4e3a7a54319399da127796e7
  - kind: registry
    name: tar
    version: 0.4.45
    sha: 22692a6476a21fa75fdfc11d452fda482af402c008cdbaf3476414e122040973
  - kind: registry
    name: tar-core
    version: 0.1.0
    sha: a870b96d9b5bd13e81517d63a18da0f0c33de072eeb5a293a2e40f3830befa0e
  - kind: registry
    name: target-lexicon
    version: 0.13.3
    sha: df7f62577c25e07834649fc3b39fafdc597c0a3527dc1c60129201ccfcbaa50c
  - kind: registry
    name: tempfile
    version: 3.27.0
    sha: 32497e9a4c7b38532efcdebeef879707aa9f794296a4f0244f6f69e9bc8574bd
  - kind: registry
    name: terminal_size
    version: 0.4.4
    sha: 230a1b821ccbd75b185820a1f1ff7b14d21da1e442e22c0863ea5f08771a8874
  - kind: registry
    name: thiserror
    version: 1.0.69
    sha: b6aaf5339b578ea85b50e080feb250a3e8ae8cfcdff9a461c9ec2904bc923f52
  - kind: registry
    name: thiserror
    version: 2.0.18
    sha: 4288b5bcbc7920c07a1149a35cf9590a2aa808e0bc1eafaade0b80947865fbc4
  - kind: registry
    name: thiserror-impl
    version: 1.0.69
    sha: 4fee6c4efc90059e10f81e6d42c60a18f76588c3d74cb83a0b242a2b6c7504c1
  - kind: registry
    name: thiserror-impl
    version: 2.0.18
    sha: ebc4ee7f67670e9b64d05fa4253e753e016c6c95ff35b89b7941d6b856dec1d5
  - kind: registry
    name: thread_local
    version: 1.1.9
    sha: f60246a4944f24f6e018aa17cdeffb7818b76356965d03b07d6a9886e8962185
  - kind: registry
    name: tini
    version: 1.3.0
    sha: e004df4c5f0805eb5f55883204a514cfa43a6d924741be29e871753a53d5565a
  - kind: registry
    name: tokio
    version: 1.52.1
    sha: b67dee974fe86fd92cc45b7a95fdd2f99a36a6d7b0d431a231178d3d670bbcc6
  - kind: registry
    name: tokio-macros
    version: 2.7.0
    sha: 385a6cb71ab9ab790c5fe8d67f1645e6c450a7ce006a33de03daa956cf70a496
  - kind: registry
    name: tokio-stream
    version: 0.1.18
    sha: 32da49809aab5c3bc678af03902d4ccddea2a87d028d86392a4b1560c6906c70
  - kind: registry
    name: tokio-util
    version: 0.7.18
    sha: 9ae9cec805b01e8fc3fd2fe289f89149a9b66dd16786abd8b19cfa7b48cb0098
  - kind: registry
    name: toml
    version: 0.8.23
    sha: dc1beb996b9d83529a9e75c17a1686767d148d70663143c7854d8b4a09ced362
  - kind: registry
    name: toml
    version: 1.1.2+spec-1.1.0
    sha: 81f3d15e84cbcd896376e6730314d59fb5a87f31e4b038454184435cd57defee
  - kind: registry
    name: toml_datetime
    version: 0.6.11
    sha: 22cddaf88f4fbc13c51aebbf5f8eceb5c7c5a9da2ac40a13519eb5b0a0e8f11c
  - kind: registry
    name: toml_datetime
    version: 1.1.1+spec-1.1.0
    sha: 3165f65f62e28e0115a00b2ebdd37eb6f3b641855f9d636d3cd4103767159ad7
  - kind: registry
    name: toml_edit
    version: 0.22.27
    sha: 41fe8c660ae4257887cf66394862d21dbca4a6ddd26f04a3560410406a2f819a
  - kind: registry
    name: toml_edit
    version: 0.25.11+spec-1.1.0
    sha: 0b59c4d22ed448339746c59b905d24568fcbb3ab65a500494f7b8c3e97739f2b
  - kind: registry
    name: toml_parser
    version: 1.1.2+spec-1.1.0
    sha: a2abe9b86193656635d2411dc43050282ca48aa31c2451210f4202550afb7526
  - kind: registry
    name: toml_writer
    version: 1.1.1+spec-1.1.0
    sha: 756daf9b1013ebe47a8776667b466417e2d4c5679d441c26230efd9ef78692db
  - kind: registry
    name: tower
    version: 0.4.13
    sha: b8fa9be0de6cf49e536ce1851f987bd21a43b771b09473c3549a6c853db37c1c
  - kind: registry
    name: tower-layer
    version: 0.3.3
    sha: 121c2a6cda46980bb0fcd1647ffaf6cd3fc79a013de288782836f6df9c48780e
  - kind: registry
    name: tower-service
    version: 0.3.3
    sha: 8df9b6e13f2d32c91b9bd719c00d1958837bc7dec474d94952798cc8e69eeec3
  - kind: registry
    name: tracing
    version: 0.1.44
    sha: 63e71662fa4b2a2c3a26f570f037eb95bb1f85397f3cd8076caed2f026a6d100
  - kind: registry
    name: tracing-attributes
    version: 0.1.31
    sha: 7490cfa5ec963746568740651ac6781f701c9c5ea257c58e057f3ba8cf69e8da
  - kind: registry
    name: tracing-core
    version: 0.1.36
    sha: db97caf9d906fbde555dd62fa95ddba9eecfd14cb388e4f491a66d74cd5fb79a
  - kind: registry
    name: tracing-error
    version: 0.2.1
    sha: 8b1581020d7a273442f5b45074a6a57d5757ad0a47dac0e9f0bd57b81936f3db
  - kind: registry
    name: tracing-journald
    version: 0.3.2
    sha: 2d3a81ed245bfb62592b1e2bc153e77656d94ee6a0497683a65a12ccaf2438d0
  - kind: registry
    name: tracing-log
    version: 0.2.0
    sha: ee855f1f400bd0e5c02d150ae5de3840039a3f54b025156404e34c23c03f47c3
  - kind: registry
    name: tracing-subscriber
    version: 0.3.23
    sha: cb7f578e5945fb242538965c2d0b04418d38ec25c79d160cd279bf0731c8d319
  - kind: registry
    name: try-lock
    version: 0.2.5
    sha: e421abadd41a4225275504ea4d6566923418b7f05506fbc9c0fe86ba7396114b
  - kind: registry
    name: typenum
    version: 1.20.0
    sha: 40ce102ab67701b8526c123c1bab5cbe42d7040ccfd0f64af1a385808d2f43de
  - kind: registry
    name: uapi-version
    version: 0.4.0
    sha: 849f6b1fe8a0fb07170737d7f3acf72cac5462fb3f4e86614474a49f7fac3b65
  - kind: registry
    name: unicase
    version: 2.9.0
    sha: dbc4bc3a9f746d862c45cb89d705aa10f187bb96c76001afab07a0d35ce60142
  - kind: registry
    name: unicode-ident
    version: 1.0.24
    sha: e6e4313cd5fcd3dad5cafa179702e2b244f760991f45397d14d4ebf38247da75
  - kind: registry
    name: unicode-segmentation
    version: 1.13.2
    sha: 9629274872b2bfaf8d66f5f15725007f635594914870f65218920345aa11aa8c
  - kind: registry
    name: unicode-width
    version: 0.2.2
    sha: b4ac048d71ede7ee76d585517add45da530660ef4390e49b098733c6e897f254
  - kind: registry
    name: unicode-xid
    version: 0.2.6
    sha: ebc1c04c71510c7f702b52b7c350734c9ff1295c464a03335b00bb84fc54f853
  - kind: registry
    name: unit-prefix
    version: 0.5.2
    sha: 81e544489bf3d8ef66c953931f56617f423cd4b5494be343d9b9d3dda037b9a3
  - kind: registry
    name: unsafe-libyaml
    version: 0.2.11
    sha: 673aac59facbab8a9007c7f6108d11f63b603f7cabff99fabf650fea5c32b861
  - kind: registry
    name: utf8parse
    version: 0.2.2
    sha: 06abde3611657adf66d383f00b093d7faecc7fa57071cce2578660c9f1010821
  - kind: registry
    name: uuid
    version: 1.23.1
    sha: ddd74a9687298c6858e9b88ec8935ec45d22e8fd5e6394fa1bd4e99a87789c76
  - kind: registry
    name: uzers
    version: 0.12.2
    sha: 0b8275fb1afee25b4111d2dc8b5c505dbbc4afd0b990cb96deb2d88bff8be18d
  - kind: registry
    name: valuable
    version: 0.1.1
    sha: ba73ea9cf16a25df0c8caa16c51acb937d5712a8429db78a3ee29d5dcacd3a65
  - kind: registry
    name: vcpkg
    version: 0.2.15
    sha: accd4ea62f7bb7a82fe23066fb0957d48ef677f6eeb8215f372f52e48bb32426
  - kind: registry
    name: version-compare
    version: 0.2.1
    sha: 03c2856837ef78f57382f06b2b8563a2f512f7185d732608fd9176cb3b8edf0e
  - kind: registry
    name: version_check
    version: 0.9.5
    sha: 0b928f33d975fc6ad9f86c8f283853ad26bdd5b10b7f1542aa2fa15e2289105a
  - kind: registry
    name: vsock
    version: 0.5.1
    sha: 4e8b4d00e672f147fc86a09738fadb1445bd1c0a40542378dfb82909deeee688
  - kind: registry
    name: want
    version: 0.3.1
    sha: bfa7760aed19e106de2c7c0b581b509f2f25d3dacaf737cb82ac61bc6d760b0e
  - kind: registry
    name: wasi
    version: 0.11.1+wasi-snapshot-preview1
    sha: ccf3ec651a847eb01de73ccad15eb7d99f80485de043efb2f370cd654f4ea44b
  - kind: registry
    name: wasip2
    version: 1.0.3+wasi-0.2.9
    sha: 20064672db26d7cdc89c7798c48a0fdfac8213434a1186e5ef29fd560ae223d6
  - kind: registry
    name: wasip3
    version: 0.4.0+wasi-0.3.0-rc-2026-01-06
    sha: 5428f8bf88ea5ddc08faddef2ac4a67e390b88186c703ce6dbd955e1c145aca5
  - kind: registry
    name: wasm-bindgen
    version: 0.2.118
    sha: 0bf938a0bacb0469e83c1e148908bd7d5a6010354cf4fb73279b7447422e3a89
  - kind: registry
    name: wasm-bindgen-macro
    version: 0.2.118
    sha: eeff24f84126c0ec2db7a449f0c2ec963c6a49efe0698c4242929da037ca28ed
  - kind: registry
    name: wasm-bindgen-macro-support
    version: 0.2.118
    sha: 9d08065faf983b2b80a79fd87d8254c409281cf7de75fc4b773019824196c904
  - kind: registry
    name: wasm-bindgen-shared
    version: 0.2.118
    sha: 5fd04d9e306f1907bd13c6361b5c6bfc7b3b3c095ed3f8a9246390f8dbdee129
  - kind: registry
    name: wasm-encoder
    version: 0.244.0
    sha: 990065f2fe63003fe337b932cfb5e3b80e0b4d0f5ff650e6985b1048f62c8319
  - kind: registry
    name: wasm-metadata
    version: 0.244.0
    sha: bb0e353e6a2fbdc176932bbaab493762eb1255a7900fe0fea1a2f96c296cc909
  - kind: registry
    name: wasmparser
    version: 0.244.0
    sha: 47b807c72e1bac69382b3a6fb3dbe8ea4c0ed87ff5629b8685ae6b9a611028fe
  - kind: registry
    name: web-time
    version: 1.1.0
    sha: 5a6580f308b1fad9207618087a65c04e7a10bc77e02c8e84e9b00dd4b12fa0bb
  - kind: registry
    name: which
    version: 8.0.2
    sha: 81995fafaaaf6ae47a7d0cc83c67caf92aeb7e5331650ae6ff856f7c0c60c459
  - kind: registry
    name: winapi
    version: 0.3.9
    sha: 5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419
  - kind: registry
    name: winapi-i686-pc-windows-gnu
    version: 0.4.0
    sha: ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6
  - kind: registry
    name: winapi-x86_64-pc-windows-gnu
    version: 0.4.0
    sha: 712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f
  - kind: registry
    name: windows-core
    version: 0.62.2
    sha: b8e83a14d34d0623b51dce9581199302a221863196a1dde71a7663a4c2be9deb
  - kind: registry
    name: windows-implement
    version: 0.60.2
    sha: 053e2e040ab57b9dc951b72c264860db7eb3b0200ba345b4e4c3b14f67855ddf
  - kind: registry
    name: windows-interface
    version: 0.59.3
    sha: 3f316c4a2570ba26bbec722032c4099d8c8bc095efccdc15688708623367e358
  - kind: registry
    name: windows-link
    version: 0.2.1
    sha: f0805222e57f7521d6a62e36fa9163bc891acd422f971defe97d64e70d0a4fe5
  - kind: registry
    name: windows-result
    version: 0.4.1
    sha: 7781fa89eaf60850ac3d2da7af8e5242a5ea78d1a11c49bf2910bb5a73853eb5
  - kind: registry
    name: windows-strings
    version: 0.5.1
    sha: 7837d08f69c77cf6b07689544538e017c1bfcf57e34b4c0ff58e6c2cd3b37091
  - kind: registry
    name: windows-sys
    version: 0.59.0
    sha: 1e38bc4d79ed67fd075bcc251a1c39b32a1776bbe92e5bef1f0bf1f8c531853b
  - kind: registry
    name: windows-sys
    version: 0.60.2
    sha: f2f500e4d28234f72040990ec9d39e3a6b950f9f22d3dba18416c35882612bcb
  - kind: registry
    name: windows-sys
    version: 0.61.2
    sha: ae137229bcbd6cdf0f7b80a31df61766145077ddf49416a728b02cb3921ff3fc
  - kind: registry
    name: windows-targets
    version: 0.52.6
    sha: 9b724f72796e036ab90c1021d4780d4d3d648aca59e491e6b98e725b84e99973
  - kind: registry
    name: windows-targets
    version: 0.53.5
    sha: 4945f9f551b88e0d65f3db0bc25c33b8acea4d9e41163edf90dcd0b19f9069f3
  - kind: registry
    name: windows_aarch64_gnullvm
    version: 0.52.6
    sha: 32a4622180e7a0ec044bb555404c800bc9fd9ec262ec147edd5989ccd0c02cd3
  - kind: registry
    name: windows_aarch64_gnullvm
    version: 0.53.1
    sha: a9d8416fa8b42f5c947f8482c43e7d89e73a173cead56d044f6a56104a6d1b53
  - kind: registry
    name: windows_aarch64_msvc
    version: 0.52.6
    sha: 09ec2a7bb152e2252b53fa7803150007879548bc709c039df7627cabbd05d469
  - kind: registry
    name: windows_aarch64_msvc
    version: 0.53.1
    sha: b9d782e804c2f632e395708e99a94275910eb9100b2114651e04744e9b125006
  - kind: registry
    name: windows_i686_gnu
    version: 0.52.6
    sha: 8e9b5ad5ab802e97eb8e295ac6720e509ee4c243f69d781394014ebfe8bbfa0b
  - kind: registry
    name: windows_i686_gnu
    version: 0.53.1
    sha: 960e6da069d81e09becb0ca57a65220ddff016ff2d6af6a223cf372a506593a3
  - kind: registry
    name: windows_i686_gnullvm
    version: 0.52.6
    sha: 0eee52d38c090b3caa76c563b86c3a4bd71ef1a819287c19d586d7334ae8ed66
  - kind: registry
    name: windows_i686_gnullvm
    version: 0.53.1
    sha: fa7359d10048f68ab8b09fa71c3daccfb0e9b559aed648a8f95469c27057180c
  - kind: registry
    name: windows_i686_msvc
    version: 0.52.6
    sha: 240948bc05c5e7c6dabba28bf89d89ffce3e303022809e73deaefe4f6ec56c66
  - kind: registry
    name: windows_i686_msvc
    version: 0.53.1
    sha: 1e7ac75179f18232fe9c285163565a57ef8d3c89254a30685b57d83a38d326c2
  - kind: registry
    name: windows_x86_64_gnu
    version: 0.52.6
    sha: 147a5c80aabfbf0c7d901cb5895d1de30ef2907eb21fbbab29ca94c5b08b1a78
  - kind: registry
    name: windows_x86_64_gnu
    version: 0.53.1
    sha: 9c3842cdd74a865a8066ab39c8a7a473c0778a3f29370b5fd6b4b9aa7df4a499
  - kind: registry
    name: windows_x86_64_gnullvm
    version: 0.52.6
    sha: 24d5b23dc417412679681396f2b49f3de8c1473deb516bd34410872eff51ed0d
  - kind: registry
    name: windows_x86_64_gnullvm
    version: 0.53.1
    sha: 0ffa179e2d07eee8ad8f57493436566c7cc30ac536a3379fdf008f47f6bb7ae1
  - kind: registry
    name: windows_x86_64_msvc
    version: 0.52.6
    sha: 589f6da84c646204747d1270a2a5661ea66ed1cced2631d546fdfb155959f9ec
  - kind: registry
    name: windows_x86_64_msvc
    version: 0.53.1
    sha: d6bbff5f0aada427a1e5a6da5f1f98158182f26556f345ac9e04d36d0ebed650
  - kind: registry
    name: winnow
    version: 0.7.15
    sha: df79d97927682d2fd8adb29682d1140b343be4ac0f08fd68b7765d9c059d3945
  - kind: registry
    name: winnow
    version: 1.0.2
    sha: 2ee1708bef14716a11bae175f579062d4554d95be2c6829f518df847b7b3fdd0
  - kind: registry
    name: winx
    version: 0.36.4
    sha: 3f3fd376f71958b862e7afb20cfe5a22830e1963462f3a17f49d82a6c1d1f42d
  - kind: registry
    name: wit-bindgen
    version: 0.51.0
    sha: d7249219f66ced02969388cf2bb044a09756a083d0fab1e566056b04d9fbcaa5
  - kind: registry
    name: wit-bindgen
    version: 0.57.1
    sha: 1ebf944e87a7c253233ad6766e082e3cd714b5d03812acc24c318f549614536e
  - kind: registry
    name: wit-bindgen-core
    version: 0.51.0
    sha: ea61de684c3ea68cb082b7a88508a8b27fcc8b797d738bfc99a82facf1d752dc
  - kind: registry
    name: wit-bindgen-rust
    version: 0.51.0
    sha: b7c566e0f4b284dd6561c786d9cb0142da491f46a9fbed79ea69cdad5db17f21
  - kind: registry
    name: wit-bindgen-rust-macro
    version: 0.51.0
    sha: 0c0f9bfd77e6a48eccf51359e3ae77140a7f50b1e2ebfe62422d8afdaffab17a
  - kind: registry
    name: wit-component
    version: 0.244.0
    sha: 9d66ea20e9553b30172b5e831994e35fbde2d165325bec84fc43dbf6f4eb9cb2
  - kind: registry
    name: wit-parser
    version: 0.244.0
    sha: ecc8ac4bc1dc3381b7f59c34f00b67e18f910c2c0f50015669dde7def656a736
  - kind: registry
    name: xattr
    version: 1.6.1
    sha: 32e45ad4206f6d2479085147f02bc2ef834ac85886624a23575ae137c8aa8156
  - kind: registry
    name: xshell
    version: 0.2.7
    sha: 9e7290c623014758632efe00737145b6867b66292c42167f2ec381eb566a373d
  - kind: registry
    name: xshell-macros
    version: 0.2.7
    sha: 32ac00cd3f8ec9c1d33fb3e7958a82df6989c42d747bd326c822b1d625283547
  - kind: registry
    name: xxhash-rust
    version: 0.8.15
    sha: fdd20c5420375476fbd4394763288da7eb0cc0b8c11deed431a91562af7335d3
  - kind: registry
    name: zerocopy
    version: 0.8.48
    sha: eed437bf9d6692032087e337407a86f04cd8d6a16a37199ed57949d415bd68e9
  - kind: registry
    name: zerocopy-derive
    version: 0.8.48
    sha: 70e3cd084b1788766f53af483dd21f93881ff30d7320490ec3ef7526d203bad4
  - kind: registry
    name: zeroize
    version: 1.8.2
    sha: b97154e67e32c85465826e8bcc1c59429aaaf107c1e4a9e53c8d8ccd5eff88d0
  - kind: registry
    name: zmij
    version: 1.0.21
    sha: b8848ee67ecc8aedbaf3e4122217aff892639231befc6a1b58d29fff4c2cabaa
  - kind: registry
    name: zstd
    version: 0.13.3
    sha: e91ee311a569c327171651566e07972200e76fcfe2242a4fa446149a3881c08a
  - kind: registry
    name: zstd-safe
    version: 7.2.4
    sha: 8f49c4d5f0abb602a93fb8736af2a4f4dd9512e36f7f570d66e65ff867ed3b9d
  - kind: registry
    name: zstd-sys
    version: 2.0.16+zstd.1.5.7
    sha: 91e19ebc2adc8f83e43039e79776e3fda8ca919132d68a1fed6a5faca2683748
build-depends:
- freedesktop-sdk.bst:components/go-md2man.bst
- freedesktop-sdk.bst:components/openssl.bst
- freedesktop-sdk.bst:components/pkg-config.bst
- freedesktop-sdk.bst:components/rust.bst
- freedesktop-sdk.bst:components/systemd.bst
- freedesktop-sdk.bst:components/zstd.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:components/composefs.bst
- freedesktop-sdk.bst:components/ostree.bst
- freedesktop-sdk.bst:components/podman.bst
- freedesktop-sdk.bst:components/skopeo.bst
- freedesktop-sdk.bst:components/util-linux.bst
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst

variables:
  make-install-args: >-
    PREFIX="%{prefix}" LIBDIR="%{lib}" DESTDIR="%{install-root}" install-all
