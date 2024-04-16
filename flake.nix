{
  inputs.openlane2.url = "github:efabless/openlane2";
  inputs.openlane2.inputs.nixpkgs.follows = "nixpkgs";

  inputs.poetry2nix.url = "github:KoviRobi/poetry2nix/tinytapeout-deps";
  inputs.poetry2nix.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, openlane2, poetry2nix }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        p2n = poetry2nix.lib.mkPoetry2Nix { inherit pkgs; };

        # The dockerTools build creates a package only containing what you
        # specify -- it's worth specifying some other common tools
        docker_packages = [
          pkgs.bashInteractive
          pkgs.curl
          pkgs.util-linux
          pkgs.coreutils
          pkgs.gnused
          pkgs.gawk
        ];

        build_packages = [
          pkgs.bluespec
          pkgs.yosys
          pkgs.yosys-bluespec
          self.packages.${system}.tt-tools.pkgs.tt-support-tools
          self.packages.${system}.tt-tools.pkgs.gds2gltf
          openlane2.packages.${system}.openlane
          openlane2.packages.${system}.volare
        ];

        dev_packages = [
          pkgs.gtkwave
          pkgs.verilog
          pkgs.verilator
          pkgs.xdot # For yosys show
          pkgs.poetry
          pkgs.netlistsvg

          pkgs.nodejs # For the gds viewer

          pkgs.clang # for verilator
          self.packages.${system}.tt-tools.pkgs.cocotb
          self.packages.${system}.tt-tools.pkgs.cocotb-test
          self.packages.${system}.tt-tools.pkgs.pytest
          self.packages.${system}.tt-tools.pkgs.hypothesis
        ];
      in
      {
        packages = {

          tt-tools = p2n.mkPoetryEnv {
            projectDir = self;
            overrides = p2n.overrides.withDefaults (final: prev: {

              find-libpython = prev.find-libpython.overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ [ final.setuptools ];
              });

              cocotb = prev.cocotb.overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ [ final.setuptools ];
              });

              cocotb-test = prev.cocotb-test.overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ [ final.setuptools ];
              });

              gds2gltf = prev.gds2gltf.overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ [ final.poetry ];
              });

              tt-support-tools = prev.tt-support-tools.overridePythonAttrs (old: {
                buildInputs = (old.buildInputs or [ ]) ++ [ final.poetry final.poetry-dynamic-versioning ];
              });

            });
          };

          docker-image = pkgs.dockerTools.streamLayeredImage {
            name = "TinyTapeout-build-env";
            tag = "tt06";

            contents = docker_packages ++ build_packages;
            config.Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
          };

        };

        devShells.default = pkgs.mkShell {
          packages = build_packages ++ dev_packages;
        };
      });
}
