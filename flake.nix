{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  outputs = {
    self,
    nixpkgs,
  }: {
    packages = nixpkgs.lib.genAttrs ["x86_64-linux"] (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
        static = pkgs.pkgsStatic;
        monero-cli-static = (static.monero-cli.override {trezorSupport = false;}).overrideAttrs (old: {
          postPatch =
            ''
              substituteInPlace CMakeLists.txt \
                --replace-fail \
                  'if (NOT (CMAKE_SYSTEM_NAME MATCHES "kOpenBSD.*|OpenBSD.*") AND NOT OSSFUZZ)' \
                  'if (NOT (CMAKE_SYSTEM_NAME MATCHES "kOpenBSD.*|OpenBSD.*") AND NOT OSSFUZZ AND BUILD_SHARED_LIBS)' \
                --replace-fail \
                  "set(BOOST_COMPONENTS filesystem thread date_time chrono serialization program_options locale)" \
                  "set(BOOST_COMPONENTS filesystem thread date_time chrono serialization program_options)"

              substituteInPlace src/wallet/CMakeLists.txt \
                --replace-fail "if(NOT IOS)" "if(FALSE)"
            ''
            + (old.postPatch or "");
          cmakeFlags =
            (old.cmakeFlags or [])
            ++ [
              "-DSTACK_TRACE=OFF"
              "-DUSE_DEVICE_TREZOR=OFF"
              "-DUNBOUND_LIBRARIES=${static.unbound.lib}/lib/libunbound.a;${static.libevent}/lib/libevent.a"
            ];
          buildInputs = (old.buildInputs or []) ++ [static.libevent];
        });
      in {
        inherit monero-cli-static;
        default = monero-cli-static;
      }
    );

    devShells = nixpkgs.lib.genAttrs ["x86_64-linux"] (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        default = pkgs.mkShell {
          packages = [self.packages.${system}.monero-cli-static];
        };

        source-text-analyze = pkgs.mkShell {
          packages = [
            pkgs.statix
            pkgs.deadnix
            pkgs.nixfmt
            pkgs.alejandra
          ];
        };
      }
    );
  };
}
