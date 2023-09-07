instance-id: "${var.vm_os.name}-${local.vm_instance_id}"
local-hostname: "${var.hostname}"
hostname: "${var.hostname}"
network:
  version: 2
  renderer: "networkd"
  ethernets:
    allen:
      match:
        name: "en*"
      dhcp4: true
    allveth:
      match:
        name: "veth*"
      dhcp4: true
