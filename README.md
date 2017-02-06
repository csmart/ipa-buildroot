[buildroot-list-defconfigs]: https://github.com/csmart/ipa-buildroot/raw/master/doc/img/buildroot-list-defconfigs.png "Listing available Buildroot configs, showing IPA"
[buildroot-menuconfig]: https://github.com/csmart/ipa-buildroot/raw/master/doc/img/buildroot-menuconfig.png "The welcome window of Buildroot menuconfig"
[buildroot-menuconfig-external]: https://github.com/csmart/ipa-buildroot/raw/master/doc/img/buildroot-menuconfig-external.png "Configuration for IPA Buildroot configs"
[buildroot-menuconfig-external-releases]: https://github.com/csmart/ipa-buildroot/raw/master/doc/img/buildroot-menuconfig-external-releases.png "Setting the Git release for building IPA"
[buildroot-menuconfig-password]: https://github.com/csmart/ipa-buildroot/raw/master/doc/img/buildroot-menuconfig-password.png "A salted, sha256 hashed password for root"
[buildroot-menuconfig-readme]: https://github.com/csmart/ipa-buildroot/raw/master/doc/img/buildroot-menuconfig-readme.png "This shows how to navigate and use Buildroot menuconfig"
[buildroot-menuconfig-search]: https://github.com/csmart/ipa-buildroot/raw/master/doc/img/buildroot-menuconfig-search.png "Search and navigate to options"

# OpenStack Ironic Python Agent

