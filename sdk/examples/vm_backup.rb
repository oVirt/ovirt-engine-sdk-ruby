#!/usr/bin/ruby

#
# Copyright (c) 2017 Red Hat, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'logger'
require 'ovirtsdk4'
require 'securerandom'
require 'time'

# This example shows how the virtual machine backup process works.

# The connection details:
API_URL = 'https://engine40.example.com/ovirt-engine/api'.freeze
API_USER = 'admin@internal'.freeze
API_PASSWORD = 'redhat123'.freeze

# The file containing the certificate of the CA used by the server. In an usual installation it will be in the file
# '/etc/pki/ovirt-engine/ca.pem'.
API_CA_FILE = 'ca.pem'.freeze

# The name of the application, to be used as the 'origin' of events sent to the audit log:
APPLICATION_NAME = 'mybackup'.freeze

# The name of the virtual machine that contains the data that we want to back-up:
DATA_VM_NAME = 'myvm'.freeze

# The name of the virtual machine where we will attach the disks in order to actually back-up them. This virtual
# machine will usually have some kind of back-up software installed.
AGENT_VM_NAME = 'myagent'.freeze

# The log:
log = Logger.new('example.log')

# Create the connection to the server:
connection = OvirtSDK4::Connection.new(
  url: API_URL,
  username: API_USER,
  password: API_PASSWORD,
  ca_file: API_CA_FILE,
  debug: true,
  log: log
)
log.info('Connected to the server.')

# Get the reference to the root of the services tree:
system_service = connection.system_service

# Get the reference to the service that we will use to send events to the audit log:
events_service = system_service.events_service()

# In order to send events we need to also send unique integer ids. These should usually come from an external
# database, but in this example we # will just generate them from the current time in seconds since Jan 1st 1970.
event_id = Time.now.to_i

# Get the reference to the service that manages the virtual machines:
vms_service = system_service.vms_service

# Find the virtual machine that we want to back up. Note that we need to use the 'all_content' parameter to retrieve
# the retrieve the OVF, as it isn't retrieved by default:
data_vm = vms_service.list(search: "name=#{DATA_VM_NAME}", all_content: true).first
log.info("Found data virtual machine '#{data_vm.name}', the id is '#{data_vm.id}'.")

# Find the virtual machine were we will attach the disks in order to do the backup:
agent_vm = vms_service.list(search: "name=#{AGENT_VM_NAME}").first
log.info("Found agent virtual machine '#{agent_vm.name}', the id is '#{agent_vm.id}'.")

# Find the services that manage the data and agent virtual machines:
data_vm_service = vms_service.vm_service(data_vm.id)
agent_vm_service = vms_service.vm_service(agent_vm.id)

# Create an unique description for the snapshot, so that it is easier for the administrator to identify this snapshot
# as a temporary one created just for backup purposes:
snap_description = "#{data_vm.name}-backup-#{SecureRandom.uuid}"

# Send an external event to indicate to the administrator that the backup of the virtual machine is starting. Note
# that the description of the event contains the name of the virtual machine and the name of the temporary snapshot,
# this way, if something fails, the administrator will know what snapshot was used and remove it manually.
events_service.add(
  OvirtSDK4::Event.new(
    vm: {
      id: data_vm.id
    },
    origin: APPLICATION_NAME,
    severity: OvirtSDK4::LogSeverity::NORMAL,
    custom_id: event_id,
    description: "Backup of virtual machine '#{data_vm.name}' using snapshot '#{snap_description}' is starting."
  )
)
event_id += 1

# Save the OVF to a file, so that we can use to restore the virtual machine later. The name of the file is the name
# of the virtual machine, followed by a dash and the identifier of the virtual machine, to make it unique:
ovf_data = data_vm.initialization.configuration.data
ovf_file = "#{data_vm.name}-#{data_vm.id}.ovf"
File.open(ovf_file, 'w') { |ovf_fd| ovf_fd.write(ovf_data.encode('utf-8')) }
log.info("Wrote OVF to file '#{File.absolute_path(ovf_file)}'.")

# Send the request to create the snapshot. Note that this will return before the snapshot is completely created, so
# we will later need to wait till the snapshot is completely created.
snaps_service = data_vm_service.snapshots_service
snap = snaps_service.add(
  OvirtSDK4::Snapshot.new(
    description: snap_description
  )
)
log.info("Sent request to create snapshot '#{snap.description}', the id is '#{snap.id}'.")

# Poll and wait till the status of the snapshot is 'ok', which means that it is completely created:
snap_service = snaps_service.snapshot_service(snap.id)
while snap.snapshot_status != OvirtSDK4::SnapshotStatus::OK
  log.info("Waiting till the snapshot is created, the satus is now '#{snap.snapshot_status}'.")
  sleep(1)
  snap = snap_service.get
end
log.info('The snapshot is now complete.')

# Retrieve the descriptions of the disks of the snapshot:
snap_disks_service = snap_service.disks_service
snap_disks = snap_disks_service.list

# Attach all the disks of the snapshot to the agent virtual machine, and save the resulting disk attachments in a
# list so that we can later detach them easily:
attachments_service = agent_vm_service.disk_attachments_service
attachments = []
snap_disks.each do |snap_disk|
  attachment = attachments_service.add(
    OvirtSDK4::DiskAttachment.new(
      disk: {
        id: snap_disk.id,
        snapshot: {
          id: snap.id
        }
      },
      active: true,
      bootable: false,
      interface: OvirtSDK4::DiskInterface::VIRTIO
    )
  )
  attachments << attachment
  log.info("Attached disk '#{attachment.disk.id}' to the agent virtual machine.")
end

# Now the disks are attached to the virtual agent virtual machine, we can then ask that virtual machine to perform
# the backup. Doing that requires a mechanism to talk to the backup software that runs inside the agent virtual
# machine. That is outside of the scope of the SDK. But if the guest agent is installed in the virtual machine
# then we can provide useful information, like the identifiers of the disks that have just been attached.
attachments.each do |attachment|
  if attachment.logical_name.nil?
    log.info("The logical name for disk '#{attachment.disk.id}' isn't available. Is the guest agent installed?")
  else
    log.info("Logical name for disk '#{attachment.disk.id}' is '#{attachment.logical_name}'.")
  end
end

# Insert here the code to contact the backup agent and do the actual backup ...
log.info('Doing the actual backup ...')

# Detach the disks from the agent virtual machine:
attachments.each do |attachment|
  attachment_service = attachments_service.attachment_service(attachment.id)
  attachment_service.remove
  log.info("Detached disk '#{attachment.disk.id}' to from the agent virtual machine.")
end

# Remove the snapshot:
snap_service.remove
log.info("Removed the snapshot '#{snap.description}'.")

# Send an external event to indicate to the administrator that the backup of the virtual machine is completed:
events_service.add(
  OvirtSDK4::Event.new(
    vm: {
      id: data_vm.id
    },
    origin: APPLICATION_NAME,
    severity: OvirtSDK4::LogSeverity::NORMAL,
    custom_id: event_id,
    description: "Backup of virtual machine '#{data_vm.name}' using snapshot '#{snap_description}' is completed."
  )
)

# Close the connection to the server:
connection.close
