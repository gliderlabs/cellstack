
init() {
  module-load-dir "module"
}

cellstack-clean() {
  echo "Gunfile" > .clean
  ls -1d blueprints/*/ 2> /dev/null >> .clean || true
  ls -1 cmds/* \
    | grep -v cellstack.bash \
    | grep -v readme.txt \
    >> .clean || true
  cat .clean
  echo
  read -p "Are you sure you want to 'rm -rf' these files [y]? " -n 1 -r
  echo
  if [[ "$REPLY" == "y" ]]; then
    cat .clean | xargs -L1 rm -rf
  fi
  rm .clean
}
