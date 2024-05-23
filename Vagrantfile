# -*- mode: ruby -*-
# vi: set ft=ruby :

# kube_node and kube_control_plane hosts with ram and cpu properties
DNS_CLUSTER_HOSTS = [
  {hostname: "dns-master",     ram: 4096, cpu: 2},
  {hostname: "dns-replica-01", ram: 4096, cpu: 2},
  {hostname: "dns-replica-02", ram: 4096, cpu: 2}
]

# Keep empty. This lists for ansible provisioning hosts splitting by their names
master_hosts = []
replica_hosts = []
etcd_cluster_hosts = []

# Libvirt plugin references:
# https://www.rubydoc.info/gems/vagrant-libvirt/0.12.2 or https://github.com/vagrant-libvirt/vagrant-libvirt
#
# Timezone plugin references:
# https://github.com/tmatilai/vagrant-timezone

REQUIRED_PLUGINS = ["vagrant-libvirt", "vagrant-timezone"]
exit unless REQUIRED_PLUGINS.all? do |plugin|
  Vagrant.has_plugin?(plugin) || (
    puts "The #{plugin} plugin is required. Please install it with:"
    puts "$ vagrant plugin install #{plugin}"
    false
  )
end

# This is workaround for imported playbook, which don't see group_vars and host_vars
make_inventory_dir_script = <<-SCRIPT
/usr/bin/mkdir -p #{ENV['PWD']}/.vagrant/provisioners/ansible/inventory
SCRIPT

make_inventory_group_vars_links_script = <<-SCRIPT
/usr/bin/ln -sf #{ENV['PWD']}/provisioning/group_vars #{ENV['PWD']}/.vagrant/provisioners/ansible/inventory
SCRIPT

make_inventory_host_vars_links_script = <<-SCRIPT
/usr/bin/ln -sf #{ENV['PWD']}/provisioning/host_vars #{ENV['PWD']}/.vagrant/provisioners/ansible/inventory
SCRIPT

Vagrant.configure(2) do |config|
  # Set timezone like in host for each VM
  config.timezone.value = :host
  config.vm.synced_folder '.', '/vagrant', disabled: true
  DNS_CLUSTER_HOSTS.each do |node|
    config.vm.define node[:hostname] do |config|
      config.vm.hostname = node[:hostname]
      config.vm.box = "generic-x64/ubuntu2204"
      config.vm.provider :libvirt do |domain|
        domain.memory = node[:ram]
        domain.cpus = node[:cpu]
      end

      # Filling kube_node_hosts and control_plane_hosts lists for ansible inventory generator
      if node[:hostname].start_with?("dns-master")
        master_hosts << node[:hostname]
      elsif node[:hostname].start_with?("dns-replica")
        replica_hosts << node[:hostname]
      end

      # workaround for etcd host
      etcd_cluster_hosts << node[:hostname]

      # Add workaround for execute provision only on last host
      if node.equal?(DNS_CLUSTER_HOSTS.last)

        config.trigger.before [:up, :provision] do |ansible_galaxy_install|
          ansible_galaxy_install.info = "Execute ansible-galaxy install..."
          ansible_galaxy_install.run = {inline: "ansible-galaxy install -f -r ./requirements.yaml --roles-path ./provisioning"}
          ansible_galaxy_install.ignore = [:destroy, :halt]
        end

        config.trigger.before [:up, :provision] do |make_inventory_dir|
          make_inventory_dir.info = "Make  inventory links"
          make_inventory_dir.run = {inline: make_inventory_dir_script }
          make_inventory_dir.ignore = [:destroy, :halt]
        end

        config.trigger.before [:up, :provision] do |make_inventory_group_vars_links|
          make_inventory_group_vars_links.info = "Make  inventory links"
          make_inventory_group_vars_links.run = {inline: make_inventory_group_vars_links_script }
          make_inventory_group_vars_links.ignore = [:destroy, :halt]
        end

        config.trigger.before [:up, :provision] do |make_inventory_host_vars_links|
          make_inventory_host_vars_links.info = "Make  inventory links"
          make_inventory_host_vars_links.run = {inline: make_inventory_host_vars_links_script }
          make_inventory_host_vars_links.ignore = [:destroy, :halt]
        end

        # Execute ansible in provision phase. Workaround for automatically generate provisioning by Vagrant
        config.vm.provision :ansible do |ansible_playbook|
          ansible_playbook.verbose = "v"
          ansible_playbook.compatibility_mode = "2.0"
          ansible_playbook.playbook = "provisioning/playbook.yaml"
          ansible_playbook.host_key_checking = false
          ansible_playbook.groups = {
            "master" => master_hosts,
            "etcd_cluster" => etcd_cluster_hosts,
            "replica" => replica_hosts,
            "postgres_cluster:children" => ["master", "replica"]
          }
          ansible_playbook.limit = "all"
        end
      end # end provision on last node
    end # end config.vm
  end # end "each"
end
