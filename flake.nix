{
  description =
    "uses buildroot to build a tiny initrd to be used in my coreboot firmware";

  inputs = {
    nixpkgs-unstable.url = "nixpkgs/nixos-unstable";
    buildroot-src = {
      url = "http://git.buildroot.net/buildroot/";
      type = "git";
      rev = "607c5986a9b3bde0cacdbe38eeaea2ab456a6e80";
      flake = false;
    };

    # TODO for now I just lazily provide all the deps but it should be fairly
    # simple to provide some sort of vendoring functionality for the buildroot
    # deps that are used during a build since in:
    #   package/<DEP_PKG_NAME>/<DEP_PKG_NAME>.mk
    # a package description file can be found that defines
    #   - the remote location of the file (http/git/...)
    #   - the checksum
    #   - the vesion
    #   - the name
    # so I guess it should be possible to derive something more nix-ish from
    # that like its being done for rust
    buildroot-deps = {
      url = "https://github.com/INTERUPT13/nix-coreboot-buildroot-deps";
      type = "git";
      flake = false;
    };

    # shit is 2 big for github so we uhh just fetch these 3 files manually

    gcc-tarball = {
      url = "https://gcc.gnu.org/pub/gcc/releases/gcc-10.3.0/gcc-10.3.0.tar.xz";
      flake = false;
      type = "file";
    };

    linux-tarball-30 = {
      flake = false;
      type = "file";
      url =
        "https://mirrors.edge.kernel.org/pub/linux/kernel/v5.x/linux-5.15.30.tar.xz";
    };

  };

  outputs = { self, nixpkgs, nixpkgs-unstable, buildroot-src, buildroot-deps
    , gcc-tarball, linux-tarball-30 }:
    with import nixpkgs { system = "x86_64-linux"; };
    let pkgs-unstable = import nixpkgs-unstable { system = "x86_64-linux"; };
    in {
      packages.x86_64-linux.coreboot-initrd = stdenv.mkDerivation {
        name = "coreboot-linux-initrd";
        src = buildroot-src;

        hardeningDisable = [ "format" ];

        postUnpack = ''
          cp ${self}/buildroot_config.config source/.config
          cp -r ${buildroot-deps}/ source/dl
          chmod +w -R source/dl 

          mkdir source/dl/linux/
          mkdir source/dl/gcc/
          cp ${linux-tarball-30} source/dl/linux/linux-5.15.30.tar.xz
          cp ${gcc-tarball} source/dl/gcc/gcc-10.3.0.tar.xz 

        '';

        # maybe pointless with FHS
        patchPhase = ''
          patchShebangs --build support/scripts/br2-external
        '';

        nativeBuildInputs = let
          fhs-env = (buildFHSUserEnv {
            name = "buildroot-env";

            #TODO some of these don't have to be in the fhs 
            # is there a point in only putting in these where we
            # actually need them in the fhs?
            targetPkgs = pkgs: ([
              pkg-config
              file
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
              util-linux
              flex
              pkgs-unstable.automake
              gperf
              help2man
              texinfo
              gmp
              mpfr
              stdenvNoCC

              gnumake
              gcc
              gnupatch
              binutils
            ]);

            # if we wanted to make further bodifications 
            # to the FHS dir
            #extraBuildCommands = "
            #  #ln -s ${file} usr/bin/file
            #";

            # dunno what is this even
            #extraInstallCommands = "
            #";
          });
        in [
          util-linux
          perl
          which
          unzip
          fhs-env
          pkgs.gcc.cc.lib
          pkgs.autoPatchelfHook
        ];

        buildPhase = let
          buildScript = pkgs.writeText "buildroot-initrd-build" ''
            export PATH=/bin:/sbin:/usr/bin:/usr/sbin
            make -j $(nproc)
          '';
        in ''
          buildroot-env ${buildScript}
        '';

        installPhase = ''
          mkdir -p $out
          mv output $out/
        '';
      };

      defaultPackage.x86_64-linux = self.packages.x86_64-linux.coreboot-initrd;

    };
}
