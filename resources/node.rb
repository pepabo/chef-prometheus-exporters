#
# Cookbook Name:: prometheus_exporters
# Resource:: node
#
# Copyright 2017, Evil Martians
#
# All rights reserved - Do Not Redistribute
#

resource_name :node_exporter

property :web_listen_address, String, default: ':9100'
property :web_telemetry_path, String, default: '/metrics'
property :log_level, String, default: 'info'
property :log_format, String, default: 'logger:stdout'
property :collectors_enabled, Array
property :collector_textfile_directory, String
property :collector_netdev_ignored_devices, String
property :collector_diskstats_ignored_devices, String
property :collector_filesystem_ignored_fs_types, String
property :collector_filesystem_ignored_mount_points, String
property :custom_options, String

action :install do
  remote_file 'node_exporter' do
    path "#{Chef::Config[:file_cache_path]}/node_exporter.tar.gz"
    owner 'root'
    group 'root'
    mode '0644'
    source node['prometheus_exporters']['node']['url']
    checksum node['prometheus_exporters']['node']['checksum']
    notifies :run, 'execute[untar node_exporter]', :immediately
  end

  execute 'untar node_exporter' do
    command "tar -xzf #{Chef::Config[:file_cache_path]}/node_exporter.tar.gz -C /opt"
    action :nothing
  end

  link '/usr/local/sbin/node_exporter' do
    to "/opt/node_exporter-#{node['prometheus_exporters']['node']['version']}.linux-amd64/node_exporter"
  end

  options = "-web.listen-address #{new_resource.web_listen_address}"
  options += " -web.telemetry-path #{new_resource.web_telemetry_path}"
  options += " -log.level #{new_resource.log_level}"
  options += " -log.format #{new_resource.log_format}"
  options += " -collectors.enabled #{new_resource.collectors_enabled.join(',')}" if new_resource.collectors_enabled
  options += " -collector.textfile.directory #{new_resource.collector_textfile_directory}" if new_resource.collector_textfile_directory
  options += " -collector.netdev.ignored-devices '#{new_resource.collector_netdev_ignored_devices}'" if new_resource.collector_netdev_ignored_devices
  options += " -collector.diskstats.ignored-devices '#{new_resource.collector_diskstats_ignored_devices}'" if new_resource.collector_diskstats_ignored_devices
  options += " -collector.filesystem.ignored-fs-types '#{new_resource.collector_filesystem_ignored_fs_types}'" if new_resource.collector_filesystem_ignored_fs_types
  options += " -collector.filesystem.ignored-mount-points '#{new_resource.collector_filesystem_ignored_mount_points}'" if new_resource.collector_filesystem_ignored_mount_points
  options += " #{new_resource.custom_options}" if new_resource.custom_options

  service 'node_exporter' do
    action :nothing
  end

  systemd_service 'node_exporter' do
    unit_description 'Systemd unit for Prometheus Node Exporter'
    after %w(network.target remote-fs.target apiserver.service)
    install do
      wanted_by 'multi-user.target'
    end
    service do
      type 'simple'
      exec_start "/usr/local/sbin/node_exporter #{options}"
      working_directory '/'
      restart 'on-failure'
      restart_sec '30s'
    end

    only_if { (platform?("ubuntu") && node['platform_version'].to_i >= 16) || (platform?("centos") && node['platform_version'].to_i >= 7)}

    verify false
    notifies :restart, 'service[node_exporter]'
  end

  template '/etc/init/node_exporter.conf' do
    source 'upstart.conf.erb'
    owner 'root'
    group 'root'
    mode '0644'
    variables(
      cmd: "/usr/local/sbin/node_exporter #{options}",
      service_description: 'Prometheus Node Exporter'
    )

    only_if { node['platform_version'].to_i < 16 }

    notifies :restart, 'service[node_exporter]'
  end if platform?("ubuntu")

  directory 'collector_textfile_directory' do
    path new_resource.collector_textfile_directory
    owner 'root'
    group 'root'
    mode '0755'
    action :create
    recursive true
    only_if { new_resource.collector_textfile_directory && new_resource.collector_textfile_directory != '' }
  end
end

action :enable do
  action_install
  service 'node_exporter' do
    action :enable
  end
end

action :start do
  service 'node_exporter' do
    action :start
  end
end

action :disable do
  service 'node_exporter' do
    action :disable
  end
end

action :stop do
  service 'node_exporter' do
    action :stop
  end
end
