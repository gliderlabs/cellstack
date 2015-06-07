
init() {
  cmd-export-ns blueprint
  cmd-export blueprint-init
  cmd-export blueprint-add
}

blueprint-init() {
  declare blueprint="$1" cell="${2:-standard}"
  : "${blueprint:?}"
  if [[ -d "blueprints/$blueprint" ]]; then
    echo "Blueprint '$blueprint' already exists."
    exit 2
  fi
  mkdir -p "blueprints/$blueprint"
  echo "export CELL_TYPE=$cell" > "blueprints/$blueprint/cell.bash"
}

blueprint-add() {
  declare blueprint="$1" infra="$2" as="$3"
  : "${blueprint:?}" "${infra:?}"
  if [[ ! "$as" ]]; then
    as="$infra"
  fi
  if [[ ! -d "infra/$infra" ]]; then
    echo "Infra '$infra' not found in library."
    exit 2
  fi
  mkdir -p "blueprints/$blueprint/$as"
  echo "export CELL_INFRA=$infra" > "blueprints/$blueprint/$as/infra.bash"
  #shopt -s nullglob
  #for path in infra/$infra/*.example; do
  #  local filename="$(basename $path)"
  #  cp $path "blueprints/$blueprint/$as/${filename%%.example}"
  #done
}
