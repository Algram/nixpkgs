{ lib, stdenv, fetchFromGitHub, qt4, qmake4Hook, trousers }:

stdenv.mkDerivation rec {
  version = "0.8.1";
  pname = "tpmmanager";

  src = fetchFromGitHub {
    owner = "Rohde-Schwarz";
    repo = "TPMManager";
    rev = "v${version}";
    sha256 = "sha256-JKYG+I/tZ+0NDmHcIgKV6eGrjbPvPQKPo0sE/zBlLY4=";
  };

  nativeBuildInputs = [ qmake4Hook ];

  buildInputs = [ qt4 trousers ];

  installPhase = ''
    mkdir -p $out/bin
    install -Dpm755 -D bin/tpmmanager $out/bin/tpmmanager

    mkdir -p $out/share/applications
    cat > $out/share/applications/tpmmanager.desktop <<EOF
    [Desktop Entry]
    Type=Application
    Version=1.0
    Name=tpmmanager
    Comment=TPM manager
    Exec=$out/bin/tpmmanager
    Terminal=false
    EOF
    '';

  meta = {
    homepage = "https://projects.sirrix.com/trac/tpmmanager";
    description = "Tool for managing the TPM";
    license = lib.licenses.gpl2;
    maintainers = with lib.maintainers; [ tstrobel ];
    platforms = with lib.platforms; linux;
  };
}
