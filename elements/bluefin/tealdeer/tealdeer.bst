kind: stack

(?):
- arch == "x86_64":
    depends:
      - bluefin/tealdeer/tealdeer-x86_64.bst
- arch == "aarch64":
    depends:
      - bluefin/tealdeer/tealdeer-aarch64.bst
