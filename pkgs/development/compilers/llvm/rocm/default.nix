{ stdenv, lib, buildPackages, fetchFromGitHub, callPackage, wrapCCWith, overrideCC }:

let
  version = "5.0.2";
  src = fetchFromGitHub {
    owner = "RadeonOpenCompute";
    repo = "llvm-project";
    rev = "rocm-${version}";
    hash = "sha256-wPzwbeQUFE6RAytrz5lBa6UUPoVL0UeMyY3qa4M6W6M=";
  };
in rec {
  clang = wrapCCWith rec {
    cc = clang-unwrapped;
    extraBuildCommands = ''
      clang_version=`${cc}/bin/clang -v 2>&1 | grep "clang version " | grep -E -o "[0-9.-]+"`
      rsrc="$out/resource-root"
      mkdir "$rsrc"
      ln -s "${cc}/lib/clang/$clang_version/include" "$rsrc"
      ln -s "${compiler-rt}/lib" "$rsrc/lib"
      echo "-resource-dir=$rsrc" >> $out/nix-support/cc-cflags
      echo "--gcc-toolchain=${stdenv.cc.cc}" >> $out/nix-support/cc-cflags
      echo "-Wno-unused-command-line-argument" >> $out/nix-support/cc-cflags
      rm $out/nix-support/add-hardening.sh
      touch $out/nix-support/add-hardening.sh
    '';
  };

  clangNoCompilerRt = wrapCCWith rec {
    cc = clang-unwrapped;
    extraBuildCommands = ''
      clang_version=`${cc}/bin/clang -v 2>&1 | grep "clang version " | grep -E -o "[0-9.-]+"`
      rsrc="$out/resource-root"
      mkdir "$rsrc"
      ln -s "${cc}/lib/clang/$clang_version/include" "$rsrc"
      echo "-resource-dir=$rsrc" >> $out/nix-support/cc-cflags
      echo "--gcc-toolchain=${stdenv.cc.cc}" >> $out/nix-support/cc-cflags
      echo "-Wno-unused-command-line-argument" >> $out/nix-support/cc-cflags
      rm $out/nix-support/add-hardening.sh
      touch $out/nix-support/add-hardening.sh
    '';
  };

  clang-unwrapped = callPackage ./clang.nix {
    inherit lld llvm version;
    src = "${src}/clang";
  };

  compiler-rt = callPackage ./compiler-rt {
    inherit version llvm;
    inherit src;
    stdenv = overrideCC stdenv clangNoCompilerRt;
  };

  lld = callPackage ./lld.nix {
    inherit llvm version;
    src = "${src}/lld";
  };

  llvm = callPackage ./llvm {
    inherit version;
    src = "${src}/llvm";
  };
}
