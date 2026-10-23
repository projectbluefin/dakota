# virtiofsd is QEMU's vhost-user virtio-fs backend. libvirt <filesystem
# driver='virtiofs'> shares and bcvk ephemeral VMs exec it; QEMU dropped its
# C implementation, and neither junction ships the Rust one.
kind: manual

build-depends:
- freedesktop-sdk.bst:components/rust.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
- freedesktop-sdk.bst:components/libcap-ng.bst
- freedesktop-sdk.bst:components/libseccomp.bst

config:
  build-commands:
  - cargo build --release --frozen --offline

  install-commands:
  # Upstream's QEMU vhost-user descriptor hardcodes /usr/libexec/virtiofsd.
  - install -Dm755 target/release/virtiofsd "%{install-root}%{libexecdir}/virtiofsd"
  - install -Dm644 50-virtiofsd.json "%{install-root}%{datadir}/qemu/vhost-user/50-virtiofsd.json"
  - install -Dm644 -t "%{install-root}%{datadir}/licenses/virtiofsd" LICENSE-APACHE LICENSE-BSD-3-Clause

sources:
- kind: git_repo
  url: gitlab:virtio-fs/virtiofsd.git
  track: 'v[0-9]*.[0-9]*.[0-9]*'
  ref: v1.14.0-0-gc2540f8db14caba81c1e37fba23fc7bf2cd7f0dd
