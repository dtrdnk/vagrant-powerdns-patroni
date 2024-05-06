# -*- mode: ruby -*-
# vi: set ft=ruby :

# kube_node and kube_control_plane hosts with ram and cpu properties
DNS_CLUSTER_HOSTS = [
  {hostname: "dns-master",     ram: 4096, cpu: 2, ip: "10.20.30.41"},
  {hostname: "dns-replica-01", ram: 4096, cpu: 2, ip: "10.20.30.42"},
  {hostname: "dns-replica-02", ram: 4096, cpu: 2, ip: "10.20.30.43"}
]

# Keep empty. This lists for ansible provisioning hosts splitting by their names
host_vars = {}
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

Vagrant.configure(2) do |config|
  # Set timezone like in host for each VM
  config.timezone.value = :host
  config.vm.synced_folder '.', '/vagrant', disabled: true
  DNS_CLUSTER_HOSTS.each do |node|
    config.vm.define node[:hostname] do |config|
      config.vm.hostname = node[:hostname]
      config.vm.box = "almalinux/9"
      config.vm.network :private_network, :ip => node[:ip]
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

      # Filling host_vars hashmap for ansible. This hashmap necessary for customize VM interface for running PG service
      host_vars[node[:hostname]] = {
        "ip": node[:ip]
      }

      # Add workaround for execute provision only on last host
      if node.equal?(DNS_CLUSTER_HOSTS.last)

        config.trigger.before [:up, :provision] do |ansible_galaxy_install|
          ansible_galaxy_install.info = "Execute ansible-galaxy install..."
          ansible_galaxy_install.run = {inline: "ansible-galaxy install -f -r ./requirements.yaml --roles-path ./provisioning"}
          ansible_galaxy_install.ignore = [:destroy, :halt]
        end

        # Execute ansible in provision phase. Workaround for automatically generate provisioning by Vagrant
        config.vm.provision :ansible do |ansible_playbook|
          ansible_playbook.verbose = "v"
          ansible_playbook.compatibility_mode = "2.0"
          ansible_playbook.playbook = "provisioning/playbook.yaml"
          ansible_playbook.host_key_checking = false
          ansible_playbook.host_vars = host_vars
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
