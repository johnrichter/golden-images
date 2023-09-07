#cloud-config
#
# Autoinstall
#
# Since version 20.04, the server installer supports automated installation mode (autoinstallation
# for short). You might also know this feature as unattended, hands-off, or preseeded installation.
#
# Autoinstallation lets you answer all those configuration questions ahead of time with an
# autoinstall config, and lets the installation process run without any interaction.
#
# The `user-data` is a regular Cloud Init config
#
# https://ubuntu.com/server/docs/install/autoinstall-reference
# https://cloudinit.readthedocs.io/
#
autoinstall:
  # A future-proofing config file version field. Currently this must be “1”.
  version: 1

  # The locale to configure for the installed system
  locale: "en_US.UTF-8"

  # Controls whether the installer updates to a new version available in the given channel before
  # continuing
  refresh-installer:
    # Whether to update or not
    update: true
    # The channel to check for updates.
    channel: "stable/ubuntu-${var.vm_os.version}"

  # The layout of any attached keyboard. The mapping’s keys correspond to settings in
  # /etc/default/keyboard
  keyboard:
    # Corresponds to the XKBLAYOUT setting
    layout: "us"

  # Driver install sources
  source:
    # What server version to install
    id: "ubuntu-server-minimal"

    # Whether the installer should search for available third-party drivers. When set to false,
    # it disables the drivers screen and section.
    search_drivers: false

  # Configuration of disk storage. Default is to use “lvm” layout in a single disk system, no
  # default in a multiple disk system
  storage:
    # Simple way of expressing common configurations. Can be “lvm” or “direct.” Default is "lvm"
    layout:
      name: lvm

      # Controls volume expansion and sizing behavior. The lvm layout will, by default, attempt to
      # leave room for snapshots and further expansion.
      #   * scaled -> adjust space allocated to the root LV based on space available to the VG
      #   * all -> allocate all remaining VG space to the root LV
      # The scaling system is currently as follows
      #   * Less than 10 GiB: use all remaining space for root filesystem
      #   * Between 10-20 GiB: 10 GiB root filesystem
      #   * Between 20-200 GiB: use half of remaining space for root filesystem
      #   * Greater than 200 GiB: 100 GiB root filesystem
      sizing-policy: "scaled"

    # The grub and swap curtin config.
    # https://curtin.readthedocs.io/en/latest/topics/config.html#grub
    grub:
      # Controls whether grub-install will update the Linux Default target value during installation
      replace_linux_default: true

      # Certain platforms, like uefi and prep systems utilize NVRAM to hold boot configuration
      # settings which control the order in which devices are booted. Curtin by default will enable
      # NVRAM updates to boot configuration settings. Users may disable NVRAM updates by setting the
      # update_nvram value to False
      update_nvram: true

      # Curtin is typically used with MAAS where the systems are configured to boot from the network
      # leaving MAAS in control. On UEFI systems, after installing a bootloader the systems
      # BootOrder may be updated to boot from the new entry. This breaks MAAS control over the
      # system as all subsequent reboots of the node will no longer boot over the network.
      # Therefore, if reorder_uefi is True curtin will modify the UEFI BootOrder settings to place
      # the currently booted entry (BootCurrent) to the first option after installing the new target
      # OS into the UEFI boot menu. The result is that the system will boot from the same device
      # that it booted to run curtin; for MAAS this will be a network device.
      #
      # On some UEFI systems the BootCurrent entry may not be present. This can cause a system to
      # not boot to the same device that it was previously booting. If BootCurrent is not present,
      # curtin will update the BootOrder such that all Network related entries are placed before
      # the newly installed boot entry and all other entries are placed at the end. This enables
      # the system to network boot first and on failure will boot the most recently installed entry
      #
      # This setting is ignored if update_nvram is False.
      #
      # Required for ubuntu 20.04 since it can't unmount the cdrom on reboot
      # https://bugs.launchpad.net/subiquity/+bug/1901397
      # https://github.com/hashicorp/packer-plugin-qemu/issues/66#issuecomment-1466049817
      reorder_uefi: false

      # The fallback reodering mechanism is only active if BootCurrent is not present in the
      # efibootmgr output. The fallback reordering method may be enabled even if BootCurrent is
      # present if reorder_uefi_force_fallback is True. This setting is ignored if update_nvram or
      # reorder_uefi are False.
      reorder_uefi_force_fallback: false

      # When curtin updates UEFI NVRAM it will remove duplicate entries that are present in the UEFI
      # menu. If you do not wish for curtin to remove duplicate entries setting
      # remove_duplicate_entries to False. This setting is ignored if update_nvram is False.
      remove_duplicate_entries: true

  # Configure SSH for the installed system
  ssh:
    # Whether to install OpenSSH server in the target system.
    install-server: true

  # Configure whether common restricted packages (including codecs) from [multiverse] should be
  # installed
  codecs:
    # Whether to install the ubuntu-restricted-addons package
    install: false

  # Driver installation
  drivers:
    # Whether to install the available third-party drivers
    install: false

  # The type of updates that will be downloaded and installed after the system install. Supported
  # values are
  #   * security -> download and install updates from the -security pocket
  #   * all -> also download and install updates from the -updates pocket
  updates: "all"

  # Request the system to power off or reboot automatically after the installation has finished.
  # Supported values are
  #   * reboot
  #   * poweroff
  shutdown: "reboot"

  # A list of shell commands to invoke as soon as the installer starts, in particular before probing
  # for block and network devices
  early-commands:
    # otherwise packer tries to connect and exceed max attempts:
    - "systemctl stop ssh.service"
    # - "systemctl stop ssh.socket"

  # Shell commands to run after the install has completed successfully and any updates and packages
  # installed, just before the system reboots. They are run in the installer environment with the
  # installed system mounted at /target. You can run curtin in-target -- $shell_command (with the
  # version of subiquity released with 20.04 GA you need to specify this as
  # curtin in-target --target=/target -- $shell_command) to run in the target system (similar to
  # how plain in-target can be used in d-i preseed/late_command)
  late-commands:
    # Required for ubuntu 20.04 since it can't unmount the cdrom on reboot
    # https://bugs.launchpad.net/subiquity/+bug/1901397
    # https://github.com/hashicorp/packer-plugin-qemu/issues/66#issuecomment-1466049817
    - |
      echo 'GRUB_TIMEOUT=10' | tee -a /target/etc/default/grub
      echo 'GRUB_TIMEOUT_STYLE="menu"' | tee -a /target/etc/default/grub
      echo 'GRUB_CMDLINE_LINUX_DEFAULT="acpi=force acpi_rev_override=5"' | tee -a /target/etc/default/grub
      curtin in-target --target=/target -- update-grub
    - |
      if [ -d /sys/firmware/efi ]; then
        /target/bin/efibootmgr -o $(/target/bin/efibootmgr | /target/bin/perl -n -e '/Boot(.+)\* ubuntu/ && print $1')
      fi

  # Shell commands to run after the install has failed. They are run in the installer environment,
  # and the target system (or as much of it as the installer managed to configure) will be mounted
  # at /target. Logs will be available at /var/log/installer in the live session
  # error-commands:
  # This causes an error for some reason
  # - "curtin in-target --target=/target -- cloud-init schema --system"

  user-data:
    # Alpine Linux: Configuration of the /etc/apk/repositories file
    apk_repos:
      alpine_repo:
        # Whether to add the Community repo to the repositories file
        community_enabled: true
        version: "latest-stable"

    # Configure apt for the user
    apt:
      # Entries in the sources list can be disabled (commented out). If the string $RELEASE is
      # present in a suite in the disable_suites list, it will be replaced with the release name
      #   * updates => $RELEASE-updates
      #   * backports => $RELEASE-backports
      #   * security => $RELEASE-security
      #   * proposed => $RELEASE-proposed
      #   * release => $RELEASE
      disable_suites:
        - "backports"
        - "proposed"

    # This module configures the final message that cloud-init writes. The message is specified a
    # a jinja template with the following variables set
    #   * version: cloud-init version
    #   * timestamp: time at cloud-init finish
    #   * datasource: cloud-init data source
    #   * uptime: system uptime
    final_message: |
      cloud-init has finished
      version: $version
      timestamp: $timestamp
      datasource: $datasource
      uptime: $uptime

    # Growpart resizes partitions to fill the available disk space
    growpart:
      # The utility to use for resizing. Possible options
      #   * auto - Use any available utility
      #   * growpart - Use growpart utility
      #   * gpart - Use BSD gpart utility
      #   * off - Take no action
      mode: "auto"

      # he devices to resize. Each entry can either be the path to the device’s mountpoint in the
      # filesystem or a path to the block device in ‘/dev’
      devices:
        - "/"

      # If true, ignore the presence of /etc/growroot-disabled. If false and the file exists, then
      # don’t resize
      ignore_growroot_disabled: false

    # Resize a filesystem to use all avaliable space on partition. Will ensure that if the root
    # partition has been resized the root filesystem will be resized along with it. False to disable
    resize_rootfs: true

    # Enable and configure ntp
    ntp:
      enabled: ${jsonencode(var.ntp_enabled)}

    # A list of packages to install during boot. Each entry in the list can be either a package name
    # or a list with two entries, the first being the package name and the second being the specific
    # package version to install
    packages: ${jsonencode(var.packages.essentials)}

    # Set true to update packages. Happens before upgrade or install
    package_update: ${jsonencode(var.packages_update)}

    # Set true to upgrade packages. Happens before install
    package_upgrade: ${jsonencode(var.packages_upgrade)}

    # Set true to reboot the system if required by presence of /var/run/reboot-required
    package_reboot_if_required: ${jsonencode(var.packages_reboot_if_required)}

    # Provide random seed data
    random_seed:
      # File to write random data to
      file: "/dev/urandom"

      # This data will be written to file before data from the datasource. When using a multiline
      # value or specifying binary data, be sure to follow yaml syntax and use the | and !binary
      # yaml format specifiers when appropriate
      data: >-
        ${sha512(uuidv4())}
        ${sha512(uuidv4())}
        ${sha512(uuidv4())}
        ${sha512(uuidv4())}
        ${sha512(uuidv4())}
        ${sha512(uuidv4())}
        ${sha512(uuidv4())}
        ${sha512(uuidv4())}

      # Used to decode data provided. Allowed values are raw, base64, b64, gzip, or gz
      encoding: "raw"

    # The hostname to set
    hostname: "${var.hostname}"

    # The fully qualified domain name to set
    fqdn: "${var.hostname_fqdn}"

    # If true, the fqdn will be used if it is set. If false, the hostname will be used. If unset,
    # the result is distro-dependent
    prefer_fqdn_over_hostname: true

    # Sets whether or not to accept password authentication
    ssh_pwauth: ${jsonencode(var.ssh_enable_password_authentication)}

    # Remove host SSH keys. This prevents re-use of a private host key from an image with default
    # host SSH keys
    ssh_deletekeys: ${jsonencode(var.ssh_delete_host_keys)}

    # If true, SSH fingerprints will not be written
    no_ssh_fingerprints: false

    # The hash type to use when generating SSH fingerprints
    authkey_hash: "sha512"

    # Disable root login
    disable_root: true

    # Disable root login options
    disable_root_opts: >-
      no-port-forwarding,no-agent-forwarding,no-X11-forwarding,command="echo 'Please login as the user \"${var.user_name}\" rather than the user \"$DISABLE_USER\".';echo;sleep 10;exit 142"

    # Create users and passwords
    chpasswd:
      # Whether to expire all user passwords such that a password will need to be reset on the
      # user’s next login
      expire: false

    # Groups to add to the system. Groups are added before users, so any users in a group list
    # must already exist on the system
    # groups: ${jsonencode(var.system_groups)}

    # Users to add to the system. the reserved string default which represents the primary admin
    # user used to access the system. The default user varies per distribution and is generally
    # configured in /etc/cloud/cloud.cfg by the default_user key.
    #
    # Specifying a hash of a user’s password with passwd is a security risk if the cloud-config can
    # be intercepted. SSH authentication is preferred.
    #
    # If specifying a sudo rule for a user, ensure that the syntax for the rule is valid, as it is
    # not checked by cloud-init.
    #
    # Most of these configuration options will not be honored if the user already exists. The
    # following options are the exceptions; they are applied to already-existing users:
    # plain_text_passwd, hashed_passwd, lock_passwd, sudo, ssh_authorized_keys, ssh_redirect_user.
    users:
      # The user’s ID. Default is next available value
      # - # uid:
      - name: "${var.user_name}"

        # Hash of user password to be applied. This will be applied even if the user is
        # pre-existing. To generate this hash, Run
        #  * `python3 -c 'import secrets; print(secrets.token_hex(8))'`
        #  * `openssl passwd -6 -salt 'rounds=4096$<output from above>'
        # hashed_passwd: "${var.user_password_crypted}"
        passwd: "${var.user_password_crypted}"

        # Disable password login
        lock_passwd: false

        # Create user as system user with no home directory
        system: false

        # Optional comment about the user, usually a comma-separated string of real name and
        # contact information
        gecos: "${var.user_realname}"

        # List of groups to add the user to
        groups: ${jsonencode(var.user_groups)}

        # Create specified user groups
        create_groups: true

        # Primary group for user
        primary_group: "${var.user_name}"

        # Do not create a group named after user
        no_user_group: false

        # Do not create home directory
        no_create_home: false

        # Home dir for user
        homedir: "/home/${var.user_name}"

        # Path to the user’s login shell. The default is to set no shell, which results in a
        # system-specific default being used
        shell: "/bin/bash"

        # List of SSH keys to add to user’s authkeys file
        ssh_authorized_keys: ${jsonencode(var.user_ssh_authorized_key_blobs)}

      - name: "${var.user_name}"

        # Sudo rule to use or false. Absence of a sudo value or null will result in no sudo
        # rules added. Seem to only be a valid field for existing users
        # sudo: "${var.user_name} ${var.user_sudo_config}"
        sudo: "${var.user_sudo_config}"
