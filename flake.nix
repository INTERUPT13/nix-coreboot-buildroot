{
  description = "A very basic flake";

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
      url = "https://github.com/INTERUPT13/nix-coreboot-initrd-buildroot-deps";
      type = "git";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, buildroot-src, buildroot-deps }:  with import nixpkgs {system="x86_64-linux";};
  let
    pkgs-unstable = import nixpkgs-unstable { system="x86_64-linux"; };
  in {
    packages.x86_64-linux.hello = stdenv.mkDerivation {
      name = "coreboot-linux-initrd";
      src = buildroot-src;

      hardeningDisable = [ "format" ];

      postUnpack = ''
        cp ${self}/buildroot_config.config source/.config
        mkdir -p source/output
        cp -r ${buildroot-deps}/ source/output/build
        chmod u+w -R source/output/build
      '';


      nativeBuildInputs = [
        pkg-config
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
        pkgs-unstable.automake
        gperf
        help2man
        texinfo
        gmp
        mpfr
      ];

      buildPhase = ''
        make -j $(nproc)
      '';
    };

    defaultPackage.x86_64-linux = self.packages.x86_64-linux.hello;

  };
}
