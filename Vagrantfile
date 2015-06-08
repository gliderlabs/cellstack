# -*- mode: ruby -*-

Vagrant.configure(2) do |config|
  config.vm.define("core-01") {|c|}
  config.vm.box         = "coreos-%s" % (ENV["VAGRANT_CHANNEL"] || "stable")
  config.vm.box_version = "0" if File.exists? ".vagrant/baked.box"
  config.vm.hostname    = "core-01"
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.vm.network :forwarded_port,
    guest:        2375,
    host:         2375,
    auto_correct: true

  config.ssh.insert_key = false
  config.ssh.username   = "core"

  config.vm.provider :virtualbox do |v|
    v.memory                = (ENV["VAGRANT_MEMORY"] || 2048).to_i
    v.cpus                  = (ENV["VAGRANT_CPUS"] || 1).to_i
    v.check_guest_additions = false
    v.functional_vboxsf     = false
    v.gui                   = false
  end

  if Vagrant.has_plugin?("vagrant-vbguest") then
    config.vbguest.auto_update = false
  end

  if ENV["VAGRANT_CONFIG"] and File.exist? ENV["VAGRANT_CONFIG"]
    config.vm.provision :file,
      source:       "#{ENV["VAGRANT_CONFIG"]}",
      destination:  "/tmp/vagrantfile-user-data"
    config.vm.provision :shell,
      inline:       "mv /tmp/vagrantfile-user-data /var/lib/coreos-vagrant/",
      privileged:   true
  end
  config.vm.provision :shell,
    inline: ENV['VAGRANT_PROVISION'].dup if ENV['VAGRANT_PROVISION']
end
