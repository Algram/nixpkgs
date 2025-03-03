{ lib, stdenv, fetchFromGitHub, writeScript, cmake }:

stdenv.mkDerivation rec {
  pname = "rocm-cmake";
  version = "5.0.2";

  src = fetchFromGitHub {
    owner = "RadeonOpenCompute";
    repo = "rocm-cmake";
    rev = "rocm-${version}";
    hash = "sha256-4PtLe864MQ9wUn+l1fshiiTQvP06ewD39TDYZl70Hgg=";
  };

  nativeBuildInputs = [ cmake ];

  passthru.updateScript = writeScript "update.sh" ''
    #!/usr/bin/env nix-shell
    #!nix-shell -i bash -p curl jq common-updater-scripts
    version="$(curl -sL "https://api.github.com/repos/RadeonOpenCompute/rocm-cmake/tags" | jq '.[].name | split("-") | .[1] | select( . != null )' --raw-output | sort -n | tail -1)"
    update-source-version rocm-cmake "$version"
  '';

  meta = with lib; {
    description = "CMake modules for common build tasks for the ROCm stack";
    homepage = "https://github.com/RadeonOpenCompute/rocm-cmake";
    license = licenses.mit;
    maintainers = with maintainers; [ ];
    platforms = platforms.unix;
  };
}
