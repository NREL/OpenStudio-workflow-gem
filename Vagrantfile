# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.require_version ">= 1.5.0"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  is_windows = (RUBY_PLATFORM =~ /mswin|mingw|cygwin/)
  use_nfs = !is_windows

  config.vm.hostname = "openstudio-workflow"
  config.omnibus.chef_version = :latest

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "opscode-ubuntu-12.04"
  config.vm.box_url = "https://opscode-vm-bento.s3.amazonaws.com/vagrant/opscode_ubuntu-12.04_provisionerless.box"
  #config.vm.box = "centos64-nrel-x86_64"
  #config.vm.box_url = "http://developer.nrel.gov/downloads/vagrant-boxes/CentOS-6.4-x86_64-v20130731.box"

  config.vm.network :private_network, type: 'dhcp' 
  config.vm.network "forwarded_port", guest: 27017, host: 27018
  config.vm.synced_folder ".", "/data/openstudio-workflow", :nfs => use_nfs
  if File.exist? "../assetscore-openstudio"
    config.vm.synced_folder "../assetscore-openstudio", "/data/assetscore-openstudio", :nfs => use_nfs
  end

  config.vm.provider :virtualbox do |p|
    nc = 1
    p.customize ["modifyvm", :id, "--memory", nc*2048, "--cpus", nc]
  end

  config.berkshelf.enabled = true
  config.vm.provision :chef_solo do |chef|
    chef.json = {
        :openstudio => {
            :version => "1.3.3",
            :installer => {
                :version_revision => "74c3859219"
            }
        },
        :mongodb => {
            :install_method => "10gen",
            :package_version => "2.4.10"
        }
    }
    chef.run_list = [
        "recipe[openstudio::default]",
        "recipe[mongodb::default]",
	"recipe[zip::default]"
    ]
  end
end
