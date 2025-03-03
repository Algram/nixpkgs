{ lib, stdenv, fetchurl, cmake, python2, boost, libuuid, ruby, buildEnv, buildPythonPackage, qpid-python }:

let
  pname = "qpid-cpp";
  name = "${pname}-${version}";
  version = "1.39.0";

  src = fetchurl {
    url = "mirror://apache/qpid/cpp/${version}/${name}.tar.gz";
    sha256 = "088dx1l6myrksbhpr15bs09j6qm8vdliqwjp2ja5amym47md103r";
  };

  meta = with lib; {
    homepage = "https://qpid.apache.org";
    description = "An AMQP message broker and a C++ messaging API";
    license = licenses.asl20;
    platforms = platforms.linux;
    maintainers = with maintainers; [ cpages ];
  };

  qpid-cpp = stdenv.mkDerivation {
    inherit src meta pname version;

    nativeBuildInputs = [ cmake ];
    buildInputs = [ boost libuuid ruby python2 ];

    # the subdir managementgen wants to install python stuff in ${python} and
    # the installation tries to create some folders in /var
    postPatch = ''
      sed -i '/managementgen/d' CMakeLists.txt
      sed -i '/ENV/d' src/CMakeLists.txt
      sed -i '/management/d' CMakeLists.txt
    '';

    NIX_CFLAGS_COMPILE = toString ([
      "-Wno-error=deprecated-declarations"
      "-Wno-error=int-in-bool-context"
      "-Wno-error=maybe-uninitialized"
      "-Wno-error=unused-function"
      "-Wno-error=ignored-qualifiers"
      "-Wno-error=catch-value"
    ] ++ lib.optionals stdenv.cc.isGNU [
      "-Wno-error=deprecated-copy"
    ]);
  };

  python-frontend = buildPythonPackage {
    inherit pname version meta src;

    sourceRoot = "${name}/management/python";

    propagatedBuildInputs = [ qpid-python ];
  };
in buildEnv {
  name = "${name}-env";
  paths = [ qpid-cpp python-frontend ];
}
