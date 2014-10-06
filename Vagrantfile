# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.require_version ">= 1.5.0"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  is_windows = (RUBY_PLATFORM =~ /mswin|mingw|cygwin/)
  use_nfs = !is_windows

  config.berkshelf.enabled = true

  config.vm.define "package" do |package|
    package.vm.hostname = "openstudio-workflow"
    package.omnibus.chef_version = :latest

    package.vm.provider :virtualbox do |p|
      nc = 1
      p.customize ["modifyvm", :id, "--memory", nc*2048, "--cpus", nc]
    end
    # Every Vagrant virtual environment requires a box to build off of.
    package.vm.box = "ubuntu/trusty64"

    package.vm.network :private_network, ip: "192.168.34.10"
    package.vm.network :private_network, type: 'dhcp'
    package.vm.network "forwarded_port", guest: 27017, host: 27018
    package.vm.synced_folder ".", "/data/openstudio-workflow", :nfs => use_nfs
    if File.exist? "../assetscore-openstudio"
      package.vm.synced_folder "../assetscore-openstudio", "/data/assetscore-openstudio", :nfs => use_nfs
    end
  end

  config.vm.define "source", autostart: false do |source|
    source.vm.hostname = "openstudio-workflow-source"
    source.omnibus.chef_version = :latest

    source.vm.provider :virtualbox do |p|
      nc = 2
      p.customize ["modifyvm", :id, "--memory", nc*2048, "--cpus", nc]
    end
    # Every Vagrant virtual environment requires a box to build off of.
    source.vm.box = "ubuntu/trusty64"

    source.vm.network :private_network, ip: "192.168.34.11"
    source.vm.network :private_network, type: 'dhcp'
    source.vm.network "forwarded_port", guest: 27017, host: 27018
    source.vm.synced_folder ".", "/data/openstudio-workflow", :nfs => use_nfs
    source.vm.synced_folder "../openstudio", "/home/vagrant/openstudio", :nfs => use_nfs
    if File.exist? "../assetscore-openstudio"
      source.vm.synced_folder "../assetscore-openstudio", "/data/assetscore-openstudio", :nfs => use_nfs
    end
  end

  config.vm.provision :chef_solo do |chef|
    chef.json = {
        :openstudio => {
            :version => "1.5.0",
            :installer => {
                :version_revision => "78d7c6dca9",
                :platform => "Linux-Ruby2.0"
            }
        },
        :mongodb => {
            # These first 4 are per this pull request: https://github.com/edelight/chef-mongodb/pull/262
            # They should be fixed soon, at which point the defaults will work again.
            :dbconfig_file => '/etc/mongod.conf',
            :sysconfig_file => '/var/lib/mongo',
            :default_init_name => 'mongod',
            :instance_name => 'mongod',
            :package_version => "2.6.4",
            :install_method => 'mongodb-org',
            :config => {
                :dbpath => "/mnt/mongodb/data",
                :logpath => '/var/log/mongo/mongod.log'
            }
        }
    }
    chef.run_list = [
        "recipe[openstudio::default]",
        "recipe[mongodb::default]",
	      "recipe[zip::default]"
    ]
  end
end
