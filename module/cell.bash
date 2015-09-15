
export SIGIL_PATH="$PWD/services:$PWD/templates:$PWD"

export ATLAS_USER="${ATLAS_USER:-$USER}"
export EC2_KEYNAME="${EC2_KEYNAME:-$USER}"
export EC2_KEYFILE="${EC2_KEYFILE:-~/.ssh/id_rsa}"

export CELL_CHANNEL="${CELL_CHANNEL:-stable}"
export CELL_ZONES="${CELL_ZONES:-b,c,d}"
export CELL_REGION="${CELL_REGION:-us-east-1}"

declare cell_rundir

init() {
  cmd-export cell-profile profile
  #cmd-export cell-init init
  cmd-export cell-apply apply
  cmd-export cell-plan plan
  cmd-export cell-destroy destroy
  cmd-export cell-output output
  cmd-export cell-taint taint
  cmd-export cell-bake bake
}

coreos-ami() {
	declare region="$1" channel="$2"
	curl -s "http://${channel:?}.release.core-os.net/amd64-usr/current/coreos_production_ami_hvm_${region:?}.txt"
}

user-ami() {
  declare region="$1" name="$2"
  aws --output json \
    ec2 --region "$region" \
    describe-images \
      --owners self \
      --filters "Name=name,Values=$name" \
      | jq -r '.Images[0].ImageId'
}

cell-rundir() {
  if [[ ! "$cell_rundir" ]]; then
    mkdir -p "$GUN_ROOT/.gun/runs"
    cell_rundir="$GUN_ROOT/.gun/runs/$(ls -1Ut $GUN_ROOT/.gun/runs/ | grep "$GUN_PROFILE-" | head -n 1)"
  fi
  echo "${cell_rundir:?}"
}

cell-rundir-old() {
  ls -1Utr "$GUN_ROOT/.gun/runs/" \
    | grep "$GUN_PROFILE-" \
    | sed '$d' \
    | sed '$d' \
    | sed '$d' \
    | sed "s|^|$GUN_ROOT/.gun/runs/|"
}

cell-rundir-new() {
  cell_rundir="$GUN_ROOT/.gun/runs/$GUN_PROFILE-$(date +%s)"
  mkdir -p "$cell_rundir"
  cell-rundir-old | xargs rm -rf
}

cell-profile() {
  declare name="$1" blueprint="$2"
  echo "export CELL_NAME=$name"
  echo "export CELL_BLUEPRINT=$blueprint"
}

cell-plan() {
  declare target="$1"
  cell-action "$target" "plan -input=false"
}

cell-apply() {
  declare target="$1"
  cell-action "$target" "apply -input=false"
}

cell-destroy() {
  declare target="$1"
  cell-action "$target" "destroy -force -input=false"
}

cell-output() {
  declare output="$1" target="$2"
  if [[ ! "$target" ]]; then
    target=".cell"
  fi
  pushd "$(cell-rundir)/$target" > /dev/null
  terraform output $output
  popd > /dev/null
}

cell-taint() {
  declare name="$1" target="$2"
  if [[ ! "$target" ]]; then
    target=".cell"
  fi
  pushd "$(cell-rundir)/$target" > /dev/null
  # XXX include additional options
  terraform taint $name
  popd > /dev/null
}

#cell-init() {
#  local stack_dir="$(dirname $BASH_SOURCE)/stack"
#  cp -r $stack_dir/* .
#  mkdir blueprints
#  mkdir .vagrant
#}

cell-bake() {
  cell-apply "cell"
  local vpc_id subnet_id ami_name region ami_id
  vpc_id="$(cell-output vpc_id)"
  region="$(cell-output region)"
  subnet_id="$(cell-output subnet_ids | awk -F, '{print $1}')"
  ami_name="$GUN_PROFILE-$(date +%s)"
  sigil -f templates/packer.tmpl \
    "vpc_id=$vpc_id" \
    "subnet_id=$subnet_id" \
    "region=$region" \
    "ami_name=$ami_name" \
    "ami_source=${CELL_AMI:-$(coreos-ami $region $CELL_CHANNEL)}" \
    | packer build -
  ami_id="$(user-ami "$region" "$ami_name")"
  sed -i '' -e '/^export CELL_AMI=.*$/d' "$GUN_ROOT/Gunfile.$GUN_PROFILE"
  echo "export CELL_AMI=${ami_id:?}" >> "$GUN_ROOT/Gunfile.$GUN_PROFILE"
}

cell-action() {
  declare target="$1" action="$2"
  cell-prepare-run "$CELL_BLUEPRINT"
  if [[ "$target" ]]; then
    cell-tf "$target" "$action"
  else
    if [[ ! "$action" =~ destroy ]]; then
      cell-tf "cell" "$action"
    fi
    for dir in $(cell-rundir)/*/; do
      local target="$(basename ${dir%%/})"
      cell-tf "$target" "$action"
    done
    if [[ "$action" =~ destroy ]]; then
      cell-tf "cell" "$action"
    fi
  fi
}

cell-prepare-run() {
  cell-rundir-new
  cp -r blueprints/$CELL_BLUEPRINT/* "$(cell-rundir)"
  pushd "$(cell-rundir)" > /dev/null
  export SIGIL_PATH="$PWD:$SIGIL_PATH"
  source cell.bash
  shopt -s nullglob
  for infra_file in **/infra.bash; do
    source "$infra_file"
    pushd "$(dirname $infra_file)" > /dev/null
    terraform init \
      -backend=atlas \
      -backend-config="name=$ATLAS_USER/$CELL_NAME-$CELL_INFRA" \
      "$GUN_ROOT/infra/$CELL_INFRA" . > /dev/null
    echo "export TF_VAR_cell=$ATLAS_USER/$CELL_NAME" >> infra.bash
    popd > /dev/null
  done
  shopt -u nullglob
  mkdir -p .cell
  pushd .cell > /dev/null
  terraform init \
    -backend=atlas \
    -backend-config="name=$ATLAS_USER/$CELL_NAME" \
    "$GUN_ROOT/$(dirname $BASH_SOURCE)/infra/cell-$CELL_TYPE" . > /dev/null
  echo "export TF_VAR_name=$CELL_NAME" > cell.bash
  popd > /dev/null
  popd > /dev/null
}

cell-tf() {
  declare target="$1" args="$2"
  if [[ "$target" == "cell" ]]; then
    target=".cell"
  fi
  pushd "$(cell-rundir)/$target" > /dev/null
  terraform-configure
  terraform remote pull > /dev/null
  terraform get > /dev/null
  shopt -s nullglob
  for tmpl in *.tmpl; do
    sigil -f $tmpl > ${tmpl%%.tmpl}
  done
  (
    for config in *.bash; do
      source $config
    done
    terraform $args
  )
  popd > /dev/null
}

terraform-configure() {
  export TF_VAR_secret_key="$AWS_SECRET_ACCESS_KEY"
  export TF_VAR_access_key="$AWS_ACCESS_KEY_ID"
  export TF_VAR_key_name="$EC2_KEYNAME"
  export TF_VAR_key_file="$EC2_KEYFILE"
  export TF_VAR_region="$CELL_REGION"
  export TF_VAR_zones="$CELL_ZONES"
  export TF_VAR_ami="${CELL_AMI:-$(coreos-ami $CELL_REGION $CELL_CHANNEL)}"
  export TF_VAR_zone_count="$(echo $CELL_ZONES | awk -F, '{print NF}')"
}
