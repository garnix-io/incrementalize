{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/release-24.05";

  outputs = { nixpkgs, self } :

  let wantedAttrs = ["packages" "checks" "devShells"];
  in {
    # 'withCaches is meant to wrap the entire 'outputs'. It
    # allows any 'checks'/'packages' to have an extra argument,
    # the cache. E.g.:
    #
    # {
    #  inputs.nixpkgs.url = "..."
    #  inputs.incrementalize.url = "github:garnix-io/incrementalize";
    #  outputs = { nixpkgs, ...} : incrementalize.lib.withCaches {
    #     packages.x86_64.default = cache: ...;
    #  };
    # }
    #
    # If referencing one another the outputs should use 'self', since there
    # the output will not be a function.
    lib.withCaches = self.lib.withCachesFor {};

    lib.withCachesFor = prev: outputs:
     let emptyDerivation = system:
           let pkgs = nixpkgs.legacyPackages.${system};
           in derivation {
             name = "emptyDerivation";
             system = system;
             builder = "/bin/sh";
             args = ["-c" ''
                ${pkgs.coreutils}/bin/mkdir $out
             ''];
             };
      in (builtins.mapAttrs (type:
           builtins.mapAttrs (sys:
             builtins.mapAttrs (pkg: def:
               if builtins.elem type wantedAttrs && builtins.isFunction def
               then (def (prev.${type}.${sys}.${pkg}.intermediates or emptyDerivation sys))
               else def
             )))) outputs;


    # nix-unit tests
    tests = {
      testAppliesFunctionArguments = {
        description = ''
          Package arguments that are functions should be applied to the cache
        '';
        expr =
          let flake = self.lib.withCaches {
            packages.x86_64-linux.foo = cache : cache;
          };
          in flake.packages.x86_64-linux.foo.name;
        expected = "emptyDerivation";
      };

      testDoesNothingWhenNotFunction = {
        description = ''
          Package arguments that are not functions should be applied returned unmodified
        '';
        expr =
          let flake = self.lib.withCaches {
            packages.x86_64-linux.foo = 1781;
          };
          in flake.packages.x86_64-linux.foo;
        expected = 1781;
      };
    };

    checks.x86_64-linux.unitTests =
     let pkgs = nixpkgs.legacyPackages.x86_64-linux;
     in pkgs.runCommand "unitTests"
        {
          nativeBuildInputs = [ pkgs.nix-unit ];
        } ''
        export HOME="$(realpath .)"
        # The nix derivation must be able to find all used inputs in the nix-store because it cannot download it during buildTime.
        ${pkgs.nix-unit}/bin/nix-unit --eval-store "$HOME" \
          --extra-experimental-features flakes \
          --override-input nixpkgs ${nixpkgs} \
          --flake ${self}#tests
        touch $out
    '';

    devShells.x86_64-linux.default =
      let pkgs = nixpkgs.legacyPackages.x86_64-linux;
       in pkgs.mkShell {
         packages = [
            pkgs.nix-unit
         ];
       };
  };

}
