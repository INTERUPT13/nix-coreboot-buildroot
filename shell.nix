{ pkgs ? import <nixpkgs> { } }:

(pkgs.buildFHSUserEnv {
  name = "simple-x11-env";
  targetPkgs = pkgs:
    (with pkgs;
      let
        nixpkgs-unstable = import (builtins.fetchGit {
          url = "https://github.com/nixos/nixpkgs.git";
          ref = "master";
        }) { system = "x86_64-linux"; };
      in [
        pkg-config
        file
        util-linux
        ncurses
        which
        unzip
        bc
        rsync
        cpio
        wget
        perl
        flock
        m4
        flex
        nixpkgs-unstable.automake
        gperf
        help2man
        texinfo
        gmp
        mpfr
      ]);
  multiPkgs = pkgs: (with pkgs; [ udev alsa-lib ]);
  runScript = "bash";
}).env
