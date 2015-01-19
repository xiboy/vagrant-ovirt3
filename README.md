# Vagrant oVirt/RHEV v3 Provider

This is a [Vagrant](http://www.vagrantup.com) 1.1+ plugin that adds an
[oVirt v3](http://ovirt.org) and
[rhev v3](http://www.redhat.com/products/virtualization/) provider to Vagrant,
allowing Vagrant to control and provision machines in oVirt and RHEV.

In this document, both oVirt and RHEV names are used interchangeably and
represent the same platform on top of which this provider should work.

## Version 1.1.2
* Added missing certificate options and fixed usage on `ca_no_verify`

## Version 1.1.1
* Added missing locales
* Fixed box url in usage

## Version 1.1.0
* Added `ca_no_verify` configuration parameter to allow self-signed certificates, etc.
* Fixed missing RsyncError locale lookup
* Fixed base dummy box
* Removed default provider, breaks with Vagrant 1.7
* Fix broken EPEL EL7 link.
* Check whether synced folder is disabled before trying to rsync.

## Version 1.0.0
* Complete overhaul of naming schemes. Vagrant-ovirt upstream is deprecated. The provider going forward is 'ovirt3' to allow gem/plugin availability.
* Volumes are automatically resized

## Version 0.2.1
* Removed automatic resizing, will be readded when upstream fog changes are committed to rubygems.org

## Features (Version 0.2.0)
* ~~Volumes are automatically resized~~
* Replaced configuration to get IP configuration with REST API usage

## Features (Version 0.1.0)

* Vagrant `up` and `destroy` commands.
* Create and boot oVirt machines from templates.
* SSH into domains.
* Provision domains with any built-in Vagrant provisioner.
* Minimal synced folder support via `rsync`.

## Future work

* Validation of configuration parameters.
* Test it on other versions of oVirt and RHEV.
* Template preparation scripts for other distros than RHEL.
* Vagrant commands `halt`, `resume`, `ssh`, `provision`, `suspend` and `resume`.
* Take a look at [open issues](https://github.com/myoung34/vagrant-ovirt3/issues?state=open).

## Installation

```
$ vagrant plugin install vagrant-ovirt3
$ vagrant up --provider=ovirt3
```

## Vagrant Project Preparation

Create a Vagrantfile that looks like the following, filling in
your information where necessary.

```ruby
Vagrant.configure('2') do |config|
  config.vm.box = 'ovirt'
  config.vm.box_url = 'https://github.com/myoung34/vagrant-ovirt3/blob/master/example_box/dummy.box?raw=true'

  config.vm.network :private_network, 
    :ip => '192.168.56.100', :nictype => 'virtio', :netmask => '255.255.255.0', #normal network configuration
    :ovirt__ip => '10.101.55.72', :ovirt__network_name => 'ovirtmgmt', :ovirt__gateway => '10.101.55.1' # oVirt specific information, overwrites previous on oVirt provider
    
  config.vm.provider :ovirt3 do |ovirt|
    ovirt.template = 'template'
    ovirt.cpus = 1
    ovirt.memory = 1024
    ovirt.console = 'vnc' #could also be 'spice'
    ovirt.url = 'https://youroVirtmaster:443'
    ovirt.username = 'username'
    ovirt.password = 'password'
    ovirt.datacenter = 'datacenter'
  end
end
```

### RHEV/oVirt Configuration Options

This provider exposes quite a few provider-specific configuration options:

* `url` - URL to management interface.
* `username` - Username to access oVirt.
* `password` - Password to access oVirt.
* `datacenter` - oVirt datacenter name, where machines will be created.
* `cluster` - oVirt cluster name. Defaults to first cluster found.
* `ca_no_verify` - Set to `true` to not verify TLS certificates.

### Domain Specific Options

* `memory` - Amount of memory in MBytes. Defaults to 512 if not set.
* `cpus` - Number of virtual cpus. Defaults to 1 if not set.
* `template` - Name of template from which new VM should be created.
* `console` - Console type to use. Can be 'vnc' or 'spice'. Default is 'spice'
* `disk_size` - If set, the first volume of the VM will automatically be resized
 to the specified value. disk_size is in GB

Specific domain settings can be set for each domain separately in multi-VM
environment. Example below shows a part of Vagrantfile, where specific options
are set for dbserver domain.

```ruby
Vagrant.configure("2") do |config|
  config.vm.define :dbserver do |dbserver|
    dbserver.vm.box = "ovirt"
    dbserver.vm.provider :ovirt3 do |vm|
      vm.memory = 2048
      vm.cpus = 2
      vm.template = "centos63-vagrant-base"
    end
  end

  # ...
```

## Multiple provider Vagrantfile with Provisioners Example

This example allows you to spin up a box under virtualbox using `$ vagrant up` as well as a VM under oVirt using a template with `$ vagrant up --provider=ovirt`
Note, the network information will differ between the two. Under virtualbox, it should come up with an IP of `192.168.56.100`. Under oVirt it should come up as `10.101.55.72` if successful.

```ruby
Vagrant.configure('2') do |config|
  config.vm.box = 'mybox'

   config.vm.network :private_network, 
    :ip => '192.168.56.100', :nictype => 'virtio', :netmask => '255.255.255.0' #normal network configuration
    :ovirt__ip => '10.101.55.72', :ovirt__network_name => 'ovirtmgmt', :ovirt__gateway => '10.101.55.1', # oVirt specific information, overwrites previous on oVirt provider
    
  config.vm.provider :virtualbox do |vb|
    vb.customize [
      # Key                Value
      'modifyvm',          :id, 
      '--cpuexecutioncap', '90',
      '--memory',          '1376',
      '--nictype2',        'virtio',
    ]
  end


  config.vm.provider :ovirt3 do |ovirt|
    ovirt.template = 'template'
    ovirt.cpus = 1
    ovirt.memory = 1024
    ovirt.console = 'vnc' #could also be 'spice'
    ovirt.url = 'https://youroVirtmaster:443'
    ovirt.username = 'username'
    ovirt.password = 'password'
    ovirt.datacenter = 'datacenter'
  end

  config.vm.provision 'shell' do |shell|
    shell.inline = 'uname -a > /var/log/something.log 2>&1'
  end

  config.vm.provision :puppet do |puppet|
    puppet.options = [
      "--environment development", 
      '--hiera_config=/etc/puppet/hiera/hiera.yaml', 
    ]
    puppet.manifests_path = './manifests'
    puppet.manifest_file = 'default.pp'
  end
```

### How Project Is Created

Vagrant goes through steps below when creating new project:

1.	Connect to oVirt via REST API on every REST query.
2.	Create new oVirt machine from template with additional network interfaces.
3.	Start oVirt machine.
4.	Check for IP address of VM using the REST API.
5.	Wait till SSH is available.
6.	Sync folders via `rsync` and run Vagrant provisioner on new domain if
	setup in Vagrantfile.

## Network Interfaces

Networking features in the form of `config.vm.network` support private networks
concept. No public network or port forwarding are supported in current version
of provider.

An examples of network interface definitions:

```ruby
  config.vm.define :test_vm1 do |test_vm1|
    test_vm1.vm.network :private_network,
      :ip      => "10.20.30.40",
      :netmask => "255.255.255.0",
      :ovirt__network_name => "ovirt_networkname"
  end
```

In example below, one additional network interface is created for VM test_vm1.
Interface is connected to `ovirt_networkname` network and configured to ip
address `10.20.30.40/24`. If you omit ip address, interface will be configured
dynamically via dhcp.

## Box Format

Every provider in Vagrant must introduce a custom box format. This provider
introduces oVirt boxes. You can view an example box in the
[example_box](https://github.com/myoung34/vagrant-ovirt3/tree/master/example_box)
directory. That directory also contains instructions on how to build a box.

The box is a tarball containing:

* `metadata.json` file describing box image (just a provider name).
* `Vagrantfile` that does default settings for the provider-specific configuration for this provider.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request

