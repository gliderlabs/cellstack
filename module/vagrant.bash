
export VAGRANT_CHANNEL="${VAGRANT_CHANNEL:-stable}"

vagrant_cmd="$(which vagrant)"

init() {
  cmd-export-ns vagrant
  cmd-export vagrant-init
  cmd-export vagrant-bake
  cmd-export vagrant-unbake
  cmd-export vagrant-apply
}

vagrant-init() {
  if ! $vagrant_cmd box list | grep "coreos-$VAGRANT_CHANNEL" > /dev/null; then
    $vagrant_cmd box add "http://$VAGRANT_CHANNEL.release.core-os.net/amd64-usr/current/coreos_production_vagrant.json"
  fi
}

vagrant-apply() {
  sigil -f "$GUN_ROOT/vagrant/host.conf.tmpl" \
    > "$GUN_ROOT/.vagrant/host.conf"
  export VAGRANT_CONFIG="$GUN_ROOT/.vagrant/host.conf"
  $vagrant_cmd destroy -f
  $vagrant_cmd up
}

vagrant-bake() {
  export VAGRANT_PROVISION="$(sigil -f templates/bake.tmpl)"
  $vagrant_cmd destroy -f
  $vagrant_cmd up
  rm -rf "$GUN_ROOT/.vagrant/baked.box"
  $vagrant_cmd package --output "$GUN_ROOT/.vagrant/baked.box"
  $vagrant_cmd box add -f "coreos-$VAGRANT_CHANNEL" "$GUN_ROOT/.vagrant/baked.box"
}

vagrant-unbake() {
  $vagrant_cmd destroy -f
  rm -rf "$GUN_ROOT/.vagrant/baked.box"
}
