{
  inputs.incrementalize = {
    url = "/nix/store/lbr8af7haw744cn4x8qg3ql8ng7s8gxm-source";
  };
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";
  outputs = { nixpkgs, incrementalize, ... } : {
    packages.x86_64-linux.default =
     let pkgs = nixpkgs.legacyPackages.x86_64-linux;
         prev = if incrementalize ? outputs.packages.x86_64-linux.default.out
                then builtins.readFile incrementalize.outputs.packages.x86_64-linux.default.out
                else "";
      in pkgs.stdenv.mkDerivation {
           name = "test";
           system = "x86_64-linux";
           src = ./.;
           buildPhase = ''
              ${pkgs.coreutils}/bin/touch $out
              echo "${prev}hi" > $out
              ls
           '';
       };
  };
}