This is an experiment using [Buildroot](https://buildroot.org) to create a
small, custom Ironic Python Agent image for OpenStack.

Feedback is most welcome!

* [How the build works](#how-the-build-works)
   * [Directory structure](#directory-structure)
* [Getting Buildroot](#getting-buildroot)
   * [Git clone](#git-clone)
* [Build dependencies](#build-dependencies)
   * [Fedora](#fedora)
   * [Ubuntu](#ubuntu)
* [Building the image](#building-the-image)
   * [Step 1 - Exporting variables](#step-1---exporting-variables)
   * [Step 2 - Preparing the output directory](#step-2---preparing-the-output-directory)
   * [Step 3 - Loading the Buildroot configuration](#step-3---loading-the-buildroot-configuration)
   * [Step 4 - Making changes to Buildroot configuration](#step-4---making-changes-to-buildroot-configuration)
   * [Step 5 - Building the image](#step-5---building-the-image)
* [Testing the image](#testing-the-image)
* [Making changes](#making-changes)
   * [Making changes to Buildroot](#making-changes-to-buildroot)
      * [Setting the IPA version](#setting-the-ipa-version)
      * [Adding users](#adding-users)
      * [Setting root password](#setting-root-password)
         * [Using a hashed password](#using-a-hashed-password)
      * [Using filesystem overlays](#using-filesystem-overlays)
      * [Adding SSH keys](#adding-ssh-keys)
   * [Making changes to Busybox](#making-changes-to-busybox)
   * [Making changes to the Linux kernel](#making-changes-to-the-linux-kernel)
* [Rebuilding](#rebuilding)
* [Saving changes](#saving-changes)

# How the build works

Buildroot is a popular open source tool for building embedded Linux
systems. It supports many popular (and generic) platforms, however it
can also be extended to support third party platforms.

We will track a stable version of Buildroot, and create an extra set
of configs to support our own platform.

Then we will simply tell Buildroot where these extra configs are so
that we can build our own Ironic Python Agent images.

The build is done as a regular user, *not* as root.

## Directory structure

Inside this main _ipa-buildroot_ repository will be directories which
are used to build your images.

| Directory | Description |
| --- | --- |
| buildroot | Upstream Buildroot source code Git submodule |
| buildroot-ipa | Ironic Python Agent image configurations for Buildroot |
| ccache | Directory for storing ccache files to speed up subsequent builds |
| dl | Cache directory for downloaded source code tarballs |
| doc | Files for documentation, including screenshots |
| output | Output directory for build |
| overlay | For users to include own files into the target image |
| scripts | For users to run own scripts when building the image |

We will export variables later to help use these.

# Getting Buildroot

This Git repository (_ipa-buildroot_) contains our configuration files
for building the IPA image (in the _buildroot-ipa_ subdirectory).

This repo also uses a Git submodule to pull in a stable release of the
upstream Buildroot Git repository for us to build against (in the
_buildroot_ subdirectory).

We shouldn't modify anything in the upstream Buildroot repository, but
rather put any changes in our own configuration space under
_buildroot-ipa_.

## Git clone

Clone this ipa-buildroot repo into your home directory, adding the
_--recursive_ option to also pull in the upstream Buildroot Git repo.

	cd ~
	git clone --recursive https://github.com/csmart/ipa-buildroot

Alternatively, if you have already cloned this ipa-buildroot repository
on its own, you can pull in the upstream Buildroot Git submodule manually.

	cd ~/ipa-buildroot/
	git submodule init
	git submodule update

Now you should have both of the Git repos required to build an image!

# Build dependencies

For additional details on build dependencies, see the
[relevant Buildroot documentation](https://buildroot.org/downloads/manual/manual.html#requirement).

## Fedora

Something like this should be about right.

	sudo dnf install bash bc binutils bison bzip2 cmake cpio \
	flex gcc gcc-c++ glibc-devel glibc-devel.i686 glibc-headers.i686 \
	gzip make ncurses-devel patch perl python redhat-lsb.i686 rsync \
	sed tar texinfo unzip wget which

Install tools for downloading source.

	sudo dnf install bzr cvs git mercurial rsync subversion

Install deps for busybox menuconfig.

	sudo dnf install 'perl(ExtUtils::MakeMaker)' 'perl(Thread::Queue)'

## Ubuntu

Something like this should be about right.

	sudo apt-get install bc build-essential libncurses5-dev libc6:i386 texinfo unzip

Install tools for downloading source.

	sudo apt-get install bzr cvs git mercurial rsync subversion

# Building the image

Buildroot makes use of environment variables and it can make our life
easier, too.

In the next steps we're going to export the following variables.

| Variable | Description | Used by |
| --- | --- | --- |
| BR2_IPA_REPO | Where this _ipa-buildroot_ Git repo was cloned, e.g. ~/ipa-buildroot | Shell |
| BR2_UPSTREAM | Where upstream Buildroot Git submodule was cloned, e.g. ~/ipa-buildroot/buildroot | Shell |
| BR2_EXTERNAL | Ironic Python Agent Buildroot configs, e.g. ~/ipa-buildroot/buildroot-ipa | Buildroot |
| BR2_OUTPUT_DIR | Where Buildroot conducts builds and saves built images, e.g. ~/ipa-buildroot/output | Shell |

## Step 1 - Exporting variables

First, let's export the location of this cloned ipa-buildroot Git repo, as
other variables will be relative to it.

_Substitute this directory as appropriate, based on where you cloned this repo._

	export BR2_IPA_REPO="${HOME}/ipa-buildroot"

Set the location of the upstream Buildroot code.

	export BR2_UPSTREAM="${BR2_IPA_REPO}/buildroot"

Let's export the BR2_EXTERNAL variable to tell Buildroot where the IPA
specific configs are inside the cloned ipa-buildroot Git repository, so
that it can find our IPA specific customisations. Without this, Buildroot
will not include our IPA configs and won't be able to build our image.

	export BR2_EXTERNAL="${BR2_IPA_REPO}/buildroot-ipa"

## Step 2 - Preparing the output directory

We will utilise Buildroot's out-of-tree support and build in the existing
 _output_ dir inside the top level of our _ipa-buildroot_ Git repository.

Note that the _output_ directory will be ignored by Git.

	export BR2_OUTPUT_DIR="${BR2_IPA_REPO}/output"

Alternatively, specify a _unique_ output dir if you need to perform concurrent
builds.

	export BR2_OUTPUT_DIR="$(mktemp -d -p ${BR2_IPA_REPO}/output \
	-t "$(date +%s)-XXXXXX")"

Now you should be able to list all of the available Buildroot configs from inside
the output directory.

	cd "${BR2_OUTPUT_DIR}"
	make -C "${BR2_UPSTREAM}" list-defconfigs

If this worked, you should see the IPA build listed under "External configs."

![alt text][buildroot-list-defconfigs]

## Step 3 - Loading the Buildroot configuration

Now you can load the default IPA config that you saw above. Note that we specify
the output directory (O=) and the change directory (-C) options to make use if
out-of-tree builds.

	cd "${BR2_OUTPUT_DIR}"
	make O="${BR2_OUTPUT_DIR}" -C "${BR2_UPSTREAM}" openstack_ipa_defconfig

**Note:** From now on you do not need to specify the output directory (O=) and
change to source directory (-C) options. After the first time, Buildroot will write a
configuration file in the output directory and remember automatically in the future.

## Step 4 - Making changes to Buildroot configuration

**Note:** This step is entirely optional, however you may wish to perform the following:
* [Setting root password](#setting-root-password)
* [Adding SSH keys](#adding-ssh-keys)

Now that you have loaded the configuration file, you have the opportunity to
make any changes you might need.

There are three main components you may want to configure.

* Buildroot itself
  * System details
    * Enable root login
    * Set root password
  * Compiler
  * Target packages
  * Image formats
  * External options
    * Version of IPA
* Busybox
  * Packages to include
* Linux kernel
  * Features
  * Hardware support

See the [Making changes](#making-changes) section below for details and examples.

## Step 5 - Building the image

Finally, make the image!

**Note:** You should **not** use -j option with make, it is set in the config
and determined automatically. Specifying -j here may cause Buildroot components
to be built out of order, causing a failure.

	make

A successful build should create both a *_bzImage_* Linux kernel image and the
IPA *_rootfs.cpio.xz_* initramfs in the ${BR2_OUTPUT_DIR}/images directory.

# Testing the image

You can test the kernel and initramfs images in QEMU.

	qemu-system-x86_64 \
	-enable-kvm \
	-cpu host \
	-m 1G \
	-kernel images/bzImage \
	-append earlyprintk \
	-initrd images/rootfs.cpio.xz \
	-netdev user,id=net0 \
	-device e1000,netdev=net0

You should see a login prompt, however note that **root login is disabled by
default**. See [Setting root password](#setting-root-password) and/or
[Adding SSH keys](#adding-ssh-keys) below on how to enable these if you require
them.

The Python packages for IPA should have been installed and the daemon
should be running on port 9999.

Note that you may want to use different QEMU networking settings than _user_
above if you want to access IPA on your network. If you have virt-manager, you
can easily boot up the kernel and initramfs using its graphical interface.

# Making changes

This assumes you have already loaded the openstack_ipa_defconfig as per
the [Building the image](#building-the-image) section above and are ready to
modify it (you do not need to have built anything yet).

Changes can be made directly via the various .config files, but it is better
to use the graphical menu tools to make changes which will write to the
.config files.

Any changes that you make will be in the output directory, not in the main
Git repositories. To save your changes, see the _Saving changes_ section
below.

Configuration files are in the following locations:

| Component | Location |
| --- | --- |
| Buildroot | ${BR2_OUTPUT_DIR}/.config|
| Busybox | ${BR2_OUTPUT_DIR}/build/busybox-[version]/.config|
| Linux | ${BR2_OUTPUT_DIR}/build/linux-[version]/.config|

## Making changes to Buildroot

The main Buildroot configuration specifies many core components of the
target system, such as architecture, toolchain and build options, system
options and settings, kernel and config, packages to build, images to
create, bootloader support and more.

It is also where we will make the most common changes, such as:

* Enabling and setting a password for the root account
* Add/override any files in the target image, like SSH keys
* Changing download and cache build directory locations

To make changes, you can modify the options directly in the .config file
and then run _make oldconfig_ or you can use the menu (recommended).

	make menuconfig

You should be greeted with a configuration menu.

![alt text][buildroot-menuconfig]

Navigate by pressing the arrow keys and select using <_Enter_> or <_Space bar_>.

**Note:** You can get help for any option by navigating across to < Help > option
and hitting <_Enter_>.

The < Help > on the main screen presents the README which explains how the options
work.

![alt text][buildroot-menuconfig-readme]

Hitting the forward slash (/) key will let you search for any option in
Buildroot and go directly to it by pressing the corresponding number.

In the example below, we searched for _python_ and pressing _8_ would take us
straight to the Python target package.

![alt text][buildroot-menuconfig-search]

### Setting the IPA version

The Ironic Python Agent and dependencies are created by the post-build.sh script.

It uses pip to automatically create wheels based on the provided requirements.txt
from the upstream OpenStack Ironic Python Agent project as well as the
upper-constraints.txt from the OpenStack Requirements project.

There are two config options in Buildroot to set the Git version of these repos
so that you can build for multiple OpenStack releases.

| Config option | Purpose |
| --- | --- |
| OPENSTACK_IPA_GIT_URL | Setting the Git URL for Ironic Python Agent (defaults to upstream) |
| OPENSTACK_IPA_RELEASE | Setting the Git commit/tag/branch from Ironic Python Agent repo for fetching requirements.txt (defaults to master) |
| OPENSTACK_REQUIREMENTS_GIT_URL | Setting the Git URL for OpenStack Requirements repo (defaults to upstream) |
| OPENSTACK_REQUIREMENTS_RELEASE | Setting the Git commit/tag/branch from Requirements repo for fetching upper-constraints.txt (defaults to master) |

If you want to build from the master branches on upstream repositories, then you
do not have to change anything.

If you want to build another branch and/or from another repository, then change
accordingly. Note that local paths are supported, e.g. /home/csmart/ironic-python-agent

If you want to fetch HEAD (in case of local repository) or the default remote branch,
then don't specify anything for the Git release value.

To set these to a specific Git repo, tag or branch, under menuconfig browse to _External
options_ (at the very bottom).

![alt text][buildroot-menuconfig-external]

In the sub menu, you should see the options mentioned above. Simply enter the
details you wish to use.

![alt text][buildroot-menuconfig-external-releases]

Save and exit menuconfig. The next time _make_ is run, Buildroot will re-clone from the
specified Git repositories and build the IPA version for the target using the specified
Git commit/tag/branch.

### Adding users

Only the root user is configured, although login is disabled by default and there is no
password.

If you need to add another user, Buildroot supports this via a file which contains
a list of users, specified at BR2_ROOTFS_USERS_TABLES option.

See their online documentation on [adding custom user accounts](https://buildroot.org/downloads/manual/manual.html#customize-users)
if you need to make use of this.

### Setting root password

The default configuration **does not allow root login** and there is **no
password configured**.

To enable the root account and set a password, navigate to the
_System configuration_ menu and hit <_Enter_>.

	System configuration  --->

Navigate down to the login option and enable it with <_Space bar_>.

	[*] Enable root login with password

This will enable a sub-option for specifying the password.

	() Root password

Hitting <_Enter_> on this option will open a free form text field for
you to enter the password.

#### Using a hashed password

The password will be **saved in plain text** inside the .config file,
so it is probably best to use a hash of a password.

Specifying sha256 hashed passwords must be prefixed with _$5$_ like so:
  * $5$salt$Gcm6FsVtF/Qa77ZKD.iwsJlCVPY0XSMgLJL0Hnww/c1

However, all instances of _$_ in the hashed password __must be doubled__, so it becomes:
  * $$5$$salt$$Gcm6FsVtF/Qa77ZKD.iwsJlCVPY0XSMgLJL0Hnww/c1

You can generate a fully compliant password like follows (note that you
should replace _salt_ with some other string and _password_ with the
password you want to use).

	python -c 'import crypt; print crypt.crypt("password", "$5$random_salt")' \
	|sed 's|\$|\$\$|g'

Then set this in the free text password field.

![alt text][buildroot-menuconfig-password]

### Using filesystem overlays

You can add or replace any file on the target system using an overlay. These
files should still be owned by your user, there is no need to change ownership
to root.

The IPA board already has an overlay to copy in important files such as
systemd init scripts to start IPA. This is located at:

* ${BR2_EXTERNAL}/board/openstack/ipa/rootfs-overlay/

A second overlay is preconfigured (which is not tracked by Git) for users to
add files to. It is located in the _overlay_ directory in the top level
ipa-buildroot Git repository at:

* ${BR2_IPA_REPO}/overlay/

The configuration option which specifies both of these locations is
__BR2_ROOTFS_OVERLAY__.

In order to make use of the overlay, simply add files and directories to
the overlay at ${BR2_IPA_REPO}/overlay/ and they will be copied into the
target filesystem at build time.

**Note:** The following files and directories are ignored and will **not** be
copied into the target.

* Directories like .git .svn and .hg
* Files called .empty
* Files ending in ~

### Adding SSH keys

Note that by default, the SSH server does not allow login by root at all. The
post-build.sh script currently sets __PermitRootLogin prohibit-password__ in
sshd_config if it detects that root has an authorized_keys file. This is done
for convenience so that login will work out of the box.

However, ultimately it's probably better to provide your own complete sshd_config
in the overlay with the configuration options you require.

The easiest way to add SSH keys is with an overlay, see
[Using filesystem overlays](#using-filesystem-overlays).

Create the required root directory structure.

	mkdir -p ${BR2_IPA_REPO}/overlay/{etc/ssh,root/.ssh}

Any keys and configs for _root_ should go under:

* ${BR2_IPA_REPO}/overlay/root/.ssh

If you have pre-generated host keys, then place these under:

* ${BR2_IPA_REPO}/overlay/etc/ssh/

If you wish to override the default sshd_config then you can also do so
by playing it at.

* ${BR2_IPA_REPO}/overlay/etc/ssh/sshd_config

**Note:** Permissions are very important for SSH, so the post-build.sh
script will ensure that these are set correctly.

## Making changes to Busybox

The busybox config is very minimal, however you may find that you want
to add (or remove) some of the packages that it offers.

You can use a menuconfig to make any changes you want (note this
may do some downloading and extracting first).

	make busybox-menuconfig

Be sure to save your changes when you exit menuconfig and see
[Saving changes](#saving-changes) if you want to add them permanently
to Git.

## Making changes to the Linux kernel

The Linux kernel was made from scratch using tiny-config and is
deliberately very limited in the amount of hardware it supports. Having
said that, it is also designed to support a wide range of server grade
hardware.

The idea is to add support for hardware as we encounter it, so please
file a bug report if some essential support is missing.

If you need to make any Linux kernel configuration changes, you can use
the menuconfig (note this may do some downloading, extracting and building
first).

	make linux-menuconfig

Be sure to save your changes when you exit menuconfig and see
[Saving changes](#saving-changes) if you want to add them permanently
to Git.

# Rebuilding

Buildroot makes use of stamp files to track the state of the build. These
are located in the package build directories under ${BR2_OUTPUT_DIR}/build/.

In most cases you can tweak the Buildroot configuration and then just
re-run _make_ to get updated images.

However, if you are making changes to a package which was already built,
Buildroot will not re-build it as the stamps say it is already been done.

In such a case, you can remove the stamp file (or entire package build
directory) and try again.

	rm ./build/python-2.7.13/.stamp_built

You can also tell Buildroot to only build a specific package if you just want
to test rebuilding one package at a time.

	make python

# Saving changes

If you made changes to the Buildroot, Linux kernel or Busybox configs, you
can save them over the top of the existing configs in the IPA buildroot repo.

	make savedefconfig
	make linux-savedefconfig && make linux-update-defconfig
	make busybox-update-config

Then back in the ipa-buildroot repository you can use Git to review/commit
them.

