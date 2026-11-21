kind: make

config:
  build-commands:
  - cargo build --release --features feat_os_unix --no-default-features

  install-commands:
  - install -Dm755 target/release/coreutils "%{install-root}/usr/bin/uutils-coreutils"
  - |
    for prog in $(target/release/coreutils --list); do
      ln -sr "%{install-root}/usr/bin/uutils-coreutils" "%{install-root}/usr/bin/uutils-${prog}"
      # kill and uptime belong to procps-ng, not coreutils; GNU coreutils
      # does not install them either. Leave procps as their only provider.
      # env stays GNU: pkexec realpath()s its target, and the multicall
      # binary dispatches on the executed path, so a symlinked env breaks
      # `pkexec -u <user> /usr/bin/env <cmd>` (used by uupd).
      case "${prog}" in
        kill|uptime|env) continue ;;
      esac
      ln -sr "%{install-root}/usr/bin/uutils-coreutils" "%{install-root}/usr/bin/${prog}"
    done

public:
  bst:
    overlap-whitelist:
    - /usr/bin/[
    - /usr/bin/arch
    - /usr/bin/b2sum
    - /usr/bin/base32
    - /usr/bin/base64
    - /usr/bin/basename
    - /usr/bin/basenc
    - /usr/bin/cat
    - /usr/bin/chgrp
    - /usr/bin/chmod
    - /usr/bin/chown
    - /usr/bin/chroot
    - /usr/bin/cksum
    - /usr/bin/comm
    - /usr/bin/cp
    - /usr/bin/csplit
    - /usr/bin/cut
    - /usr/bin/date
    - /usr/bin/dd
    - /usr/bin/df
    - /usr/bin/dir
    - /usr/bin/dircolors
    - /usr/bin/dirname
    - /usr/bin/du
    - /usr/bin/echo
    - /usr/bin/expand
    - /usr/bin/expr
    - /usr/bin/factor
    - /usr/bin/false
    - /usr/bin/fmt
    - /usr/bin/fold
    - /usr/bin/groups
    - /usr/bin/head
    - /usr/bin/hostid
    - /usr/bin/hostname
    - /usr/bin/id
    - /usr/bin/install
    - /usr/bin/join
    - /usr/bin/link
    - /usr/bin/ln
    - /usr/bin/logname
    - /usr/bin/ls
    - /usr/bin/md5sum
    - /usr/bin/mkdir
    - /usr/bin/mkfifo
    - /usr/bin/mknod
    - /usr/bin/mktemp
    - /usr/bin/more
    - /usr/bin/mv
    - /usr/bin/nice
    - /usr/bin/nl
    - /usr/bin/nohup
    - /usr/bin/nproc
    - /usr/bin/numfmt
    - /usr/bin/od
    - /usr/bin/paste
    - /usr/bin/pathchk
    - /usr/bin/pinky
    - /usr/bin/pr
    - /usr/bin/printenv
    - /usr/bin/printf
    - /usr/bin/ptx
    - /usr/bin/pwd
    - /usr/bin/readlink
    - /usr/bin/realpath
    - /usr/bin/rm
    - /usr/bin/rmdir
    - /usr/bin/seq
    - /usr/bin/sha1sum
    - /usr/bin/sha224sum
    - /usr/bin/sha256sum
    - /usr/bin/sha384sum
    - /usr/bin/sha512sum
    - /usr/bin/shred
    - /usr/bin/shuf
    - /usr/bin/sleep
    - /usr/bin/sort
    - /usr/bin/split
    - /usr/bin/stat
    - /usr/bin/stdbuf
    - /usr/bin/stty
    - /usr/bin/sum
    - /usr/bin/sync
    - /usr/bin/tac
    - /usr/bin/tail
    - /usr/bin/tee
    - /usr/bin/test
    - /usr/bin/timeout
    - /usr/bin/touch
    - /usr/bin/tr
    - /usr/bin/true
    - /usr/bin/truncate
    - /usr/bin/tsort
    - /usr/bin/tty
    - /usr/bin/uname
    - /usr/bin/unexpand
    - /usr/bin/uniq
    - /usr/bin/unlink
    - /usr/bin/users
    - /usr/bin/vdir
    - /usr/bin/wc
    - /usr/bin/who
    - /usr/bin/whoami
    - /usr/bin/yes

build-depends:
- freedesktop-sdk.bst:components/rust.bst
- freedesktop-sdk.bst:public-stacks/buildsystem-make.bst

depends:
- freedesktop-sdk.bst:public-stacks/runtime-minimal.bst
# uutils replaces GNU coreutils by overwriting the same /usr/bin paths, and a
# compose keeps whichever element stages last. Depending on GNU coreutils makes
# it stage first, so uutils wins regardless of how the junctions order the rest
# of the graph (freedesktop-sdk 26.08 moved GNU coreutils out of runtime-minimal,
# which silently let it win).
- freedesktop-sdk.bst:bootstrap/coreutils.bst

sources:
- kind: git_repo
  url: github:uutils/coreutils.git
  track: '[0-9]*.[0-9]*.[0-9]*'
  ref: 0.13.0-0-g07b76df463390fd56856725201ae52df5df0a063 # 0.8.0
- kind: cargo2
  url: crates:crates
  ref:
  - kind: registry
    name: aho-corasick
    version: 1.1.5
    sha: c982642fa9e8606056828ee9a8505737230110bb1099153c79efe865c59d12ba
  - kind: registry
    name: allocator-api2
    version: 0.2.21
    sha: 683d7910e743518b0e34f1186f92494becacb047c7b6bf616c96772180fef923
  - kind: registry
    name: ansi-width
    version: 0.1.1
    sha: 90759a65f5178dbbd1b0eecc97b187996401bced0eb4a943d9ac6d7a6304d111
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
    version: 1.0.104
    sha: 330a5ed07fa54e4702c9d6c4174f74427fc0ef6e214bbd677ae50a5099946470
  - kind: registry
    name: approx
    version: 0.5.1
    sha: cab112f0a86d568ea0e627cc1d6be74a1e9cd55214684db5561995f6dad897c6
  - kind: registry
    name: ariadne
    version: 0.6.0
    sha: 8454c8a44ce2cb9cc7e7fae67fc6128465b343b92c6631e94beca3c8d1524ea5
  - kind: registry
    name: arrayvec
    version: 0.7.8
    sha: d3fb67a6e08acf24fdeccbac2cb6ac4305825bd1f117462e0e6f2f193345ad56
  - kind: registry
    name: autocfg
    version: 1.5.1
    sha: f2032f911046de80f0a198e0901378627c33f59ea0ac00e363d481118bd70a53
  - kind: registry
    name: aws-lc-sys
    version: 0.41.0
    sha: 1a2f9779ce85b93ab6170dd940ad0169b5766ff848247aff13bb788b832fe3f4
  - kind: registry
    name: base64-simd
    version: 0.8.0
    sha: 339abbe78e73178762e23bea9dfd08e697eb3f3301cd4be981c0f78ba5859195
  - kind: registry
    name: bigdecimal
    version: 0.4.11
    sha: 8fa3f3d8cbf4dffcfe4991de61d012bef509a409ecbe9dd41049bfe32b4d4653
  - kind: registry
    name: bindgen
    version: 0.72.1
    sha: 993776b509cfb49c750f11b8f07a46fa23e0a1386ffc01fb1e7d343efc387895
  - kind: registry
    name: bit-set
    version: 0.8.0
    sha: 08807e080ed7f9d5433fa9b275196cfc35414f66a0c79d864dc51a0d825231a3
  - kind: registry
    name: bit-vec
    version: 0.8.0
    sha: 5e764a1d40d510daf35e07be9eb06e75770908c27d411ee6c92109c9840eaaf7
  - kind: registry
    name: bitflags
    version: 2.13.2
    sha: 3ded4057c258ba199e2d26386d3af3780957ecaee6c4ef4041c6b4b8b97c0b06
  - kind: registry
    name: bitvec
    version: 1.1.1
    sha: ddcec3d12c579d40898fe0a9a358a803c23e9c52ca3c425707f81c9436211837
  - kind: registry
    name: blake2b_simd
    version: 1.0.5
    sha: 3560a7b1951efe814fcd721938313adc56753ca39f4b23847d7e9a2402f5dbff
  - kind: registry
    name: blake3
    version: 1.8.7
    sha: 6d9e454fc11f76977dc803893aff6304ed33d6a26efae8696573bea74baa27ae
  - kind: registry
    name: block-buffer
    version: 0.12.1
    sha: d2f6c7dbe95a6ed67ad9f18e57daf93a2f034c524b99fd2b76d18fdfeb6660aa
  - kind: registry
    name: block2
    version: 0.6.2
    sha: cdeb9d870516001442e364c5220d3574d2da8dc765554b4a617230d33fa58ef5
  - kind: registry
    name: bstr
    version: 1.13.1
    sha: 6bb31b46c14244e20ee9984b11bf5c992b91fb6939fea616e3512c8baecdbe5f
  - kind: registry
    name: bumpalo
    version: 3.20.3
    sha: 72f5acc6cb2ba439de613abc23857ec3d78374d8ed5ac84e9d11336e87da8649
  - kind: registry
    name: bytecount
    version: 0.6.9
    sha: 175812e0be2bccb6abe50bb8d566126198344f707e304f45c648fd8f2cc0365e
  - kind: registry
    name: calendrical_calculations
    version: 0.2.4
    sha: 5abbd6eeda6885048d357edc66748eea6e0268e3dd11f326fff5bd248d779c26
  - kind: registry
    name: cc
    version: 1.4.7
    sha: 54413ede23c2daf518f35156dfde027feb2374004d63bd497f983c8db9c0e313
  - kind: registry
    name: cexpr
    version: 0.6.0
    sha: 6fac387a98bb7c37292057cffc56d62ecb629900026402633ae9160df93a8766
  - kind: registry
    name: cfg-if
    version: 1.0.5
    sha: 4e7648175b45a9a48536d676f68d918270699102aa8dab5496df06904c914600
  - kind: registry
    name: cfg_aliases
    version: 0.2.2
    sha: f079e83a288787bcd14a6aea84cee5c87a67c5a3e660c30f557a3d24761b3527
  - kind: registry
    name: chacha20
    version: 0.10.2
    sha: 65c35e4b699c7e15ccbe7ee35c005e4fc0a278d22238a2857e6ce2dadeda1b06
  - kind: registry
    name: clang-sys
    version: 1.9.1
    sha: 157a8ba7b480713b56f4c09fd13fc3e0a22a5dfab8097ba61cbc5feef950788a
  - kind: registry
    name: clap
    version: 4.6.8
    sha: ac230478587d0269d8d6998b82ae69ea51509d55df66d9e92edd1f986904cd4a
  - kind: registry
    name: clap_builder
    version: 4.6.7
    sha: ec0797fb7aeb1406c84efac526901f7ec3ead2124f946b494e72879d4b54704d
  - kind: registry
    name: clap_complete
    version: 4.6.12
    sha: 6a35200383f20018d41c14d1ab19c1727c697f544492143f7d93aa39f0187848
  - kind: registry
    name: clap_lex
    version: 1.1.1
    sha: 1c133bc6a41be0d194c306b5506d15e6feeea7b1d6604bd3f8310dfb2ca96486
  - kind: registry
    name: clap_mangen
    version: 0.3.4
    sha: a3b6a8907b1723f211693e27b9af5899b86a9512ef5b08bd4a15b6bceb30da6d
  - kind: registry
    name: cmake
    version: 0.1.58
    sha: c0f78a02292a74a88ac736019ab962ece0bc380e3f977bf72e376c5d78ff0678
  - kind: registry
    name: codspeed
    version: 5.0.3
    sha: 1cade51e6e6e30e7ea2cd9599fa5d5d5f48255a6b221bbd0cab1cf32f3c23c65
  - kind: registry
    name: codspeed-divan-compat
    version: 5.0.3
    sha: 03b0fd97311e4e732bd4ec1c04fe8aa69354f4331810d161f70b5170b72656de
  - kind: registry
    name: codspeed-divan-compat-macros
    version: 5.0.3
    sha: 1dd3e854683dd16bb2df9da578fa5f78793f7053fc284e506d9c788dc521a1fb
  - kind: registry
    name: codspeed-divan-compat-walltime
    version: 5.0.3
    sha: deccfff88999b6a27304b8fec11ee92c698380e1612d015eb10f1bc2328e8a42
  - kind: registry
    name: colorchoice
    version: 1.0.5
    sha: 1d07550c9036bf2ae0c684c4297d503f838287c83c53686d05370d0e139ae570
  - kind: registry
    name: colored
    version: 3.1.1
    sha: faf9468729b8cbcea668e36183cb69d317348c2e08e994829fb56ebfdfbaac34
  - kind: registry
    name: condtype
    version: 1.3.0
    sha: baf0a07a401f374238ab8e2f11a104d2851bf9ce711ec69804834de8af45c7af
  - kind: registry
    name: console
    version: 0.16.6
    sha: e96a4956774c13c126a8b5af4daa79384f4d826534c95a02d76afb39e2ab64e3
  - kind: registry
    name: constant_time_eq
    version: 0.4.2
    sha: 3d52eff69cd5e647efe296129160853a42795992097e8af39800e1060caeea9b
  - kind: registry
    name: constant_time_eq
    version: 0.6.1
    sha: 9eb6feb175df65d0a3ccd3e73484e940d0ac664e8034f0519fd49a93db3071d9
  - kind: registry
    name: core_maths
    version: 0.1.1
    sha: 77745e017f5edba1a9c1d854f6f3a52dac8a12dd5af5d2f54aecf61e43d80d30
  - kind: registry
    name: cpufeatures
    version: 0.3.1
    sha: 5ca28b0ae3115b884660db4118d803791fd6756b6e88f39c0f3f7859060d7566
  - kind: registry
    name: crc-fast
    version: 1.10.0
    sha: e75b2483e97a5a7da73ac68a05b629f9c53cff58d8ed1c77866079e18b00dba5
  - kind: registry
    name: crc32fast
    version: 1.5.4
    sha: 5f97d3416d5337d15c4b0d78c8c91df922ca143f57ec20e2d1c188333047ef04
  - kind: registry
    name: crossbeam-deque
    version: 0.8.8
    sha: 622f3fc73690be383c7214310406f28a90e6edeadc3cea882f9d71e495b9711a
  - kind: registry
    name: crossbeam-epoch
    version: 0.9.21
    sha: dc74980687109a3b14c72fd458107bf0baa1da1a1a805e178d15501ba9b86d9d
  - kind: registry
    name: crossbeam-utils
    version: 0.8.23
    sha: a31eee39dddec8330830986fcd7625edb5a24ec90ea038215273bbc3adb08ac6
  - kind: registry
    name: crossterm
    version: 0.29.0
    sha: d8b9f2e4c67f833b660cdb0a3523065869fb35570177239812ed4c905aeff87b
  - kind: registry
    name: crossterm_winapi
    version: 0.9.1
    sha: acdd7c62a3665c7f6830a51635d9ac9b23ed385797f70a83bb8bafe9c572ab2b
  - kind: registry
    name: crunchy
    version: 0.2.4
    sha: 460fbee9c2c2f33933d720630a6a0bac33ba7053db5344fac858d4b8952d77d5
  - kind: registry
    name: crypto-common
    version: 0.1.7
    sha: 78c8292055d1c1df0cce5d180393dc8cce0abec0a7102adb6c7b1eef6016d60a
  - kind: registry
    name: crypto-common
    version: 0.2.2
    sha: ce6e4c961d6cd6c9a86db418387425e8bdeaf05b3c8bc1411e6dca4c252f1453
  - kind: registry
    name: ctor
    version: 1.0.14
    sha: ea691ed9f36489d087419b8b2ba3ef27d89621380b4178c73e2445a379e4e0f4
  - kind: registry
    name: ctrlc
    version: 3.5.3
    sha: 11247e6c4f83c2b15748f4873805483deaa2bbc855e773817c07a9f987f55c62
  - kind: registry
    name: data-encoding
    version: 2.11.1
    sha: 4583a4551df46e2792f82ceeac45e850d2e2d5debba0b91f102385cda5b11f06
  - kind: registry
    name: data-encoding-macro
    version: 0.1.21
    sha: c6a127ecbb3c4632e1525380e04c0c3fcf8dcb44d32a79ea290d8a36906edcd8
  - kind: registry
    name: data-encoding-macro-internal
    version: 0.1.19
    sha: c54e03a951783e8b327515db3f2a2fd0e3bed362a96b066f341ce66ed49b4ead
  - kind: registry
    name: deranged
    version: 0.5.8
    sha: 7cd812cc2bc1d69d4764bd80df88b4317eaef9e773c75226407d9bc0876b211c
  - kind: registry
    name: diff
    version: 0.1.13
    sha: 56254986775e3233ffa9c4d7d3faaf6d36a2c09d30b20687e9f88bc8bafc16c8
  - kind: registry
    name: digest
    version: 0.10.7
    sha: 9ed9a281f7bc9b7576e61468ba615a66a5c8cfdff42420a70aa82701a3b1e292
  - kind: registry
    name: digest
    version: 0.11.3
    sha: f1dd6dbb5841937940781866fa1281a1ff7bd3bf827091440879f9994983d5c2
  - kind: registry
    name: dispatch2
    version: 0.3.1
    sha: 1e0e367e4e7da84520dedcac1901e4da967309406d1e51017ae1abfb97adbd38
  - kind: registry
    name: displaydoc
    version: 0.2.7
    sha: c6232dd377dcc64799954cbd3a9bb882e9cdc1308ccd87b1c098f1fb2eaf82a8
  - kind: registry
    name: divan-macros
    version: 0.1.17
    sha: 8dc51d98e636f5e3b0759a39257458b22619cac7e96d932da6eeb052891bb67c
  - kind: registry
    name: dns-lookup
    version: 4.0.2
    sha: 263c0ccfc6b3b6a93e959edad4f985779e76c0b36dbb2e13e3d27c690974adf1
  - kind: registry
    name: document-features
    version: 0.2.12
    sha: d4b8a88685455ed29a21542a33abd9cb6510b6b129abadabdcef0f4c55bc8f61
  - kind: registry
    name: dunce
    version: 1.0.5
    sha: 92773504d58c093f6de2459af4af33faa518c13451eb8f2b5698ed3d36e7c813
  - kind: registry
    name: either
    version: 1.19.0
    sha: 0e9c71c2167ca323c882b99918929403426e2373ea17242ff5653e0d5e1058be
  - kind: registry
    name: encode_unicode
    version: 1.0.0
    sha: 34aa73646ffb006b8f5147f3dc182bd4bcb190227ce861fc4a4844bf8e3cb2c0
  - kind: registry
    name: equivalent
    version: 1.0.2
    sha: 877a4ace8713b0bcf2a4e7eec82529c029f1d0619886d18145fea96c3ffe5c0f
  - kind: registry
    name: errno
    version: 0.3.14
    sha: 39cab71617ae0d63f51a36d69f866391735b51691dbda63cf6f96d042b63efeb
  - kind: registry
    name: fancy-regex
    version: 0.20.2
    sha: 0a2e16b9a584b602f1e0e5e22c30ca0906786088c27500653e432d086def8b53
  - kind: registry
    name: fastrand
    version: 2.5.0
    sha: da7c62ceae207dd37ea5b845da6a0696c799f85e97da1ab5b7910be3c1c80223
  - kind: registry
    name: filedescriptor
    version: 0.8.3
    sha: e40758ed24c9b2eeb76c35fb0aebc66c626084edd827e07e1552279814c6682d
  - kind: registry
    name: filetime
    version: 0.2.29
    sha: 5c287a33c7f0a620c38e641e7f60827713987b3c0f26e8ddc9462cc69cf75759
  - kind: registry
    name: find-msvc-tools
    version: 0.1.13
    sha: ef25905e51abafe4dcea6c15fec58c57b601cdbd0ee53d22ea1d3016c587d39b
  - kind: registry
    name: fixed_decimal
    version: 0.7.3
    sha: 2214fb00f669ee96bee5bb29dfb1ddabe058b2bc426817efc79afa03c9bc55ae
  - kind: registry
    name: flate2
    version: 1.1.10
    sha: 6e634e2e0ebac1ee034020da1ca582e17ffe4e0f5e985823721e168928136dcb
  - kind: registry
    name: fluent
    version: 0.17.0
    sha: 8137a6d5a2c50d6b0ebfcb9aaa91a28154e0a70605f112d30cb0cd4a78670477
  - kind: registry
    name: fluent-bundle
    version: 0.16.0
    sha: 01203cb8918f5711e73891b347816d932046f95f54207710bda99beaeb423bf4
  - kind: registry
    name: fluent-langneg
    version: 0.13.1
    sha: 7eebbe59450baee8282d71676f3bfed5689aeab00b27545e83e5f14b1195e8b0
  - kind: registry
    name: fluent-syntax
    version: 0.12.0
    sha: 54f0d287c53ffd184d04d8677f590f4ac5379785529e5e08b1c8083acdd5c198
  - kind: registry
    name: foldhash
    version: 0.2.0
    sha: 77ce24cb58228fbb8aa041425bb1050850ac19177686ea6e0f41a70416f56fdb
  - kind: registry
    name: foreign-types
    version: 0.3.2
    sha: f6f339eb8adc052cd2ca78910fda869aefa38d22d5cb648e6485e4d3fc06f3b1
  - kind: registry
    name: foreign-types-shared
    version: 0.1.1
    sha: 00b0228411908ca8685dba7fc2cdd70ec9990a6e753e89b6ac91a84c40fbaf4b
  - kind: registry
    name: fs_extra
    version: 1.3.0
    sha: 42703706b716c37f96a77aea830392ad231f44c9e9a67872fa5548707e11b11c
  - kind: registry
    name: funty
    version: 2.0.0
    sha: e6d5a32815ae3f33302d95fdcb2ce17862f8c65363dcfd29360480ba1001fc9c
  - kind: registry
    name: futures-core
    version: 0.3.34
    sha: 92d699e522242e69e3003b94ecc1f960f3a5e015aa7c5d7486e65ad01dd94f5e
  - kind: registry
    name: futures-task
    version: 0.3.34
    sha: cd417de3d1d015fc3bfd2b1ea46dfc7bab72ef86f1cc7cc9c78e728b34a6d1fd
  - kind: registry
    name: futures-timer
    version: 3.0.4
    sha: af43fadb8a98512d547e37b4e92e0ced13e205c061b87b4623eff01d918d6968
  - kind: registry
    name: futures-util
    version: 0.3.34
    sha: 0d50a92467f8ba5dd6e3ee5d4bd04d73ab2e4e1c44474a0674821dfce14b79bc
  - kind: registry
    name: generic-array
    version: 0.14.7
    sha: 85649ca51fd72272d7821adaf274ad91c288277713d9c18820d8499a7ff69e9a
  - kind: registry
    name: getrandom
    version: 0.2.17
    sha: ff2abc00be7fca6ebc474524697ae276ad847ad0a6b3faa4bcb027e9a4614ad0
  - kind: registry
    name: getrandom
    version: 0.4.3
    sha: 300e883d756b2e4ec94e02791f39b04b522276138852cfc41d9fb7e904106099
  - kind: registry
    name: glob
    version: 0.3.4
    sha: e4eba85ea1d0a966a983acd07deee566e67395d2d96b6fb39e62b5a833f1eb0b
  - kind: registry
    name: half
    version: 2.7.1
    sha: 6ea2d84b969582b4b1864a92dc5d27cd2b77b622a8d79306834f1be5ba20d84b
  - kind: registry
    name: hashbrown
    version: 0.16.1
    sha: 841d1cc9bed7f9236f321df977030373f4a4163ae1a7dbfe1a51a2c1a51d9100
  - kind: registry
    name: hashbrown
    version: 0.17.1
    sha: ed5909b6e89a2db4456e54cd5f673791d7eca6732202bbf2a9cc504fe2f9b84a
  - kind: registry
    name: hex
    version: 0.4.3
    sha: 7f24254aa9a54b5c858eaee2f5bccdb46aaf0e486a595ed5fd8f86ba55232a70
  - kind: registry
    name: hex-literal
    version: 1.1.0
    sha: e712f64ec3850b98572bffac52e2c6f282b29fe6c5fa6d42334b30be438d95c1
  - kind: registry
    name: hostname
    version: 0.4.2
    sha: 617aaa3557aef3810a6369d0a99fac8a080891b68bd9f9812a1eeda0c0730cbd
  - kind: registry
    name: hybrid-array
    version: 0.4.15
    sha: 27f864f10dfb56725ce5ce5472bc52252c8f93a4ab86327122cebf62c5f59a17
  - kind: registry
    name: icu_calendar
    version: 2.4.0
    sha: a68ffb801cc7acb8dcae62da7c692c47934698d2dd4f479ddee1eb442763dea1
  - kind: registry
    name: icu_calendar_data
    version: 2.4.0
    sha: 514da54e79efa36b5976232d5b3d1d8ee1b47b19ab658f1b1ebe39221696c2d8
  - kind: registry
    name: icu_collator
    version: 2.4.0
    sha: 24cb0205c419b2036da3f9082964905d6849b3f2130dd4a517940c45899a544b
  - kind: registry
    name: icu_collator_data
    version: 2.4.0
    sha: 183f47e821a327661c1ebe152f61d5b6c2000010d228cadbbf226e0e2b8c2634
  - kind: registry
    name: icu_collections
    version: 2.4.0
    sha: fe090a42a0d3140fed8c63263ed1fecc02422cb2f4bfe55cd8de2de1b8e105dd
  - kind: registry
    name: icu_datetime
    version: 2.4.0
    sha: 3c338aa7ebff734470e216a4196fa84b123a366cc786c445741b6f5647412c3c
  - kind: registry
    name: icu_datetime_data
    version: 2.4.0
    sha: 4bddb757c2df1635453c4e8cb2d4ba7ad026e904893f29699315826c0951bbd9
  - kind: registry
    name: icu_decimal
    version: 2.4.0
    sha: 1150ad5e272740670464934ee76facda43ef2e11f85c27b7ba76ccb33edf2d05
  - kind: registry
    name: icu_decimal_data
    version: 2.4.0
    sha: 5595ab78370d48abd24a062f3db115d5108dd0b65634352036cae532aebb0df8
  - kind: registry
    name: icu_locale
    version: 2.4.0
    sha: fe8fa57bcddc15cb921582ee5259c5b77da39f946f188ca5213fad24d9241236
  - kind: registry
    name: icu_locale_core
    version: 2.4.0
    sha: 25d29b57c17c6528d0dc4c2141cfa2d08200465acb537a3909c8b9b8a4a984c0
  - kind: registry
    name: icu_locale_data
    version: 2.4.0
    sha: a64014dac577a11d8d2cee48517c73c1984bd72ab11031e934269bd3cefb2ad9
  - kind: registry
    name: icu_locale_fallback
    version: 2.4.0
    sha: 406e9ae5b95d8aa37db6293405931b766a6172d1848daee22d70eb44aa78a43c
  - kind: registry
    name: icu_locale_fallback_data
    version: 2.4.0
    sha: 3632ebbd0c5c3637ba1a40bdf8288f2cb9d2268e73441a69d5fc73d7cfbaa87c
  - kind: registry
    name: icu_normalizer
    version: 2.4.0
    sha: 404a3b8c486f205c87fe7f23ab6894d84a4ad76d6e4671ae1981ba7def87c599
  - kind: registry
    name: icu_normalizer_data
    version: 2.4.0
    sha: 20f0088bfb7441f7a37fa0c9e20cb1e9cba1cac6b9ce8cd2a6dc44294f8e8cbc
  - kind: registry
    name: icu_pattern
    version: 0.5.1
    sha: bc43ce0e76ee8cb0482dc6e2dbb9b76278e8038f45daabf2a2877577e2ceb18f
  - kind: registry
    name: icu_plurals
    version: 2.4.0
    sha: 2ef046647b445acf95ce0f8083fa292467d3df649959fa9a20f3f8abfd957c5d
  - kind: registry
    name: icu_plurals_data
    version: 2.4.0
    sha: d43ff7df2c1a1d41588a6ddcba354d513d4a3e10eec22c06fe56d13c12a848ea
  - kind: registry
    name: icu_properties
    version: 2.4.0
    sha: 2ea83d991c56158f7cf898bf86436c1dfe7c07ee82fe88951f2695c9f37a379f
  - kind: registry
    name: icu_properties_data
    version: 2.4.0
    sha: b98f29af82d02b163fe50161388350e743bb3107cc8e8c2f7314cb505faddfcf
  - kind: registry
    name: icu_provider
    version: 2.4.0
    sha: 413099315636c588ee8f011190b329b971a09a8fae9d157e01dcae8379468514
  - kind: registry
    name: icu_time
    version: 2.4.0
    sha: 17d45ee651f21433b1c6352311f2ad9b5253c26be0e25d9a0869cb8247b8cfde
  - kind: registry
    name: icu_time_data
    version: 2.4.0
    sha: a6d7d711f44237fa9300406ab6e521148594056862343370b5df265a0d15c088
  - kind: registry
    name: indexmap
    version: 2.14.2
    sha: cc4e190f5d26ca7051642629da2c52fc03bde85a03197c99408dcd291734c855
  - kind: registry
    name: indicatif
    version: 0.18.6
    sha: 9433806cd6b4ec1aba79c021c7e4c58fb4c3b9977c085062e611ac929998fb0c
  - kind: registry
    name: inotify
    version: 0.11.5
    sha: 4cc00ea907cab49550b7da656f80ebb97be1b997d931fbcd28d39734e17ce592
  - kind: registry
    name: inotify-sys
    version: 0.1.8
    sha: c033f80b2c113cdf91ab7a33faa9cbc014726dcad99880c8609af2a370edf37d
  - kind: registry
    name: intl-memoizer
    version: 0.5.3
    sha: 310da2e345f5eb861e7a07ee182262e94975051db9e4223e909ba90f392f163f
  - kind: registry
    name: intl_pluralrules
    version: 7.0.2
    sha: 078ea7b7c29a2b4df841a7f6ac8775ff6074020c6776d48491ce2268e068f972
  - kind: registry
    name: is_terminal_polyfill
    version: 1.70.2
    sha: a6cb138bb79a146c1bd460005623e142ef0181e3d0219cb493e02f7d08a35695
  - kind: registry
    name: itertools
    version: 0.13.0
    sha: 413ee7dfc52ee1a4949ceeb7dbc8a33f2d6c088194d9f922fb8318faf1f01186
  - kind: registry
    name: itertools
    version: 0.14.0
    sha: 2b192c782037fadd9cfa75548310488aabdbf3d2da73885b31bd0abd03351285
  - kind: registry
    name: itertools
    version: 0.15.0
    sha: 8b4baf93f58d4425749ca49a51c50ebab072c5df6994d08fed93541c331481dc
  - kind: registry
    name: itoa
    version: 1.0.19
    sha: 3bd1574e617a9a6c1f8f8181bd7e841e1f20e4277607ef28945765188d6284d4
  - kind: registry
    name: jiff
    version: 0.2.46
    sha: 175dc66334db3b9ab9985bf8b61cfed50dc16d20964bb47f9e479adcae984a7f
  - kind: registry
    name: jiff-core
    version: 0.1.8
    sha: e599b80292e597019b8b3e392de3f4bea2959ddfb8c7dff60e035e9e311a2c1b
  - kind: registry
    name: jiff-icu
    version: 0.2.4
    sha: 72fe268c5e5b3c96397a29f209fe662576f25bf537584274b1aaf201477ad499
  - kind: registry
    name: jiff-static
    version: 0.2.46
    sha: c7b1af7547d47354bc438d797e3854601bde8f8d185780c5ba4ab27afa54f1ba
  - kind: registry
    name: jiff-tzdb
    version: 0.1.10
    sha: 0980fca2cc272465bd60e82397607ba9f33add9e48defd77923301bbd03808f2
  - kind: registry
    name: jiff-tzdb-platform
    version: 0.1.3
    sha: 875a5a69ac2bab1a891711cf5eccbec1ce0341ea805560dcd90b7a2e925132e8
  - kind: registry
    name: jobserver
    version: 0.1.35
    sha: 1c00acbd29eabad4a2392fa0e921c874934dbbf4194312ad20f04a0ed67a3cb3
  - kind: registry
    name: js-sys
    version: 0.3.105
    sha: ce57d20d1ea864ce2ac172ab472d409214f4fd359f0b2a2775abdf522e2af99e
  - kind: registry
    name: keccak
    version: 0.2.2
    sha: d8f198d1db720e4940b5a493201d199d9f24f568f8f746bd13706243a2f71598
  - kind: registry
    name: kqueue
    version: 1.2.1
    sha: 8d763e5b24120b4ddf50de6c92308156765aabfbbccebf401da7cff2d70a41ea
  - kind: registry
    name: kqueue-sys
    version: 1.1.2
    sha: 07293a4e297ac234359b510362495713f75ea345d5307140414f20c69ffeb087
  - kind: registry
    name: libc
    version: 0.2.191
    sha: 65cd87c9a6d60536580b316ad985726104730a5151c99845f2490428ef91240a
  - kind: registry
    name: libloading
    version: 0.8.9
    sha: d7c4b02199fee7c5d21a5ae7d8cfa79a6ef5bb2fc834d6e9058e89c825efdc55
  - kind: registry
    name: libm
    version: 0.2.16
    sha: b6d2cec3eae94f9f509c767b45932f1ada8350c4bdb85af2fcab4a3c14807981
  - kind: registry
    name: link-section
    version: 0.19.4
    sha: 4d9aae57673c1a235149777a74d152f3210ebd3e3b13346d2cdb6809e566bd3c
  - kind: registry
    name: linktime-proc-macro
    version: 0.2.3
    sha: 7e57c38c1e860fd37c604281cdfb1dd2216977fd76a50f85ba2f388ef3219616
  - kind: registry
    name: linux-raw-sys
    version: 0.12.1
    sha: 32a66949e030da00e8c7d4434b251670a91556f4144941d37452769c25d58a53
  - kind: registry
    name: litemap
    version: 0.8.3
    sha: 47d9d19d1d6efa0109d2f65ff4c85cddd50bd572e5a00127ab10987290bcefae
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
    version: 0.4.34
    sha: f9f8bd3e56ce4dfc153cf470fffbfa98c7620958b312ca5c3a4b8d5181fd13c6
  - kind: registry
    name: lru
    version: 0.16.4
    sha: 7f66e8d5d03f609abc3a39e6f08e4164ebf1447a732906d39eb9b99b7919ef39
  - kind: registry
    name: lscolors
    version: 0.21.0
    sha: d60e266dfb1426eb2d24792602e041131fdc0236bb7007abc0e589acafd60929
  - kind: registry
    name: md-5
    version: 0.11.0
    sha: 69b6441f590336821bb897fb28fc622898ccceb1d6cea3fde5ea86b090c4de98
  - kind: registry
    name: memchr
    version: 2.8.3
    sha: cf8baf1c55e62ffcace7a9f06f4bd9cd3f0c4beb022d3b367256b91b87513d98
  - kind: registry
    name: memmap2
    version: 0.9.12
    sha: 6b0ca1155a9ecc25aa12e8313a119f32edf0255fea2f44839c4ac0a12b2ac157
  - kind: registry
    name: minimal-lexical
    version: 0.2.1
    sha: 68354c5c6bd36d73ff3feceb05efa59b6acb7626617f4962be322a825e61f79a
  - kind: registry
    name: mio
    version: 1.2.4
    sha: 1788edb87fdc09c7e26304471e2f5be8cdefb1b6930d6e3985fc02ff53bf86ee
  - kind: registry
    name: nix
    version: 0.31.3
    sha: cf20d2fde8ff38632c426f1165ed7436270b44f199fc55284c38276f9db47c3d
  - kind: registry
    name: nom
    version: 7.1.3
    sha: d273983c5a657a70a3e8f2a01329822f3b8c8172b73826411a55751e404a0a4a
  - kind: registry
    name: nom
    version: 8.0.0
    sha: df9761775871bdef83bee530e60050f7e54b1105350d6884eb0fb4f46c2f9405
  - kind: registry
    name: notify
    version: 8.2.2
    sha: c41a04a5f59df9322cc657286dd2d79f90816119b22c5f847607c850110205ab
  - kind: registry
    name: notify-types
    version: 2.1.0
    sha: 42b8cfee0e339a0337359f3c88165702ac6e600dc01c0cc9579a92d62b08477a
  - kind: registry
    name: nu-ansi-term
    version: 0.50.3
    sha: 7957b9740744892f114936ab4a57b3f487491bbeafaf8083688b16841a4240e5
  - kind: registry
    name: num-bigint
    version: 0.4.8
    sha: c89e69e7e0f03bea5ef08013795c25018e101932225a656383bd384495ecc367
  - kind: registry
    name: num-conv
    version: 0.2.2
    sha: 521739c6d2bac4aa25192232afe6841231376b2b26d4d9fae5ecf8ca5772e441
  - kind: registry
    name: num-integer
    version: 0.1.47
    sha: 7ce2d95d4b3734dc35aa2f45e1aa22cd416814592a4f9d9205e11affd5b8e10b
  - kind: registry
    name: num-modular
    version: 0.6.5
    sha: bd8e500409e6cd603b03e477c26a6caecdc27ac58979a53e881c75eafc079f44
  - kind: registry
    name: num-prime
    version: 0.7.0
    sha: 6de1394909173a98f21f28406f9d82f0e11d87be4bf36473364f37a5bd100741
  - kind: registry
    name: num-traits
    version: 0.2.19
    sha: 071dfc062690e90b734c0b2273ce72ad0ffa95f0c74596bc250dcfd960262841
  - kind: registry
    name: num_threads
    version: 0.1.7
    sha: 5c7398b9c8b70908f6371f47ed36737907c87c52af34c268fed0bf0ceb92ead9
  - kind: registry
    name: objc2
    version: 0.6.4
    sha: 3a12a8ed07aefc768292f076dc3ac8c48f3781c8f2d5851dd3d98950e8c5a89f
  - kind: registry
    name: objc2-core-foundation
    version: 0.3.2
    sha: 2a180dd8642fa45cdb7dd721cd4c11b1cadd4929ce112ebd8b9f5803cc79d536
  - kind: registry
    name: objc2-core-services
    version: 0.3.2
    sha: 583300ad934cba24ff5292aee751ecc070f7ca6b39a574cc21b7b5e588e06a0b
  - kind: registry
    name: objc2-encode
    version: 4.1.0
    sha: ef25abbcd74fb2609453eb695bd2f860d389e457f67dc17cafc8b8cbc89d0c33
  - kind: registry
    name: once_cell
    version: 1.21.4
    sha: 9f7c3e4beb33f85d45ae3e3a1792185706c8e16d043238c593331cc7cd313b50
  - kind: registry
    name: once_cell_polyfill
    version: 1.70.2
    sha: 384b8ab6d37215f3c5301a95a4accb5d64aa607f1fcb26a11b5303878451b4fe
  - kind: registry
    name: openssl
    version: 0.10.82
    sha: 4de8111e94a56adca7ebfe6c365b6d42f99deb69b74b6becacd4204e2f193aa2
  - kind: registry
    name: openssl-macros
    version: 0.1.1
    sha: a948666b637a0f465e8564c73e89d4dde00d72d4d473cc972f390fc3dcee7d9c
  - kind: registry
    name: openssl-src
    version: 300.6.1+3.6.3
    sha: 46eb8fb9fb3b61ce1c0f8a026c4c1a0714d3a9e138e7fbde78753ce2babc3846
  - kind: registry
    name: openssl-sys
    version: 0.9.118
    sha: 19c413d6ec9ebaf5e1c829d355cb3e9f783778d700f135be0921d52fce3c60ae
  - kind: registry
    name: os_display
    version: 0.1.4
    sha: ad5fd71b79026fb918650dde6d125000a233764f1c2f1659a1c71118e33ea08f
  - kind: registry
    name: outref
    version: 0.5.2
    sha: 1a80800c0488c3a21695ea981a54918fbb37abf04f4d0720c453632255e2ff0e
  - kind: registry
    name: parking_lot
    version: 0.12.5
    sha: 93857453250e3077bd71ff98b6a65ea6621a19bb0f559a85248955ac12c45a1a
  - kind: registry
    name: parking_lot_core
    version: 0.9.12
    sha: 2621685985a2ebf1c516881c026032ac7deafcda1a2c9b7850dc81e3dfcb64c1
  - kind: registry
    name: parse_datetime
    version: 0.17.0
    sha: cb51967a779ef73b125a243688e53e4bb2474f91cae72734ee5051e857fb2645
  - kind: registry
    name: phf
    version: 0.14.0
    sha: 010378780309880b08997fae13be7834dba947d36393bd372f2b1556deb2a2f6
  - kind: registry
    name: phf_codegen
    version: 0.14.0
    sha: 41b585a510fb76fdebead6897982ef2a03a21d8e6cbcca904999742a4afc6ffe
  - kind: registry
    name: phf_generator
    version: 0.14.0
    sha: aeb62e0959d5a1bebc965f4d15d9e2b7cea002b6b0f5ba8cde6cc26738467100
  - kind: registry
    name: phf_shared
    version: 0.14.0
    sha: c6fd9027e2d9319be6349febd1db4e8d02aa544921200c9b777720ac34a3aa89
  - kind: registry
    name: pin-project-lite
    version: 0.2.17
    sha: a89322df9ebe1c1578d689c92318e070967d1042b512afbe49518723f4e6d5cd
  - kind: registry
    name: pkg-config
    version: 0.3.34
    sha: f6b464fbc74e149a392436b17d523f769e057cb6877f6a5c4618bc6f11800548
  - kind: registry
    name: platform-info
    version: 2.2.1
    sha: aa5c6ef5da99ec17edc36267860ddb03504a916e0cc74c0c4dd1c5cdb19637f8
  - kind: registry
    name: portable-atomic
    version: 1.15.0
    sha: 05c8b63e8d9609db387f0324918f81d68fe27748f084ef092fb35954d0539a85
  - kind: registry
    name: portable-atomic-util
    version: 0.2.8
    sha: 10ab3eb7f3becc3a1cbc4f2c6f20267996cfc1a6467a873763411b136a122715
  - kind: registry
    name: potential_utf
    version: 0.1.6
    sha: d83eb9bc6d8e5cf568e7a1101d60ee05e81ed50ea106026f3d18deeb046d7661
  - kind: registry
    name: powerfmt
    version: 0.2.0
    sha: 439ee305def115ba05938db6eb1644ff94165c5ab5e9420d1c1bcedbba909391
  - kind: registry
    name: ppv-lite86
    version: 0.2.21
    sha: 85eae3c4ed2f50dcfe72643da4befc30deadb458a9b590d720cde2f2b1e97da9
  - kind: registry
    name: pretty_assertions
    version: 1.4.1
    sha: 3ae130e2f271fbc2ac3a40fb1d07180839cdbbe443c7a27e1e3c13c5cac0116d
  - kind: registry
    name: prettyplease
    version: 0.2.37
    sha: 479ca8adacdd7ce8f1fb39ce9ecccbfe93a3f1344b3d0d97f20bc0196208f62b
  - kind: registry
    name: proc-macro-crate
    version: 3.5.0
    sha: e67ba7e9b2b56446f1d419b1d807906278ffa1a658a8a5d8a39dcb1f5a78614f
  - kind: registry
    name: proc-macro2
    version: 1.0.107
    sha: 985e7ec9bb745e6ce6535b544d84d6cd6f7ad8bd711c398938ae983b91a766d9
  - kind: registry
    name: procfs
    version: 0.18.0
    sha: 25485360a54d6861439d60facef26de713b1e126bf015ec8f98239467a2b82f7
  - kind: registry
    name: procfs-core
    version: 0.18.0
    sha: e6401bf7b6af22f78b563665d15a22e9aef27775b79b149a66ca022468a4e405
  - kind: registry
    name: quote
    version: 1.0.47
    sha: 1fbf4db142a473a8d80c26bbf18454ed458bf8d26c8219c331daecfdbd079001
  - kind: registry
    name: r-efi
    version: 6.0.0
    sha: f8dcc9c7d52a811697d2151c701e0d08956f92b0e24136cf4cf27b57a6a0d9bf
  - kind: registry
    name: radium
    version: 0.7.0
    sha: dc33ff2d4973d518d823d61aa239014831e521c75da58e3df4840d3f47749d09
  - kind: registry
    name: rand
    version: 0.10.4
    sha: 8f6fa277c67e6ea590466f04c3fe82cb509f0864fe470643e5570de9514a9b11
  - kind: registry
    name: rand
    version: 0.8.8
    sha: e058c7de0b26af77780c769414d6257830bb240f3c38477dbc2c16e5f54d6d4c
  - kind: registry
    name: rand_chacha
    version: 0.10.0
    sha: 3e6af7f3e25ded52c41df4e0b1af2d047e45896c2f3281792ed68a1c243daedb
  - kind: registry
    name: rand_chacha
    version: 0.3.1
    sha: e6c10a63a0fa32252be49d21e7709d4d4baf8d231c2dbce1eaa8141b9b127d88
  - kind: registry
    name: rand_core
    version: 0.10.1
    sha: 63b8176103e19a2643978565ca18b50549f6101881c443590420e4dc998a3c69
  - kind: registry
    name: rand_core
    version: 0.6.4
    sha: ec0be4795e2f6a28069bec0b5ff3e2ac9bafc99e6a9a7dc3547996c5c816922c
  - kind: registry
    name: rayon
    version: 1.12.0
    sha: fb39b166781f92d482534ef4b4b1b2568f42613b53e5b6c160e24cfbfa30926d
  - kind: registry
    name: rayon-core
    version: 1.13.0
    sha: 22e18b0f0062d30d4230b2e85ff77fdfe4326feb054b9783a3460d8435c8ab91
  - kind: registry
    name: redox_syscall
    version: 0.5.18
    sha: ed2bf2547551a7053d6fdfafda3f938979645c44812fbfcda098faae3f1a362d
  - kind: registry
    name: regex
    version: 1.13.2
    sha: 9807af0e638c12e753aa1b4e601791bf2a8f71274023c8bbeec12fc149950857
  - kind: registry
    name: regex-automata
    version: 0.4.19
    sha: 41d60ef07df457506a0a1a2073112eb4aae5733dbd2813c3da77d1b0fd441158
  - kind: registry
    name: regex-lite
    version: 0.1.9
    sha: cab834c73d247e67f4fae452806d17d3c7501756d98c8808d7c9c7aa7d18f973
  - kind: registry
    name: regex-syntax
    version: 0.8.12
    sha: d902046e6a28a1e4c3cab97258a0ce11e994903f01c2d97a9447a0b3df85f4f6
  - kind: registry
    name: relative-path
    version: 1.9.3
    sha: ba39f3699c378cd8970968dcbff9c43159ea4cfbd88d43c00b22f2ef10a435d2
  - kind: registry
    name: rlimit
    version: 0.11.0
    sha: f35ee2729c56bb610f6dba436bf78135f728b7373bdffae2ec815b2d3eb98cc3
  - kind: registry
    name: roff
    version: 1.1.1
    sha: 323c417e1d9665a65b263ec744ba09030cfb277e9daa0b018a4ab62e57bc8189
  - kind: registry
    name: rstest
    version: 0.28.0
    sha: b376e512f30a7686a8dbc6aeaace99b3ade1c26c1c63473473a817ade226dafc
  - kind: registry
    name: rstest_macros
    version: 0.28.0
    sha: 88512dbfb5b73a0dfa38aef7bc73b5657035fce477b923faf12d332dd83051ea
  - kind: registry
    name: rstest_reuse
    version: 0.7.1
    sha: 5ac1bd675701e1d74aef2f1b332d28182700f1bc7f2371209ac5eb26a238f422
  - kind: registry
    name: rustc-hash
    version: 2.1.3
    sha: 6b1e7f9a428571be2dc5bc0505c13fb6bf936822b894ec87abf8a08a4e51742d
  - kind: registry
    name: rustc_version
    version: 0.4.1
    sha: cfcb3a22ef46e85b45de6ee7e79d063319ebb6594faafcf1c225ea92ab6e9b92
  - kind: registry
    name: rustix
    version: 1.1.6
    sha: e5e76742e5294153d4dde1207dbec5bdd81eef6fabdc0d2118babadabfd858aa
  - kind: registry
    name: rustversion
    version: 1.0.23
    sha: cf54715a573b99ac80df0bc206da022bcd442c974952c7b9720069370852e21f
  - kind: registry
    name: same-file
    version: 1.0.6
    sha: 93fc1dc3aaa9bfed95e02e6eadabb4baf7e3078b0bd1b4d7b6b0b68378900502
  - kind: registry
    name: scopeguard
    version: 1.2.0
    sha: 94143f37725109f92c262ed2cf5e59bce7498c01bcc1502d7b9afe439a4e9f49
  - kind: registry
    name: self_cell
    version: 1.3.0
    sha: 2ab42ca02749e120097e328d91d415325bdf43b1c72c4c8badf37375fe40a813
  - kind: registry
    name: selinux
    version: 0.6.3
    sha: 5e27b533f7b8e124356edfe653a21e5a5072585b4c0a67459519844c039bc4e1
  - kind: registry
    name: selinux-sys
    version: 0.7.0
    sha: acf9f7ddcfd31f0558b246d6ddc4a34fb4550668f364a09dd51f28409157e754
  - kind: registry
    name: semver
    version: 1.0.28
    sha: 8a7852d02fc848982e0c167ef163aaff9cd91dc640ba85e263cb1ce46fae51cd
  - kind: registry
    name: serde
    version: 1.0.229
    sha: 4148590afebada386688f18773da617792bf2ef03ffc1e4cbd2b1d45b023e0ba
  - kind: registry
    name: serde_core
    version: 1.0.229
    sha: 67dca2c9c51e58a4791a4b1ed58308b39c64224d349a935ab5039aa360942a48
  - kind: registry
    name: serde_derive
    version: 1.0.229
    sha: e7a5d71263a5a7d47b41f6b3f06ba276f10cc18b0931f1799f710578e2309348
  - kind: registry
    name: serde_json
    version: 1.0.151
    sha: c841b55ecdae098c80dcae9cf767f6f8a0c2cdb3416bbef72181df4d0fe73f14
  - kind: registry
    name: sha1
    version: 0.11.0
    sha: aacc4cc499359472b4abe1bf11d0b12e688af9a805fa5e3016f9a386dc2d0214
  - kind: registry
    name: sha2
    version: 0.11.1
    sha: 47d7069beb7d6ac7b9acd1039986e73443f24234f41074da099d6f994ac9ad19
  - kind: registry
    name: sha3
    version: 0.12.0
    sha: bc9bad02c26382724b2d2692c6f179285e4b54eeecd7968f52a50059c3c11759
  - kind: registry
    name: shake
    version: 0.1.0
    sha: 09057cb2149ad4cbd2da1e26b351f9a4c354219421229c69c3063e6f61947c4a
  - kind: registry
    name: shlex
    version: 1.3.0
    sha: 0fda2ff0d084019ba4d7c6f371c95d8fd75ce3524c3cb8fb653a3023f6323e64
  - kind: registry
    name: shlex
    version: 2.0.1
    sha: f8fadd59c855ef2080decdef8ff161eb6661b86933c9d82e5ba29dc602a55aba
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
    version: 0.3.10
    sha: 3a219298ac11a56ea9a6d2120044824d6f01aeb034955e7af7bc16858527deea
  - kind: registry
    name: siphasher
    version: 1.0.3
    sha: 8ee5873ec9cce0195efcb7a4e9507a04cd49aec9c83d0389df45b1ef7ba2e649
  - kind: registry
    name: slab
    version: 0.4.12
    sha: 0c790de23124f9ab44544d7ac05d60440adc586479ce501c1d6d7da3cd8c9cf5
  - kind: registry
    name: sm3
    version: 0.5.0
    sha: da6a89ba31723d185fd7413b98c576a575f356d9b84729d8ecb6ead60000a5b6
  - kind: registry
    name: smallvec
    version: 1.16.1
    sha: ba467056f1b547ed52077911161fc86985becbc60e8e1857c8a144dab0def891
  - kind: registry
    name: socket2
    version: 0.6.5
    sha: c3d1e2c7f27f8d4cb10542a02c49005dbd6e93095799d6f3be745fae9f8fedd4
  - kind: registry
    name: spin
    version: 0.10.1
    sha: 023a211cb3138dbc438680b32560ad89f699977624c9f8dbb95a47d5b4c07dd3
  - kind: registry
    name: sponge-cursor
    version: 0.1.0
    sha: 3a0219bd7d979d58245a4f41f695e1ac9f8befdffadd7f61f1bae9e39abc6620
  - kind: registry
    name: stable_deref_trait
    version: 1.2.1
    sha: 6ce2be8dc25455e1f91df71bfa12ad37d7af1092ae736f3a6cd0e37bc7810596
  - kind: registry
    name: statrs
    version: 0.18.0
    sha: 2a3fe7c28c6512e766b0874335db33c94ad7b8f9054228ae1c2abd47ce7d335e
  - kind: registry
    name: strsim
    version: 0.11.1
    sha: 7da8b5736845d9f2fcb837ea5d9e2628564b3b043a70948a3f0b778838c5fb4f
  - kind: registry
    name: syn
    version: 2.0.119
    sha: 872831b642d1a07999a962a351ed35b955ea2cfc8f3862091e2a240a84f17297
  - kind: registry
    name: syn
    version: 3.0.10
    sha: 4ae9ccbea3a7b0b09443036490c8f34a8b1b760fd345e5c0dae0aac718faea79
  - kind: registry
    name: synstructure
    version: 0.14.0
    sha: 901704edd0dfe137f1987838ee4f259e4e063c31371bdb423f7ae38ec6f77f02
  - kind: registry
    name: tap
    version: 1.0.1
    sha: 55937e1799185b12863d447f42597ed69d9928686b8d88a1df17376a097d8369
  - kind: registry
    name: temp-env
    version: 0.3.6
    sha: 96374855068f47402c3121c6eed88d29cb1de8f3ab27090e273e420bdabcf050
  - kind: registry
    name: tempfile
    version: 3.27.0
    sha: 32497e9a4c7b38532efcdebeef879707aa9f794296a4f0244f6f69e9bc8574bd
  - kind: registry
    name: terminal_size
    version: 0.4.4
    sha: 230a1b821ccbd75b185820a1f1ff7b14d21da1e442e22c0863ea5f08771a8874
  - kind: registry
    name: textwrap
    version: 0.16.4
    sha: 6ecfad6c3abc80a577f2b91c1e412ee57e7a060d430b553c1b0c940974ebcd49
  - kind: registry
    name: thiserror
    version: 1.0.69
    sha: b6aaf5339b578ea85b50e080feb250a3e8ae8cfcdff9a461c9ec2904bc923f52
  - kind: registry
    name: thiserror
    version: 2.0.21
    sha: 09e52cb86a36cede5cb101bf8908837b3e4c6e5e59fe7fd85c23fb56200d189e
  - kind: registry
    name: thiserror-impl
    version: 1.0.69
    sha: 4fee6c4efc90059e10f81e6d42c60a18f76588c3d74cb83a0b242a2b6c7504c1
  - kind: registry
    name: thiserror-impl
    version: 2.0.21
    sha: fe5197923287db20a58125f0bc85c062f7f2c892de97b18c356f9efb14b28524
  - kind: registry
    name: time
    version: 0.3.55
    sha: cdb87b95ec50ddfa440816d227a17b2ccbdda963a316a727fda0fc4334f7d134
  - kind: registry
    name: time-core
    version: 0.1.9
    sha: 9e1c906769ad99c88eaa54e728060edef082f8e358ff32030cb7c7d315e81109
  - kind: registry
    name: time-macros
    version: 0.2.32
    sha: 7e689342a48d2ea927c87ea50cabf8594854bf940e9310208848d680d668ed85
  - kind: registry
    name: tinystr
    version: 0.8.5
    sha: abc840c238154d58f9e86b2792261edfde565a17696e1cda1a449de27979801a
  - kind: registry
    name: toml_datetime
    version: 1.1.1+spec-1.1.0
    sha: 3165f65f62e28e0115a00b2ebdd37eb6f3b641855f9d636d3cd4103767159ad7
  - kind: registry
    name: toml_edit
    version: 0.25.15+spec-1.1.0
    sha: 1340ea94a5856333492c9064b02c778b191dd2c853778d9609debdcdfea3a614
  - kind: registry
    name: toml_parser
    version: 1.1.3+spec-1.1.0
    sha: 1d38ac1cf9b95face32296c0a3ede1fdc270627c9d9c02a7274dd6d960dc4d56
  - kind: registry
    name: type-map
    version: 0.5.1
    sha: cb30dbbd9036155e74adad6812e9898d03ec374946234fbcebd5dfc7b9187b90
  - kind: registry
    name: typed-path
    version: 0.13.0
    sha: 9ce898823d8cd0f028662d2f349694b1af0a5cc9be83f1d213a00d3147445e1e
  - kind: registry
    name: typenum
    version: 1.20.1
    sha: b6f5e870be6c3b371b77fe0ee0bafb859fa4964b4404c27de1d380043c4dda20
  - kind: registry
    name: unic-langid
    version: 0.9.6
    sha: a28ba52c9b05311f4f6e62d5d9d46f094bd6e84cb8df7b3ef952748d752a7d05
  - kind: registry
    name: unic-langid-impl
    version: 0.9.6
    sha: dce1bf08044d4b7a94028c93786f8566047edc11110595914de93362559bc658
  - kind: registry
    name: unicode-ident
    version: 1.0.26
    sha: d245f478577f809a851594d02313b640fb437e0bb33866753cff937863096954
  - kind: registry
    name: unicode-width
    version: 0.2.3
    sha: ca718471876992059f251e33aafc334346ada08042b7661dd1fe313a9bced557
  - kind: registry
    name: unindent
    version: 0.2.4
    sha: 7264e107f553ccae879d21fbea1d6724ac785e8c3bfc762137959b5802826ef3
  - kind: registry
    name: unit-prefix
    version: 0.5.2
    sha: 81e544489bf3d8ef66c953931f56617f423cd4b5494be343d9b9d3dda037b9a3
  - kind: registry
    name: utf16_iter
    version: 1.0.5
    sha: c8232dd3cdaed5356e0f716d285e4b40b932ac434100fe9b7e0e8e935b9e6246
  - kind: registry
    name: utf8_iter
    version: 1.0.4
    sha: b6c140620e7ffbb22c2dee59cafe6084a59b5ffc27a8859a5f0d494b5d52b6be
  - kind: registry
    name: utf8parse
    version: 0.2.2
    sha: 06abde3611657adf66d383f00b093d7faecc7fa57071cce2578660c9f1010821
  - kind: registry
    name: utmp-classic
    version: 0.2.1
    sha: db5a80feb3b4d6ca5e7f2075904e6ef26d335a888f28c453f94efafbc9d0e5cb
  - kind: registry
    name: utmp-classic-raw
    version: 0.2.1
    sha: 52463619959caa531fb5da45898e646000bb38ba133b31d67141e47e17e56147
  - kind: registry
    name: uutils_term_grid
    version: 0.8.1
    sha: e70bdc0434ef5f30856fbe0908a7d96568f8b212a28c20b16d44851f753e465f
  - kind: registry
    name: vcpkg
    version: 0.2.15
    sha: accd4ea62f7bb7a82fe23066fb0957d48ef677f6eeb8215f372f52e48bb32426
  - kind: registry
    name: version_check
    version: 0.9.5
    sha: 0b928f33d975fc6ad9f86c8f283853ad26bdd5b10b7f1542aa2fa15e2289105a
  - kind: registry
    name: vsimd
    version: 0.8.0
    sha: 5c3082ca00d5a5ef149bb8b555a72ae84c9c59f7250f013ac822ac2e49b19c64
  - kind: registry
    name: walkdir
    version: 2.5.0
    sha: 29790946404f91d9c5d06f9874efddea1dc06c5efe94541a7d6863108e3a5e4b
  - kind: registry
    name: wasi
    version: 0.11.1+wasi-snapshot-preview1
    sha: ccf3ec651a847eb01de73ccad15eb7d99f80485de043efb2f370cd654f4ea44b
  - kind: registry
    name: wasm-bindgen
    version: 0.2.128
    sha: aecb87a33d3b0c5e3b7aa46336eaf486cffafbd281b195e4c8b80d50df2351bf
  - kind: registry
    name: wasm-bindgen-macro
    version: 0.2.128
    sha: a690d511e3c1a8b3a55e33511e3c2c00c78415cd23650f32b808627f5696b9ed
  - kind: registry
    name: wasm-bindgen-macro-support
    version: 0.2.128
    sha: 411e4887f0071ef2d2164a9d5fdf2d20efbef78fccd3a78b0c10a1dc5295e48a
  - kind: registry
    name: wasm-bindgen-shared
    version: 0.2.128
    sha: 81941cd78d0c92026c33e5e01312845a4cb1e9af3407f9134b100dd03144103e
  - kind: registry
    name: web-time
    version: 1.1.0
    sha: 5a6580f308b1fad9207618087a65c04e7a10bc77e02c8e84e9b00dd4b12fa0bb
  - kind: registry
    name: wild
    version: 2.2.1
    sha: a3131afc8c575281e1e80f36ed6a092aa502c08b18ed7524e86fbbb12bb410e1
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
    version: 0.1.11
    sha: c2a7b1c03c876122aa43f3020e6c3c3ee5c05081c9a00739faf7503aeba10d22
  - kind: registry
    name: winapi-x86_64-pc-windows-gnu
    version: 0.4.0
    sha: 712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f
  - kind: registry
    name: windows-link
    version: 0.2.1
    sha: f0805222e57f7521d6a62e36fa9163bc891acd422f971defe97d64e70d0a4fe5
  - kind: registry
    name: windows-sys
    version: 0.61.2
    sha: ae137229bcbd6cdf0f7b80a31df61766145077ddf49416a728b02cb3921ff3fc
  - kind: registry
    name: winnow
    version: 1.0.4
    sha: 23b97319f7b8343df12cc98938e5c3eb436064524c8d2b4e30a1d3a36eecdf81
  - kind: registry
    name: write16
    version: 1.0.0
    sha: d1890f4022759daae28ed4fe62859b1236caebfc61ede2f63ed4e695f3f6d936
  - kind: registry
    name: writeable
    version: 0.6.4
    sha: 3ad82d2a33cdc9674dc7465672f271e096168fcdbe0f799d9e6db8c5892679dc
  - kind: registry
    name: wyz
    version: 0.5.1
    sha: 05f360fc0b24296329c78fda852a1e9ae82de9cf7b27dae4b7f62f118f77b9ed
  - kind: registry
    name: xattr
    version: 1.7.0
    sha: 963d6fab92d5504b971dc8bd90ca743c2575e590bc8071ea5bc571598667ae08
  - kind: registry
    name: yansi
    version: 1.0.1
    sha: cfe53a6657fd280eaa890a3bc59152892ffa3e30101319d168b781ed6529b049
  - kind: registry
    name: yoke
    version: 0.8.4
    sha: 417ef3fcf6c300b7dbd25c85531a746931c02ad536f3cf4786ed1e88223340b3
  - kind: registry
    name: yoke-derive
    version: 0.8.4
    sha: ec8ebde2db3681e8c9980cc27822030e68752690ddfa9473e739aeb4dbde6d71
  - kind: registry
    name: z85
    version: 3.0.7
    sha: c6e61e59a957b7ccee15d2049f86e8bfd6f66968fcd88f018950662d9b86e675
  - kind: registry
    name: zerocopy
    version: 0.8.57
    sha: d35102a9f36d089ccae9e4c6802bc118be4487b80aaffc0ab4e0cf5ce92d2873
  - kind: registry
    name: zerocopy-derive
    version: 0.8.57
    sha: 146c01f5ab44258da43cf276c74a2763db2ff3969c9c652c3f2de07041d0b2bc
  - kind: registry
    name: zerofrom
    version: 0.1.8
    sha: 0ec05a11813ea801ff6d75110ad09cd0824ddba17dfe17128ea0d5f68e6c5272
  - kind: registry
    name: zerofrom-derive
    version: 0.1.8
    sha: f75b4683f6c7f45248d4d64056a24298c6281e0993356d7d1b4a1a962ef10d4a
  - kind: registry
    name: zeroize
    version: 1.9.1
    sha: e13084392c5e4bc371903e2935a5eaeed24905a7511356b883835e18a78f6879
  - kind: registry
    name: zeroize_derive
    version: 1.5.0
    sha: 3c50655cbb0fe3fc43170059e702f1ce5e19b84cec58dc87b037a09935c2f328
  - kind: registry
    name: zerotrie
    version: 0.2.5
    sha: 4ea269c3bd32f0a32c321907a2ae912ba6f4649bb0fc764a15627e99a7095a3f
  - kind: registry
    name: zerovec
    version: 0.11.9
    sha: f58a2799cfe9a1670c7ea8edbd52ef8edb93cb37a7f83bf31ba9e35d9dae6a40
  - kind: registry
    name: zerovec-derive
    version: 0.11.7
    sha: c3743ddbf47738d929cd1ae2e199d40d0162979dfe31aef8ae646d2bf00bf97a
  - kind: registry
    name: zip
    version: 9.5.1
    sha: e3476fd497ac8af5b1ec7b51acab7bef380f7e8dd8e0487595bafd839417a302
  - kind: registry
    name: zlib-rs
    version: 0.6.8
    sha: b268e58e7c693d7c271f93ffc4ba3b380412554231c85bf61ca7af91042a4112
  - kind: registry
    name: zmij
    version: 1.0.23
    sha: 29666d0abbfad1e3dc4dcf6144730dd3a3ab225bbbdac83319345b1b44ccfc1b
  - kind: registry
    name: zopfli
    version: 0.8.4
    sha: aaf7fc5d30c28483d93805c4a5e12b05bbb52407fa67c5f8bd552374cd01fb11