- kind: cargo2
  url: crates:crates
  ref:
  - kind: registry
    name: aho-corasick
    version: 0.7.18
    sha: 1e37cfd5e7657ada45f742d6e99ca5788580b5c529dc78faf11ece6dc702656f
  - kind: registry
    name: anstream
    version: 0.3.2
    sha: 0ca84f3628370c59db74ee214b3263d58f9aadd9b4fe7e711fd87dc452b7f163
  - kind: registry
    name: anstyle
    version: 1.0.1
    sha: 3a30da5c5f2d5e72842e00bcb57657162cdabef0931f40e2deb9b4140440cecd
  - kind: registry
    name: anstyle-parse
    version: 0.2.1
    sha: 938874ff5980b03a87c5524b3ae5b59cf99b1d6bc836848df7bc5ada9643c333
  - kind: registry
    name: anstyle-query
    version: 1.0.0
    sha: 5ca11d4be1bab0c8bc8734a9aa7bf4ee8316d462a08c6ac5052f888fef5b494b
  - kind: registry
    name: anstyle-wincon
    version: 1.0.1
    sha: 180abfa45703aebe0093f79badacc01b8fd4ea2e35118747e5811127f926e188
  - kind: registry
    name: arc-swap
    version: 1.5.0
    sha: c5d78ce20460b82d3fa150275ed9d55e21064fc7951177baacf86a145c4a4b1f
  - kind: registry
    name: atomic-polyfill
    version: 0.1.11
    sha: e3ff7eb3f316534d83a8a2c3d1674ace8a5a71198eba31e2e2b597833f699b28
  - kind: registry
    name: atty
    version: 0.2.14
    sha: d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8
  - kind: registry
    name: autocfg
    version: 1.1.0
    sha: d468802bab17cbc0cc575e9b053f41e72aa36bfa6b7f55e3529ffa43161b97fa
  - kind: registry
    name: bitflags
    version: 1.3.2
    sha: bef38d45163c2f1dde094a7dfd33ccf595c92905c8f8f4fdc18d06fb1037718a
  - kind: registry
    name: bitflags
    version: 2.4.1
    sha: 327762f6e5a765692301e5bb513e0d9fef63be86bbc14528052b1cd3e6f03e07
  - kind: registry
    name: btree-range-map
    version: 0.7.2
    sha: 1be5c9672446d3800bcbcaabaeba121fe22f1fb25700c4562b22faf76d377c33
  - kind: registry
    name: btree-slab
    version: 0.6.1
    sha: 7a2b56d3029f075c4fa892428a098425b86cef5c89ae54073137ece416aef13c
  - kind: registry
    name: byteorder
    version: 1.4.3
    sha: 14c189c53d098945499cdfa7ecc63567cf3886b3332b312a5b4585d8d3a6a610
  - kind: registry
    name: capng
    version: 0.2.2
    sha: f6f8e9448233603643e42606121d95f5f8d4e015b3e7619a51593864dd902575
  - kind: registry
    name: cc
    version: 1.0.79
    sha: 50d30906286121d95be3d479533b458f87493b30a4b5f79a607db8f5d11aa91f
  - kind: registry
    name: cc-traits
    version: 2.0.0
    sha: 060303ef31ef4a522737e1b1ab68c67916f2a787bb2f4f54f383279adba962b5
  - kind: registry
    name: cfg-if
    version: 1.0.0
    sha: baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd
  - kind: registry
    name: clap
    version: 4.3.11
    sha: 1640e5cc7fb47dbb8338fd471b105e7ed6c3cb2aeb00c2e067127ffd3764a05d
  - kind: registry
    name: clap_builder
    version: 4.3.11
    sha: 98c59138d527eeaf9b53f35a77fcc1fad9d883116070c63d5de1c7dc7b00c72b
  - kind: registry
    name: clap_derive
    version: 4.3.2
    sha: b8cd2b2a819ad6eec39e8f1d6b53001af1e5469f8c177579cdaeb313115b825f
  - kind: registry
    name: clap_lex
    version: 0.5.0
    sha: 2da6da31387c7e4ef160ffab6d5e7f00c42626fe39aea70a7b0f1773f7dd6c1b
  - kind: registry
    name: cobs
    version: 0.2.3
    sha: 67ba02a97a2bd10f4b59b25c7973101c79642302776489e030cd13cdab09ed15
  - kind: registry
    name: colorchoice
    version: 1.0.0
    sha: acbf1af155f9b9ef647e42cdc158db4b64a1b61f743629225fde6f3e0be2a7c7
  - kind: registry
    name: critical-section
    version: 1.1.2
    sha: 7059fff8937831a9ae6f0fe4d658ffabf58f2ca96aa9dec1c889f936f705f216
  - kind: registry
    name: env_logger
    version: 0.8.4
    sha: a19187fea3ac7e84da7dacf48de0c45d63c6a76f9490dae389aead16c243fce3
  - kind: registry
    name: errno
    version: 0.3.1
    sha: 4bcfec3a70f97c962c307b2d2c56e358cf1d00b558d74262b5f929ee8cc7e73a
  - kind: registry
    name: errno-dragonfly
    version: 0.1.2
    sha: aa68f1b12764fab894d2755d2518754e71b4fd80ecfb822714a1206c2aab39bf
  - kind: registry
    name: error-chain
    version: 0.12.4
    sha: 2d2f06b9cac1506ece98fe3231e3cc9c4410ec3d5b1f24ae1c8946f0742cdefc
  - kind: registry
    name: futures
    version: 0.3.21
    sha: f73fe65f54d1e12b726f517d3e2135ca3125a437b6d998caf1962961f7172d9e
  - kind: registry
    name: futures-channel
    version: 0.3.21
    sha: c3083ce4b914124575708913bca19bfe887522d6e2e6d0952943f5eac4a74010
  - kind: registry
    name: futures-core
    version: 0.3.21
    sha: 0c09fd04b7e4073ac7156a9539b57a484a8ea920f79c7c675d05d289ab6110d3
  - kind: registry
    name: futures-executor
    version: 0.3.21
    sha: 9420b90cfa29e327d0429f19be13e7ddb68fa1cccb09d65e5706b8c7a749b8a6
  - kind: registry
    name: futures-io
    version: 0.3.21
    sha: fc4045962a5a5e935ee2fdedaa4e08284547402885ab326734432bed5d12966b
  - kind: registry
    name: futures-macro
    version: 0.3.21
    sha: 33c1e13800337f4d4d7a316bf45a567dbcb6ffe087f16424852d97e97a91f512
  - kind: registry
    name: futures-sink
    version: 0.3.21
    sha: 21163e139fa306126e6eedaf49ecdb4588f939600f0b1e770f4205ee4b7fa868
  - kind: registry
    name: futures-task
    version: 0.3.21
    sha: 57c66a976bf5909d801bbef33416c41372779507e7a6b3a5e25e4749c58f776a
  - kind: registry
    name: futures-util
    version: 0.3.21
    sha: d8b7abd5d659d9b90c8cba917f6ec750a74e2dc23902ef9cd4cc8c8b22e6036a
  - kind: registry
    name: getrandom
    version: 0.2.15
    sha: c4567c8db10ae91089c99af84c68c38da3ec2f087c3f82960bcdbf3656b6f4d7
  - kind: registry
    name: hash32
    version: 0.2.1
    sha: b0c35f58762feb77d74ebe43bdbc3210f09be9fe6742234d573bacc26ed92b67
  - kind: registry
    name: heapless
    version: 0.7.16
    sha: db04bc24a18b9ea980628ecf00e6c0264f3c1426dac36c00cb49b6fbad8b0743
  - kind: registry
    name: heck
    version: 0.4.1
    sha: 95505c38b4572b2d910cecb0281560f54b440a19336cbbcb27bf6ce6adc6f5a8
  - kind: registry
    name: hermit-abi
    version: 0.1.19
    sha: 62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33
  - kind: registry
    name: hermit-abi
    version: 0.3.2
    sha: 443144c8cdadd93ebf52ddb4056d257f5b52c04d3c804e657d19eb73fc33668b
  - kind: registry
    name: hostname
    version: 0.3.1
    sha: 3c731c3e10504cc8ed35cfe2f1db4c9274c3d35fa486e3b31df46f068ef3e867
  - kind: registry
    name: humantime
    version: 2.1.0
    sha: 9a3a5bfb195931eeb336b2a7b4d761daec841b97f947d34394601737a7bba5e4
  - kind: registry
    name: is-terminal
    version: 0.4.9
    sha: cb0889898416213fab133e1d33a0e5858a48177452750691bde3666d0fdbaf8b
  - kind: registry
    name: itoa
    version: 1.0.2
    sha: 112c678d4050afce233f4f2852bb2eb519230b3cf12f33585275537d7e41578d
  - kind: registry
    name: libc
    version: 0.2.177
    sha: 2874a2af47a2325c2001a6e6fad9b16a53b802102b528163885171cf92b15976
  - kind: registry
    name: libseccomp-sys
    version: 0.2.1
    sha: 9a7cbbd4ad467251987c6e5b47d53b11a5a05add08f2447a9e2d70aef1e0d138
  - kind: registry
    name: linux-raw-sys
    version: 0.4.5
    sha: 57bcfdad1b858c2db7c38303a6d2ad4dfaf5eb53dfeb0910128b2c26d6158503
  - kind: registry
    name: lock_api
    version: 0.4.10
    sha: c1cc9717a20b1bb222f333e6a92fd32f7d8a18ddc5a3191a11af45dcbf4dcd16
  - kind: registry
    name: log
    version: 0.4.17
    sha: abb12e687cfb44aa40f41fc3978ef76448f9b6038cad6aef4259d3c095a2382e
  - kind: registry
    name: match_cfg
    version: 0.1.0
    sha: ffbee8634e0d45d258acb448e7eaab3fce7a0a467395d4d9f228e3c1f01fb2e4
  - kind: registry
    name: memchr
    version: 2.5.0
    sha: 2dffe52ecf27772e601905b7522cb4ef790d2cc203488bbd0e2fe85fcb74566d
  - kind: registry
    name: num_cpus
    version: 1.13.1
    sha: 19e64526ebdee182341572e50e9ad03965aa510cd94427a4549448f285e957a1
  - kind: registry
    name: num_threads
    version: 0.1.6
    sha: 2819ce041d2ee131036f4fc9d6ae7ae125a3a40e97ba64d04fe799ad9dabbb44
  - kind: registry
    name: once_cell
    version: 1.18.0
    sha: dd8b5dd2ae5ed71462c540258bedcb51965123ad7e7ccf4b9a8cafaa4a63576d
  - kind: registry
    name: pin-project-lite
    version: 0.2.9
    sha: e0a7ae3ac2f1173085d398531c705756c94a4c56843785df85a60c1a0afac116
  - kind: registry
    name: pin-utils
    version: 0.1.0
    sha: 8b870d8c151b6f2fb93e84a13146138f05d02ed11c7e7c54f8826aaaf7c9f184
  - kind: registry
    name: postcard
    version: 1.0.6
    sha: c9ee729232311d3cd113749948b689627618133b1c5012b77342c1950b25eaeb
  - kind: registry
    name: ppv-lite86
    version: 0.2.20
    sha: 77957b295656769bb8ad2b6a6b09d897d94f05c41b069aede1fcdaa675eaea04
  - kind: registry
    name: proc-macro2
    version: 1.0.103
    sha: 5ee95bc4ef87b8d5ba32e8b7714ccc834865276eab0aed5c9958d00ec45f49e8
  - kind: registry
    name: quote
    version: 1.0.42
    sha: a338cc41d27e6cc6dce6cefc13a0729dfbb81c262b1f519331575dd80ef3067f
  - kind: registry
    name: rand
    version: 0.8.5
    sha: 34af8d1a0e25924bc5b7c43c079c942339d8f0a8b57c39049bef581b46327404
  - kind: registry
    name: rand_chacha
    version: 0.3.1
    sha: e6c10a63a0fa32252be49d21e7709d4d4baf8d231c2dbce1eaa8141b9b127d88
  - kind: registry
    name: rand_core
    version: 0.6.4
    sha: ec0be4795e2f6a28069bec0b5ff3e2ac9bafc99e6a9a7dc3547996c5c816922c
  - kind: registry
    name: range-traits
    version: 0.3.2
    sha: d20581732dd76fa913c7dff1a2412b714afe3573e94d41c34719de73337cc8ab
  - kind: registry
    name: regex
    version: 1.6.0
    sha: 4c4eb3267174b8c6c2f654116623910a0fef09c4753f8dd83db29c48a0df988b
  - kind: registry
    name: regex-syntax
    version: 0.6.27
    sha: a3f87b73ce11b1619a3c6332f45341e0047173771e8b8b73f87bfeefb7b56244
  - kind: registry
    name: rustc_version
    version: 0.4.0
    sha: bfa0f585226d2e68097d4f95d113b15b83a82e819ab25717ec0590d9584ef366
  - kind: registry
    name: rustix
    version: 0.38.7
    sha: 172891ebdceb05aa0005f533a6cbfca599ddd7d966f6f5d4d9b2e70478e70399
  - kind: registry
    name: scopeguard
    version: 1.2.0
    sha: 94143f37725109f92c262ed2cf5e59bce7498c01bcc1502d7b9afe439a4e9f49
  - kind: registry
    name: semver
    version: 1.0.18
    sha: b0293b4b29daaf487284529cc2f5675b8e57c61f70167ba415a463651fd6a918
  - kind: registry
    name: serde
    version: 1.0.168
    sha: d614f89548720367ded108b3c843be93f3a341e22d5674ca0dd5cd57f34926af
  - kind: registry
    name: serde_derive
    version: 1.0.168
    sha: d4fe589678c688e44177da4f27152ee2d190757271dc7f1d5b6b9f68d869d641
  - kind: registry
    name: slab
    version: 0.4.7
    sha: 4614a76b2a8be0058caa9dbbaf66d988527d86d003c11a94fbd335d7661edcef
  - kind: registry
    name: smallvec
    version: 1.13.2
    sha: 3c5e1a9a646d36c3599cd173a41282daf47c44583ad367b8e6837255952e5c67
  - kind: registry
    name: spin
    version: 0.9.8
    sha: 6980e8d7511241f8acf4aebddbb1ff938df5eebe98691418c4468d0b72a96a67
  - kind: registry
    name: stable_deref_trait
    version: 1.2.0
    sha: a8f112729512f8e442d81f95a8a7ddf2b7c6b8a1a6f509a95864142b30cab2d3
  - kind: registry
    name: strsim
    version: 0.10.0
    sha: 73473c0e59e6d5812c5dfe2a064a6444949f089e20eec9a2e5506596494e4623
  - kind: registry
    name: syn
    version: 1.0.98
    sha: c50aef8a904de4c23c788f104b7dddc7d6f79c647c7c8ce4cc8f73eb0ca773dd
  - kind: registry
    name: syn
    version: 2.0.111
    sha: 390cc9a294ab71bdb1aa2e99d13be9c753cd2d7bd6560c77118597410c4d2e87
  - kind: registry
    name: syslog
    version: 6.1.1
    sha: dfc7e95b5b795122fafe6519e27629b5ab4232c73ebb2428f568e82b1a457ad3
  - kind: registry
    name: termcolor
    version: 1.1.3
    sha: bab24d30b911b2376f3a13cc2cd443142f0c81dda04c118693e35b3835757755
  - kind: registry
    name: thiserror
    version: 2.0.17
    sha: f63587ca0f12b72a0600bcba1d40081f830876000bb46dd2337a3051618f4fc8
  - kind: registry
    name: thiserror-impl
    version: 2.0.17
    sha: 3ff15c8ecd7de3849db632e14d18d2571fa09dfc5ed93479bc4485c7a517c913
  - kind: registry
    name: time
    version: 0.3.11
    sha: 72c91f41dcb2f096c05f0873d667dceec1087ce5bcf984ec8ffb19acddbb3217
  - kind: registry
    name: unicode-ident
    version: 1.0.2
    sha: 15c61ba63f9235225a22310255a29b806b907c9b8c964bcbd0a2c70f3f2deea7
  - kind: registry
    name: utf8parse
    version: 0.2.1
    sha: 711b9620af191e0cdc7468a8d14e709c3dcdb115b36f838e601583af800a370a
  - kind: registry
    name: uuid
    version: 1.11.0
    sha: f8c5f0a0af699448548ad1a2fbf920fb4bee257eae39953ba95cb84891a0446a
  - kind: registry
    name: version_check
    version: 0.9.4
    sha: 49874b5167b65d7193b8aba1567f5c7d93d001cafc34600cee003eda787e483f
  - kind: registry
    name: vhost
    version: 0.16.0
    sha: ee90657203a8644e9a0860a0db6a7887d8ef0c7bc09fc22dfa4ae75df65bac86
  - kind: registry
    name: vhost-user-backend
    version: 0.22.0
    sha: d5925983d8fb537752ad3e26604c0a17abfa5de77cb6773a096c8a959c9eca0f
  - kind: registry
    name: virtio-bindings
    version: 0.2.7
    sha: 091f1f09cfbf2a78563b562e7a949465cce1aef63b6065645188d995162f8868
  - kind: registry
    name: virtio-queue
    version: 0.17.0
    sha: e358084f32ed165fddb41d98ff1b7ff3c08b9611d8d6114a1b422e2e85688baf
  - kind: registry
    name: vm-memory
    version: 0.17.1
    sha: f39348a049689cabd3377cdd9182bf526ec76a6f823b79903896452e9d7a7380
  - kind: registry
    name: vmm-sys-util
    version: 0.15.0
    sha: 506c62fdf617a5176827c2f9afbcf1be155b03a9b4bf9617a60dbc07e3a1642f
  - kind: registry
    name: wasi
    version: 0.11.0+wasi-snapshot-preview1
    sha: 9c8d87e72b64a3b4db28d11ce29237c246188f4f51057d65a7eab63b7987e423
  - kind: registry
    name: winapi
    version: 0.3.9
    sha: 5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419
  - kind: registry
    name: winapi-i686-pc-windows-gnu
    version: 0.4.0
    sha: ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6
  - kind: registry
    name: winapi-util
    version: 0.1.5
    sha: 70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178
  - kind: registry
    name: winapi-x86_64-pc-windows-gnu
    version: 0.4.0
    sha: 712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f
  - kind: registry
    name: windows-sys
    version: 0.48.0
    sha: 677d2418bec65e3338edb076e806bc1ec15693c5d0104683f2efe857f61056a9
  - kind: registry
    name: windows-targets
    version: 0.48.1
    sha: 05d4b17490f70499f20b9e791dcf6a299785ce8af4d709018206dc5b4953e95f
  - kind: registry
    name: windows_aarch64_gnullvm
    version: 0.48.0
    sha: 91ae572e1b79dba883e0d315474df7305d12f569b400fcf90581b06062f7e1bc
  - kind: registry
    name: windows_aarch64_msvc
    version: 0.48.0
    sha: b2ef27e0d7bdfcfc7b868b317c1d32c641a6fe4629c171b8928c7b08d98d7cf3
  - kind: registry
    name: windows_i686_gnu
    version: 0.48.0
    sha: 622a1962a7db830d6fd0a69683c80a18fda201879f0f447f065a3b7467daa241
  - kind: registry
    name: windows_i686_msvc
    version: 0.48.0
    sha: 4542c6e364ce21bf45d69fdd2a8e455fa38d316158cfd43b3ac1c5b1b19f8e00
  - kind: registry
    name: windows_x86_64_gnu
    version: 0.48.0
    sha: ca2b8a661f7628cbd23440e50b05d705db3686f894fc9580820623656af974b1
  - kind: registry
    name: windows_x86_64_gnullvm
    version: 0.48.0
    sha: 7896dbc1f41e08872e9d5e8f8baa8fdd2677f29468c4e156210174edc7f7b953
  - kind: registry
    name: windows_x86_64_msvc
    version: 0.48.0
    sha: 1a515f5799fe4961cb532f983ce2b23082366b898e52ffbce459c86f67c8378a
  - kind: registry
    name: zerocopy
    version: 0.7.35
    sha: 1b9b4fd18abc82b8136838da5d50bae7bdea537c574d8dc1a34ed098d6c166f0
  - kind: registry
    name: zerocopy-derive
    version: 0.7.35
    sha: fa4f8080344d4671fb4e831a13ad1e68092748387dfc4f55e356242fae12ce3e
