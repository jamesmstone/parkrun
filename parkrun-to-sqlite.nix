{
  lib,
  buildPythonApplication,
  fetchPypi,
  setuptools,
}:
buildPythonApplication rec {
  pname = "parkrun-to-sqlite";
  version = "0.7";
  pyproject = true;

  src = fetchPypi {
    pname = "parkrun_to_sqlite";
    inherit version;
    hash = "sha256-J750+5oiVa+rquqg1AbGOWB9aChOmEnwfJiffXHrHDA=";
  };

  build-system = [setuptools];

  # The sdist ships the test module but not the results.html fixture it reads.
  doCheck = false;

  pythonImportsCheck = ["parkrun_to_sqlite"];

  meta = {
    description = "Create a SQLite database containing your parkruns";
    homepage = "https://github.com/mwoodbri/parkrun-to-sqlite";
    license = lib.licenses.mit;
    mainProgram = "parkrun-to-sqlite";
  };
}
