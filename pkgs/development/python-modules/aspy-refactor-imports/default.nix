{ lib
, buildPythonPackage
, fetchFromGitHub
, pytestCheckHook
, pythonOlder
}:

buildPythonPackage rec {
  pname = "aspy-refactor-imports";
  version = "3.0.1";
  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "asottile";
    repo = "aspy.refactor_imports";
    rev = "v${version}";
    sha256 = "MlCM3zNTQZJ1RWrTQG0AN28RUepWINKCeLENykbu2nw=";
  };

  pythonImportsCheck = [
    "aspy.refactor_imports"
  ];

  checkInputs = [
    pytestCheckHook
  ];

  meta = with lib; {
    description = "Utilities for refactoring imports in python-like syntax.";
    homepage = "https://github.com/asottile/reorder_python_imports";
    license = licenses.mit;
    maintainers = with maintainers; [ gador ];
  };
}
