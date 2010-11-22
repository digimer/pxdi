#!/usr/bin/perl
#
# Based on the RHEL6 tutorial provided by Pasi Kärkkäinen <pasik@iki.fi>
# - http://wiki.xen.org/xenwiki/RHEL6Xen4Tutorial
#
# Author:  Digimer <digimer@alteeve.com>
# Date:    2010-11-18
# Version: 0.3
# License: GPL v2.0+
# 
# Creates an installable Xen 4.0.1 Hypervisor, creates a 2.6.32-25 based dom0
# kernel and then installs the lot on RHEL 6 and derivatives.
# 
### TODO
# - Find a way to show progress while 'yum' is downloading so that it doesn't look hung.
# - Make sure that 'network' is in use and not 'NetworkManager'.
# - Make sure that the interface with the default route is set to 'NM_CONTROLLED="no"'.
# - Do an actual test to see if the Internet connection is working.
# - Make sure that this works with SELinux or else that SELinux is disabled.
# - Check that the hostname is sane.
### TOCHECK
# - 'mkinitrd' is listed on Pasi's tutorial, but is not a package itself. It
#   seems to be provided by 'dracut'.

use strict;
use warnings;
use IO::Handle;
use File::Copy;

# Configuration stuff.
my $conf = {
	confirm		=>	1,
	path		=>	{
		yum		=>	"/usr/bin/yum",
		wget		=>	"/usr/bin/wget",
		git		=>	"/usr/bin/git",
		rpmbuild	=>	"/usr/bin/rpmbuild",
		rpm		=>	"/bin/rpm",
		make		=>	"/usr/bin/make",
		depmod		=>	"/sbin/depmod",
		chkconfig	=>	"/sbin/chkconfig",
		xm		=>	"/usr/sbin/xm",
		patch		=>	"/usr/bin/patch",
		dracut		=>	"/sbin/dracut",
	},
	string		=>	{
		opt_repo	=>	"server-optional-6",
		grp_list_begin	=>	"Installed Groups",
		grp_list_end	=>	"Available Groups",
		pkg_list_begin	=>	"Installed Packages",
		xen_rpm_install	=>	"xen*4.0.1-6*.rpm",
		git_branch	=>	"xen/stable-2.6.32.x",
		git_checkout	=>	"xen/stable-2.6.32.x origin/xen/stable-2.6.32.x",
		patch		=>	"patching file",
	},
	args		=>	{
		yum_repo	=>	"repolist all",
		yum_install_grp	=>	"-y groupinstall",
		yum_install_pkg	=>	"-y install",
		yum_installed_g =>	"grouplist",
		yum_installed_p	=>	"list installed",
		yum_install_rpm	=>	"-y install --nogpgcheck",
		wget		=>	"-c",
		wget_config	=>	"-c -O .config",
		rpm_src		=>	"-ivh",
		rpmbuild	=>	"-bb",
		rpm		=>	"-Uvh",
		rpm_force	=>	"-Uvh --force",
		git_clone	=>	"clone",
		git_branch	=>	"branch",
		git_checkout	=>	"checkout -b",
		make_oc		=>	"oldconfig",
		make_jobs	=>	"-j4",
		patch		=>	"-p0",
		depmod		=>	"-a",
		# If the kernel spec changes, so must this.
		kernel_ver	=>	"2.6.32.25",
		# This is appended to the Xen kernel line in grub.
		xen_kernel	=>	"dom0_mem=1024M",
		grub_timeout	=>	"10",
	},
	files		=>	{
		kernel_git_dir	=>	"linux-2.6-xen",
		pasik_config	=>	".config",
		old_config	=>	".config.old",
		# 'args::kernel_ver' is appended to these.
		dst_bzimage	=>	"/boot/vmlinuz-",
		dst_system_map	=>	"/boot/System.map-",
		dst_config	=>	"/boot/config-",
		grub_in		=>	"/boot/grub/grub.conf",
# 		grub_out	=>	"/boot/grub/grub.conf.dom0",
		grub_out	=>	"/boot/grub/grub.conf",
		yum_depend_grp	=>	[
			"Additional Development",
			"Compatibility libraries",
			"Console internet tools",
			"Debugging Tools",
			"Desktop Platform Development",
			"Development tools",
			"System administration tools",
		],
		yum_depend_pkg	=>	[
			"avahi-devel.x86_64",
			"bridge-utils.x86_64",
			"bzip2-devel.x86_64",
			"cyrus-sasl-devel.x86_64",
			"dev86.x86_64",
			"device-mapper-devel.x86_64",
			"dnsmasq.x86_64",
			"dracut.noarch",
			"e2fsprogs-devel.x86_64",
			"ebtables.x86_64",
			"elinks.x86_64",
			"ethtool.x86_64",
			"gitk.noarch",
			"glibc-devel.x86_64",
			"glibc-devel.i686",
			"gnutls-devel.x86_64",
			"gtk2-devel.x86_64",
			"iasl.x86_64",
			"libaio-devel.x86_64",
			"libcap-ng-devel.x86_64",
			"libcurl-devel.x86_64",
			"libidn-devel.x86_64",
			"libnl-devel.x86_64",
			"libpcap-devel.x86_64",
			"libpciaccess-devel.x86_64",
			"libuuid-devel.x86_64",
			"libudev-devel.x86_64",
			"libX11-devel.x86_64",
			"lzo.x86_64",
			"lzop.x86_64",
			"lvm2.x86_64",
			"lynx.x86_64",
			"man.x86_64",
			"mercurial.x86_64",
			"ncurses-devel.x86_64",
			"netcf-devel.x86_64",
			"ntp.x86_64",
			"ntpdate.x86_64",
			"numactl-devel.x86_64",
			"openssl-devel.x86_64",
			"parted-devel.x86_64",
			"pciutils-devel.x86_64",
			"pciutils-libs.x86_64",
			"pulseaudio-libs-devel.x86_64",
			"python-devel.x86_64",
			"PyXML.x86_64",
			"qemu-img.x86_64",
			"readline-devel.x86_64",
			"iscsi-initiator-utils.x86_64",
			"tcpdump.x86_64",
			"texi2html.noarch",
			"transfig.x86_64",
			"screen.x86_64",
			"SDL-devel.x86_64",
			"smartmontools.x86_64",
			"texinfo.x86_64",
			"vim-enhanced.x86_64",
			"virt-manager.noarch",
			"wget.x86_64",
			"xhtml1-dtds.noarch",
			"xorg-x11-xauth.x86_64",
			"xz-devel.x86_64",
			"yajl-devel.x86_64",
		],
		downloads	=>	{
			qemu_src	=>	"http://download.fedora.redhat.com/pub/fedora/linux/updates/13/SRPMS/qemu-0.12.5-1.fc13.src.rpm",
			libvirt_src	=>	"ftp://ftp.redhat.com/pub/redhat/linux/enterprise/6/en/source/SRPMS/libvirt-0.8.1-27.el6.src.rpm",
			libvirt_patch	=>	"http://pasik.reaktio.net/xen/patches/libvirt-spec-rhel6-enable-xen.patch",
			xen_src		=>	"http://download.fedora.redhat.com/pub/fedora/linux/releases/14/Everything/source/SRPMS/xen-4.0.1-6.fc14.src.rpm",
			kernel_src	=>	"git://git.kernel.org/pub/scm/linux/kernel/git/jeremy/xen.git",
			kernel_config	=>	"http://pasik.reaktio.net/xen/kernel-config/config-2.6.32.25-pvops-dom0-xen-stable-x86_64",
		},
		specs		=>	{
			qemu		=>	"qemu.spec",
			libvirt		=>	"libvirt.spec",
			xen		=>	"xen.spec",
		},
		rpms		=>	{
			# Only need one of each. It's safe to assume that if
			# one RPM exists, they've all been built.
			qemu_common	=>	"qemu-common-0.12.5-1.el6.x86_64.rpm",
			qemu_kvm	=>	"",
			qemu_kvm_tools	=>	"",
			libvirt		=>	"libvirt-0.8.1-27.el6.x86_64.rpm",
			libvirt_client	=>	"libvirt-client-0.8.1-27.el6.x86_64.rpm",
			libvirt_python	=>	"libvirt-python-0.8.1-27.el6.x86_64.rpm",
			xen		=>	"xen-4.0.1-6.el6.x86_64.rpm",
			xen_libs	=>	"xen-libs-4.0.1-6.el6.x86_64.rpm",
			xen_runtime	=>	"xen-runtime-4.0.1-6.el6.x86_64.rpm",
			xen_hypervisor	=>	"xen-hypervisor-4.0.1-6.el6.x86_64.rpm",
			xen_doc		=>	"xen-doc-4.0.1-6.el6.x86_64.rpm",
			xen_devel	=>	"xen-devel-4.0.1-6.el6.x86_64.rpm",
			xen_license	=>	"xen-licenses-4.0.1-6.el6.x86_64.rpm",
			xen_debuginfo	=>	"xen-debuginfo-4.0.1-6.el6.x86_64.rpm",
		},
		bins		=>	{
			# These differ from the 'path's above as they are
			# checked to see that the compiled RPMs installed.
			qemu_nbd	=>	"/usr/bin/qemu-nbd",
			libvirt		=>	"/usr/sbin/libvirtd",
			libvirt_client	=>	"/usr/bin/virsh",
			libvirt_python	=>	"/usr/lib64/python2.6/site-packages/libvirt.py",
			libvirt_patch	=>	"libvirt-spec-rhel6-enable-xen.patch",
			xen		=>	"/usr/sbin/xm",
			xen_libs	=>	"/usr/lib64/libxenctrl.so.4.0",
			xen_runtime	=>	"/usr/bin/xenstore",
			xen_hypervisor	=>	"/boot/xen.gz",
			xen_doc		=>	"/usr/share/doc/xen-doc-4.0.1/user.pdf",
			xen_devel	=>	"/usr/include/blktaplib.h",
			xen_license	=>	"/usr/share/doc/xen-licenses-4.0.1/COPYING",
			xen_debuginfo	=>	"/usr/lib/debug/usr/bin/xen-detect.debug",
			kernel_bzImage	=>	"arch/x86/boot/bzImage",
			# The following is not adequate. It is found.
			kernel_modules	=>	"firmware/vicam/firmware.fw",
			kernel_mod_inst =>	"/lib/modules/2.6.32.25/build",
		},
	},
	chkconfig	=>	{
		ksm		=>	"off",
		ksmtuned	=>	"off",
		libvirtd	=>	"on",
	},
	installed	=>	{
		groups		=>	[],
		packages	=>	[],
	},
};

# Make STDOUT hot.
$|=0;

### Run all functions.
# Make sure the script is running as root.
is_root($conf);

# Ask the user to confirm before proceeding.
confirm($conf);

# Check that I have acccess to the "optional" repo.
check_repo($conf);

# Install package groups. If it installs something, it calls a second time.
if (install_dep_groups($conf, "1")) { install_dep_groups($conf, "2"); }

# Install packages. If it installs something, it calls a second time.
if (install_dep_packages($conf, "1")) { install_dep_packages($conf, "2") }

# Build and install qemu from source.
build_and_install_qemu($conf);

# Build and install the xen hypervisor from source.
build_and_install_xen_hv($conf);

# Build and install libvirt from source.
patch_build_and_install_libvirt($conf);

# Compile and install the kernel.
compile_patch_and_instal_dom0($conf);

# Turn services off and on.
run_chkconfig($conf);

# The last step is to insert the new kernel into Grub.
add_dom0_to_grub($conf);

exit 0;

### Functions

# This reads in grub.conf, creates an entry for the new kernel and the writes
# out a new grub.conf (possibly to a different file for the user to analyze).
sub add_dom0_to_grub
{
	my ($conf)=@_;
	
	# Read in the existing file
	my @lines;
	my $root_dev="";
	my $kernel_args="";
	my $abort=0;
	my $title="title Xen 4.0 with Linux $conf->{args}{kernel_ver} dom0";
	
	my $read=IO::Handle->new();
	my $shell_call="< $conf->{files}{grub_in}";
	open ($read, $shell_call) || die "Failed to call: [$shell_call]\n";
	while (<$read>)
	{
		my $line=$_;
		chomp ($line);
		$abort=1 if $line =~ /$title/;
		$line=~s/timeout=\d+/timeout=$conf->{args}{grub_timeout}/;
		if (( not $root_dev ) && ( $line =~ /^\s+root \((.*?)\)/ ))
		{
			$root_dev=$1;
		}
		if (( not $kernel_args ) && ( $line =~ /^\s+kernel \/vmlinuz-.*?\s+(.*)$/ ))
		{
			$kernel_args=$1;
		}
		push @lines, $line;
	}
	$read->close();
	
	# Backup the original grub file if I am about to overwrite the existing
	# grub.conf.
	my $backup=$conf->{files}{grub_in}.".original";
	my $grub_backed_up=0;
	if (( not -e $backup ) && ($conf->{files}{grub_in} eq $conf->{files}{grub_out}))
	{
		print "Backing up the original Grub menu.\n";
		print " - $conf->{files}{grub_in}\n";
		print " - $backup\n";
		copy_file($conf, $conf->{files}{grub_in}, $backup);
		$grub_backed_up=1;
	}
	
	# Create the rest of my grub strings.
	my $root="\troot ($root_dev)";
	my $xen_kernel="\tkernel /xen.gz $conf->{args}{xen_kernel}";
	my $vmlinuz="\tmodule /vmlinuz-".$conf->{args}{kernel_ver}." $kernel_args";
	my $initramfs="\tmodule /initramfs-".$conf->{args}{kernel_ver}.".img";
	
	# Shall I abort?
	if ($abort)
	{
		print "WARNING: I found an entry already in grub with the following title:\n";
		print "         - $title\n";
		print "         Grub injection has been aborted.\n";
		print "If you want to replace the existing entry, use this:\n";
		print "##############################################################################\n";
		print "$title\n";
		print "$root\n";
		print "$xen_kernel\n";
		print "$vmlinuz\n";
		print "$initramfs\n";
		print "##############################################################################\n";
		print "\nIt looks like the install was a success. You should be able to reboot into\n";
		print "the new dom0 kernel now.\n\n";
	}
	else
	{
		my $write=IO::Handle->new();
		my $shell_call="> $conf->{files}{grub_out}";
		open ($write, $shell_call) || die "Failed to call: [$shell_call]\n";
		
		my $injected=0;
		foreach my $line (@lines)
		{
			if ((not $injected) && ($line =~ /title/))
			{
				print $write "\n#This kernel added by the 'pxdi_rhel6.pl' program.\n";
				print $write "$title\n";
				print $write "$root\n";
				print $write "$xen_kernel\n";
				print $write "$vmlinuz\n";
				print $write "$initramfs\n";
				$injected=1;
			}
			print $write "$line\n";
		}
		$write->close();
		
		print "\nSUCCESS! Done! Finished!\n\n";
		print "Wrote out new grub menu as:\n";
		if ($conf->{files}{grub_in} eq $conf->{files}{grub_out})
		{
			print "The new dom0 kernel should now be written to your grub menu.\n";
			print "The original grub menu was backed up to:\n" if $grub_backed_up;
			print " - $backup\n\n" if $grub_backed_up;
			print "You should now be able to reboot into the dom0 and 'libvirt' should work!\n\n";
		}
		else
		{
			print "The updated grub menu has been written to:\n";
			print " - $conf->{files}{grub_out}\n\n";
			print "Please verify that it looks okay and then copy it to:\n";
			print " - $conf->{files}{grub_in}\n\n";
			print "One copied, you should be able to reboot into dom0 and 'libvirt' should work!\n\n";
		}
	}
	print "If you run into problems with this installer, please let me know:\n";
	print " - Digimer; digimer\@alteeve.com\n\n";
	print "Thanks to Pasi Kärkkäinen for the tutorial that this installer is based on.\n\n";
	print "Please note; When this kernel starts to boot, it will pause for ~1 minute.\n";
	print "Be patient, it should boot. Also note, this kernel has several debug options\n";
	print "enabled, so it will not benchmark very well, but it should be reliable.\n\n";
	print "Have fun!!\n\n";
}

# This turns services on and off.
sub run_chkconfig
{
	my ($conf)=@_;
	
	# Run the 'chkconfig's.
	print "Altering services\n";
	foreach my $service (sort {$a cmp $b} keys %{$conf->{chkconfig}})
	{
		my $chkconfig=IO::Handle->new();
		my $shell_call="$conf->{path}{chkconfig} $service $conf->{chkconfig}{$service} 2>&1 |";
		print " - Switching: [$service] to: [$conf->{chkconfig}{$service}]\n";
# 		print "Shell call: [$shell_call]\n";
		open ($chkconfig, $shell_call) || die "Failed to call: [$shell_call]\n";
		while (<$chkconfig>)
		{
			print "> ".$_;
		}
		$chkconfig->close();
	}
}

# This compiles, patches and the installs dom0. Shocking, I know.
sub compile_patch_and_instal_dom0
{
	my ($conf)=@_;
	
	# Pull down the upstream kernel using git.
	chdir "$ENV{HOME}" || die "failed to change the directory: $!\n";
	my $git_clone_dir="$ENV{HOME}/$conf->{files}{kernel_git_dir}";
	print "I will now clone the upstream 2.6.32 kernel into the following directory.\n";
	print " - $git_clone_dir\n";
	if ( -e $git_clone_dir )
	{
		print "The upstream kernel appears to have already been cloned; Skipping.\n";
	}
	else
	{
		# Clone
		my $git=IO::Handle->new();
		my $shell_call="$conf->{path}{git} $conf->{args}{git_clone} $conf->{files}{downloads}{kernel_src} $git_clone_dir 2>&1 |";
# 		print "Shell call: [$shell_call]\n";
		print "WARNING: The clone process can take a very long time, depending on the speed of\n";
		print "         your Internet connection for the download phase and processor for the\n";
		print "         decompression stage. To confirm that it is not hung, run 'top' on\n";
		print "         another terminal.\n";
		sleep 2;
# 		exit;
		open ($git, $shell_call) || die "Failed to call: [$shell_call]\n";
		print "/--------------------\n";
		while (<$git>)
		{
			print "| ".$_;
		}
		print "\\--------------------\n";
		$git->close();
	}
	
	# Checkout the stable branch if not yet done.
	print "Switching to the git stable branch.\n";
	chdir "$git_clone_dir" || die "failed to change the directory to: [$git_clone_dir]. Error: $!\n";
	if (check_git_kernel_branch($conf))
	{
		print " - Already using the stable branch; Skipping\n";
	}
	else
	{
		my $git_co=IO::Handle->new();
		my $shell_call="$conf->{path}{git} $conf->{args}{git_checkout} $conf->{string}{git_checkout} 2>&1 |";
# 		print "Shell call: [$shell_call]\n";
		open ($git_co, $shell_call) || die "Failed to call: [$shell_call]\n";
		print "/--------------------\n";
		while (<$git_co>)
		{
			print "| ".$_;
		}
		print "\\--------------------\n";
		$git_co->close();
		if (check_git_kernel_branch($conf))
		{
			print " - Success! Now using branch: [$conf->{string}{git_branch}]\n";
		}
		else
		{
			print "[ERROR]\n";
			print "Failed to switch to the upstream kernel's stable git branch.\n\n";
			print "Exiting.\n";
		}
	}
	
	# Check to see if Pasik's ".config" is down.
	print "Downloading Pasik's dom0 '.config' file.\n";
	if ( -e $conf->{files}{pasik_config} )
	{
		print " - It looks like we already have it; Skipping.\n";
	}
	else
	{
		# Do the download. I don't need to check for success as the
		# function below does so and exits on error.
		my $url=$conf->{files}{downloads}{kernel_config};
		download_file($conf, $url, "wget_config");
		print " - Success!\n";
	}
	
	# Now I will compile the kernel.
	print "Now compiling the kernel 2.6.32 dom0 kernl.\n";
	my $bzImage="$git_clone_dir/$conf->{files}{bins}{kernel_bzImage}";
	if ( -e $bzImage )
	{
		print " - I found the kernel's bzImage file below, compile appears to be completed\n";
		print "   already; Skipping.\n";
	}
	else
	{
		print " - Making '.config' with: [$conf->{args}{make_oc}]\n";
		my $old_config="$git_clone_dir/$conf->{files}{bins}{old_config}";
		if ( -e $old_config )
		{
			print " - It looks like the '.config' has already been updated; Skipping.\n";
		}
		else
		{
			my $make_oc=IO::Handle->new();
			my $shell_call="$conf->{path}{make} $conf->{args}{make_oc} 2>&1 |";
# 			print "Shell call: [$shell_call]\n";
			open ($make_oc, $shell_call) || die "Failed to call: [$shell_call]\n";
			print "/--------------------\n";
			while (<$make_oc>)
			{
				print "| ".$_;
			}
			print "\\--------------------\n";
			$make_oc->close();
			if ( -e $old_config )
			{
				print " - Success!\n";
			}
			else
			{
				print "[ERROR]\n";
				print "I tried to reconfigure the '.config' file using the following command.\n";
				print " - $conf->{path}{make} $conf->{args}{make_oc}\n";
				print "It seems to have failed though, as I didn't find the expected file:\n";
				print " - $old_config\n";
				print "Exiting.\n";
				exit -12;
			}
		}
		
		# Now make the kernel!
		print "Now compiling the kernel.\n";
		print "WARNING! This can take a very, very long time depending on the speed of your\n";
		print "         processor(s). Please be patient and watch 'top' from another terminal.\n";
		my $make_bz=IO::Handle->new();
		my $shell_call="$conf->{path}{make} $conf->{args}{make_jobs} bzImage 2>&1 |";
# 		print "Shell call: [$shell_call]\n";
		open ($make_bz, $shell_call) || die "Failed to call: [$shell_call]\n";
		print "/--------------------\n";
		while (<$make_bz>)
		{
			print "| ".$_;
		}
		print "\\--------------------\n";
		$make_bz->close();
		if ( -e $bzImage )
		{
			print " - Success!\n";
		}
		else
		{
			print "[ERROR]\n";
			print "I tried to compile the 2.6.32 kernel using the following command.\n";
			print " - $conf->{path}{make} $conf->{args}{make_oc} bzImage\n";
			print "It seems to have failed though, as I didn't find the expected file:\n";
			print " - $bzImage\n";
			print "Exiting.\n";
			exit -13;
		}
	}
	
	# Make the modules
	my $module="$git_clone_dir/$conf->{files}{bins}{kernel_modules}";
# 	if ($module)
	if (0)
	{
		print "I found a sample module from module compile stage, so it looks to be completed\n";
		print "already; Skipping.\n";
	}
	else
	{
		# Now make the kernel!
		print "WARNING! This can take a very, very long time depending on the speed of your\n";
		print "         processor(s). Please be patient and watch 'top' from another terminal.\n";
		my $make_mod=IO::Handle->new();
		my $shell_call="$conf->{path}{make} $conf->{args}{make_jobs} modules 2>&1 |";
# 		print "Shell call: [$shell_call]\n";
		open ($make_mod, $shell_call) || die "Failed to call: [$shell_call]\n";
		print "/--------------------\n";
		while (<$make_mod>)
		{
			print "| ".$_;
		}
		print "\\--------------------\n";
		$make_mod->close();
		
		if ( -e $module )
		{
			print " - Success!\n";
		}
		else
		{
			print "[ERROR]\n";
			print "I tried compiling the modules for the 2.6.32 kernel using:\n";
			print " - $conf->{path}{make} $conf->{args}{make_jobs} modules\n";
			print "It seems to have failed though, as I didn't find an expected file:\n";
			print " - $module\n";
			print "Exiting.\n";
			exit -14;
		}
	}
	
	# Install the lot now.
	chdir "$git_clone_dir" || die "failed to change the directory to: [$git_clone_dir]. Error: $!\n";
	my $kernel_mod_inst=$conf->{files}{bins}{kernel_mod_inst};
# 	if ($kernel_mod_inst)
	if (0)
	{
		print " - It looks like the kernel modules have already been installed; Skipping.\n";
	}
	else
	{
		# Now make the kernel!
		print "Compiling the kernel modules now.\n";
		print "WARNING! This can take a very, very long time depending on the speed of your\n";
		print "         processor(s). Please be patient and watch 'top' from another terminal.\n";
		my $make_ins=IO::Handle->new();
		my $shell_call="$conf->{path}{make} modules_install 2>&1 |";
# 		print "Shell call: [$shell_call]\n";
		open ($make_ins, $shell_call) || die "Failed to call: [$shell_call]\n";
		print "/--------------------\n";
		while (<$make_ins>)
		{
			print "| ".$_;
		}
		print "\\--------------------\n";
		$make_ins->close();
		
		if ($kernel_mod_inst)
		{
			print " - Success!\n";
		}
		else
		{
			print "[ERROR]\n";
			print "I tried compiling the modules for the 2.6.32 kernel using:\n";
			print " - $conf->{path}{make} $conf->{args}{make_jobs} modules\n";
			print "It seems to have failed though, as I didn't find an expected file:\n";
			print " - $module\n";
			print "Exiting.\n";
			exit -14;
		}
	}
	
	# Call 'depmod'. I don't know of any way to tell if this was run
	# before, though I assume there is. I'll adapt this clause then.
	if (0)
	{
		# Depmod already run.
		print "Depmod already run ...\n";
	}
	else
	{
		print "Running depmod.\n";
		print "WARNING! This can take a long time depending on the speed of your processor(s).\n";
		print "         Please be patient and watch 'top' from another terminal.\n";
		my $ok=1;
		my $depmod=IO::Handle->new();
		my $shell_call="$conf->{path}{depmod} $conf->{args}{depmod} $conf->{args}{kernel_ver} 2>&1 |";
# 		print "Shell call: [$shell_call]\n";
		open ($depmod, $shell_call) || die "Failed to call: [$shell_call]\n";
		while (<$depmod>)
		{
			$ok=0;
			print "> ".$_;
		}
		$depmod->close();
		
		if ($ok)
		{
			print " - Success!\n";
		}
		else
		{
			print "[ERROR]\n";
			print "There was output while running depmod using the call below. There shouldn't\n";
			print "have been any output, so I have to assume that something went wrong.\n";
			print " - $conf->{path}{depmod} $conf->{args}{depmod} $conf->{args}{kernel_ver}\n";
			print "Exiting.\n";
			exit -16;
		}
	}
	chdir "$ENV{HOME}" || die "failed to change the directory to: [$ENV{HOME}]. Error: $!\n";
	
	# Now copy the files into place.
	my $src_bzimage="$ENV{HOME}/$conf->{files}{kernel_git_dir}/arch/x86/boot/bzImage";
	my $dst_bzimage=$conf->{files}{dst_bzimage}.$conf->{args}{kernel_ver},
	my $src_sys_map="$ENV{HOME}/$conf->{files}{kernel_git_dir}/System.map";
	my $dst_sys_map=$conf->{files}{dst_system_map}.$conf->{args}{kernel_ver},
	my $src_config="$git_clone_dir/.config";
	my $dst_config=$conf->{files}{dst_config}.$conf->{args}{kernel_ver},
	copy_file($conf, $src_bzimage, $dst_bzimage);
	copy_file($conf, $src_sys_map, $dst_sys_map);
	copy_file($conf, $src_config, $dst_config);
	
	my $target="/boot/initramfs-".$conf->{args}{kernel_ver}.".img";
	if ( -e $target )
	{
		print "It looks like 'dracut' has already been run for the kernel:\n";
		print " - initramfs-".$conf->{args}{kernel_ver}.".img\n";
		print " - Skipping\n";
	}
	else
	{
		print "Running dracut\n";
		print "WARNING! This can take a long time depending on the speed of your processor(s).\n";
		print "         Please be patient and watch 'top' from another terminal.\n";
		chdir "/boot" || die "failed to change the directory to: [/boot]. Error: $!\n";
# 		print "Current dir: "; system ('pwd');
		my $dracut=IO::Handle->new();
		my $shell_call="$conf->{path}{dracut} initramfs-".$conf->{args}{kernel_ver}.".img $conf->{args}{kernel_ver} 2>&1 |";
# 		print "Shell call: [$shell_call]\n";
		my $ok=1;
		open ($dracut, $shell_call) || die "Failed to call: [$shell_call]\n";
		while (<$dracut>)
		{
			$ok=0;
			print "> ".$_;
		}
		$dracut->close();
		chdir "$ENV{HOME}" || die "failed to change the directory: $!\n";
		if ($ok)
		{
			print " - Success!\n";
		}
		else
		{
			print "[ERROR]\n";
			print "There was output while running dracut using the call below. There shouldn't\n";
			print "have been any output, so I have to assume that something went wrong.\n";
			print " - $conf->{path}{dracut} initramfs-".$conf->{args}{kernel_ver}.".img $conf->{args}{kernel_ver}\n";
			print "Exiting.\n";
			exit -17;
		}
	}
	
	# Return to the home directory.
	chdir "$ENV{HOME}" || die "failed to change the directory: $!\n";
}

# This copies a file, but checks first that the destination doesn't exist and
# returns without copying if so.
sub copy_file
{
	my ($conf, $src, $dst)=@_;
	
	die "No source given to 'copy_file'\n" if not $src;
	die "No destination given to 'copy_file'\n" if not $dst;
	
	# Check to see if the destination exists.
	if ( -e $dst )
	{
		print "WARNING: I was going to copy to following file:\n";
		print "         - $src\n";
		print "         To the following destination and name:\n";
		print "         - $dst\n";
		print "         But the destination already exists, so I am skipping it.\n";
		print "         You may need to manually copy the file into place.\n";
	}
	copy ($src, $dst) || die "Failed to copy: [$src] to [$dst]. Error: $!\n";
}

# This builds qemu from the RHEL 6 source repo.
sub patch_build_and_install_libvirt
{
	my ($conf)=@_;
	
	# Make the URL and file cleaner.
	my $url		= $conf->{files}{downloads}{libvirt_src};
	my $spec	= "$ENV{HOME}/rpmbuild/SPECS/".$conf->{files}{specs}{"libvirt"};
	my $rpm_libvirt	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"libvirt"};
	my $rpm_client	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"libvirt_client"};
	my $rpm_python	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"libvirt_python"};
	my $bin_libvirt	= $conf->{files}{bins}{"libvirt"};
	my $bin_client	= $conf->{files}{bins}{"libvirt_client"};
	my $bin_python	= $conf->{files}{bins}{"libvirt_python"};
	
	### TODO
	# run md5 against these compiled RPMs if possible to tell the
	# difference. Perhaps file size difference otherwise?
	### NOTE
	# I can't check for a binary as it may exist from the stock RHEL
	# install. Instead, check for the RPMs.
	if (( -e $rpm_libvirt ) && ( -e $rpm_client ) && ( -e $rpm_python ))
	{
		# Looks like the binary is already installed.
		print "I found all three compiled RPMs:\n";
		print " - $rpm_libvirt\n";
		print " - $rpm_client\n";
		print " - $rpm_python\n";
		print "I will skip directly to installing.\n";
	}
	else
	{
		# Download the source RPM
		my $src_file=download_file($conf, $url, "wget");
		install_src_rpm($conf, $src_file, $spec);
		
		# I need to patch the .spec file before I can compile it.
		print "Applying patch to original spec file.\n";
		my $patch_file="$ENV{HOME}/rpmbuild/SPECS/$conf->{files}{bins}{libvirt_patch}";
		if ( -e $patch_file )
		{
			print " - Patch file: [$conf->{files}{bins}{libvirt_patch}] already downloaded.\n";
		}
		else
		{
			# I have to be in the SPECS directory for the patch to
			# apply.
			my $spec_dir="$ENV{HOME}/rpmbuild/SPECS";
			chdir "$spec_dir" || die "failed to change the directory: $!\n";
			
			# Download the patch.
			print " - Downloading patch.\n";
			my $url=$conf->{files}{downloads}{libvirt_patch};
			download_file($conf, $url, "wget");
		}
		
		# Backup the original spec file.
		my $spec_bak=$spec.".orig";
		if ( -e $spec_bak )
		{
			# Backup found, assuming that the patch has
			# already been applied,
			print "I found the backup of the original spec file, so I am assuming that the patch\n";
			print "has already been applied. If this is not the case, please restore the backup by\n";
			print "copying the backup:\n";
			print " - $spec_bak\n";
			print "Over the existing .spec file:\n";
			print " - $spec\n";
			print "Proceeding with compile in five seconds.\n";
			sleep 5;
		}
		else
		{
			# I have to be in the SPECS directory for the patch to
			# apply.
			my $spec_dir="$ENV{HOME}/rpmbuild/SPECS";
			chdir "$spec_dir" || die "failed to change the directory: $!\n";
			
			# Backup the original spec file before patching.
			print " - Making a backup of the original .spec file.\n";
			copy ($spec, $spec_bak) || die "Failed to copy: [$spec] to [$spec_bak]. Error: $!\n";
			
			print " - Applying patch.\n";
			my $patch_ok=0;
			my $patch=IO::Handle->new();
			my $shell_call="$conf->{path}{patch} $conf->{args}{patch} < $patch_file 2>&1 |";
# 			print "Shell call: [$shell_call]\n";
			open ($patch, $shell_call) || die "Failed to call: [$shell_call]\n";
			print "/--------------------\n";
			while (<$patch>)
			{
				my $line=$_;
				chomp ($line);
				print "| $line\n";
				$patch_ok=1 if $line =~ /$conf->{string}{patch}/;
			}
			print "\\--------------------\n";
			$patch->close();
			
			if ($patch_ok)
			{
				print " - Successfully applied the patch\n";
			}
			else
			{
				print "[ERROR]\n";
				print "It would appear that the patch didn't apply successfully. Please consult the\n";
				print "output above this message for hints. I was expecting to see the string:\n";
				print " - $conf->{string}{patch}\n";
				print "But I did not.\n\n";
				print "Exiting.\n";
				exit -15;
			}
		}
		
		# Go back to the home directory.
		chdir "$ENV{HOME}" || die "failed to change the directory: $!\n";
		compile_spec($conf, $spec, $rpm_libvirt);
	}
	install_rpms($conf, $rpm_libvirt, $bin_libvirt);
	install_rpms($conf, $rpm_client, $bin_client);
	install_rpms($conf, $rpm_python, $bin_python);
}

# This checks the current git branch and returns 1 if on the stable branch.
sub check_git_kernel_branch
{
	my ($conf)=@_;
	
	my $on_stable=0;
	my $git_branch=IO::Handle->new();
	my $shell_call="$conf->{path}{git} $conf->{args}{git_branch} 2>&1 |";
	open ($git_branch, $shell_call) || die "Failed to call: [$shell_call]\n";
	while (<$git_branch>)
	{
		my $line=$_;
		chomp($line);
		$on_stable=1 if $line =~ /^\* $conf->{string}{git_branch}/;
		last if $on_stable;
	}
	$git_branch->close();
	
	return ($on_stable);
}

# This builds the Xen 4.0.1 hypervisor from the Fedora 14 source.
sub build_and_install_xen_hv
{
	my ($conf)=@_;
	
	# Make the URL and file cleaner.
	my $url			= $conf->{files}{downloads}{xen_src};
	my $spec		= "$ENV{HOME}/rpmbuild/SPECS/".$conf->{files}{specs}{"xen"};
	my $rpm_xen		= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"xen"};
	my $rpm_xen_libs	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"xen_libs"};
	my $rpm_xen_runtime	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"xen_runtime"};
	my $rpm_xen_hypervisor	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"xen_hypervisor"};
	my $rpm_xen_doc		= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"xen_doc"};
	my $rpm_xen_devel	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"xen_devel"};
	my $rpm_xen_license	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"xen_license"};
	my $rpm_xen_debuginfo	= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"xen_debuginfo"};
	my $bin_xen		= $conf->{files}{bins}{"xen"};
	my $bin_xen_libs	= $conf->{files}{bins}{"xen_libs"};
	my $bin_xen_runtime	= $conf->{files}{bins}{"xen_runtime"};
	my $bin_xen_hypervisor	= $conf->{files}{bins}{"xen_hypervisor"};
	my $bin_xen_doc		= $conf->{files}{bins}{"xen_doc"};
	my $bin_xen_devel	= $conf->{files}{bins}{"xen_devel"};
	my $bin_xen_license	= $conf->{files}{bins}{"xen_license"};
	my $bin_xen_debuginfo	= $conf->{files}{bins}{"xen_debuginfo"};
	
	# Check to see if I need to compile the .spec.
	if ( -e $bin_xen )
	{
		# Looks like the binary is already installed.
		print "I found the binary:\n";
		print "- $bin_xen\n";
		print "It looks like the Xen hypervisor has already been compiled and installed.\n";
	}
	else
	{
		# Compile from source.
		my $src_file=download_file($conf, $url, "wget");
		install_src_rpm($conf, $src_file, $spec);
		compile_spec($conf, $spec, $rpm_xen);
	}
	
	# I want to install all RPMs in one shot, so I do the actual install
	# call here if the xen binary doesn't exist yet.
	if ( -e $bin_xen )
	{
		print "It looks like the Xen hypervisor has already been installed; Skipping.\n";
	}
	else
	{
		my $yum=IO::Handle->new();
		my $rpm_string="$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{string}{xen_rpm_install};
		my $shell_call="$conf->{path}{rpm} $conf->{args}{rpm} $rpm_string 2>&1 |";
	# 	print "Shell call: [$shell_call]\n";
		open ($yum, $shell_call) || die "Failed to call: [$shell_call]\n";
		print "/--------------------\n";
		while (<$yum>)
		{
			print "| ".$_;
		}
		print "\\--------------------\n";
		$yum->close();
		
		# I cheat a bit here. I reuse this function for each RPM to ensure that
		# it installed properly.
		print "All Xen RPMs will now be checked individually. If the prior step succeeded,\n";
		print "these should all exit saying that the RPM was already installed.\n";
		install_rpms($conf, $rpm_xen, 		$bin_xen);
		install_rpms($conf, $rpm_xen_libs, 	$bin_xen_libs);
		install_rpms($conf, $rpm_xen_runtime, 	$bin_xen_runtime);
		install_rpms($conf, $rpm_xen_hypervisor, $bin_xen_hypervisor);
		install_rpms($conf, $rpm_xen_doc, 	$bin_xen_doc);
		install_rpms($conf, $rpm_xen_devel, 	$bin_xen_devel);
		install_rpms($conf, $rpm_xen_license, 	$bin_xen_license);
		install_rpms($conf, $rpm_xen_debuginfo, $bin_xen_debuginfo);
	}
}

# This installs the RPMs built by a previous 'compile_spec' call.
sub install_rpms
{
	my ($conf, $rpm, $binary)=@_;
	
	# If the RPM exists, exit as this step is done. The exception being the
	# libvirt and virsh binaries as we're replacing the stock ones.
	my $shell_call="$conf->{path}{yum} $conf->{args}{yum_install_rpm} $rpm 2>&1 |";
	if ($rpm =~ /vir/ )
	{
		$shell_call="$conf->{path}{rpm} $conf->{args}{rpm_force} $rpm 2>&1 |";
	}
	elsif( -e $binary )
	{
		# Looks like the binary is already installed.
		print "It looks like following RPM has already been installed.\n";
		print "- $rpm\n";
		print "As I found it's binary:\n";
		print "- $binary\n";
		return;
	}
	
	# Still here? Ok, compile.
	print "Now installing the RPM file:\n";
	print " - $rpm\n";
	
	my $yum=IO::Handle->new();
# 	print "Shell call: [$shell_call]\n";
	open ($yum, $shell_call) || die "Failed to call: [$shell_call]\n";
	print "/--------------------\n";
	while (<$yum>)
	{
		print "| ".$_;
	}
	print "\\--------------------\n";
	$yum->close();
	
	# If the RPM exists, success!
	if ( -e $binary )
	{
		# Looks like the binary is already installed.
		print " - Success! I found the RPM's binary:\n";
		print " - $binary\n";
	}
	else
	{
		print "[ERROR]\n";
		print "It looks like I failed to install the RPM:\n";
		print " - $rpm\n";
		print "I expected to find the following binary, but did not.\n";
		print "- $binary\n";
		print "Exiting.\n";
		exit -10;
	}
}

# This builds qemu from the Fedora 13 source.
sub build_and_install_qemu
{
	my ($conf)=@_;
	
	# Make the URL and file cleaner.
	my $url		= $conf->{files}{downloads}{"qemu_src"};
	my $spec	= "$ENV{HOME}/rpmbuild/SPECS/".$conf->{files}{specs}{"qemu"};
	my $rpm		= "$ENV{HOME}/rpmbuild/RPMS/x86_64/".$conf->{files}{rpms}{"qemu_common"};
	my $binary	= $conf->{files}{bins}{"qemu_nbd"};
	if ( -e $binary )
	{
		# Looks like the binary is already installed.
		print "I found the binary:\n";
		print "- $binary\n";
		print "It looks like qemu has already been compiled and installed.\n";
	}
	else
	{
		my $src_file=download_file($conf, $url, "wget");
		install_src_rpm($conf, $src_file, $spec);
		compile_spec($conf, $spec, $rpm);
		install_rpms($conf, $rpm, $binary);
	}
}

# This uses 'rpmbuild' to compile RPMs using the given spec file.
sub compile_spec
{
	my ($conf, $spec, $rpm)=@_;
	
	# If the RPM exists, exit as this step is done.
	print "I will now compile RPM(s) from the spec file:\n";
	print " - $spec\n";
	if ( -e $rpm )
	{
		print "Found the following RPM, so it looks like this step is already done. Returning.\n";
		print " - $rpm\n";
		return;
	}
	
	# Still here? Ok, compile.
	print "Please be patient. Now compiling RPM using spec file:\n";
	print " - $spec\n";
	
	my $rpmbuild=IO::Handle->new();
	my $shell_call="$conf->{path}{rpmbuild} $conf->{args}{rpmbuild} $spec 2>&1 |";
# 	die "Shell call: [$shell_call]\n";
	open ($rpmbuild, $shell_call) || die "Failed to call: [$shell_call]\n";
	print "/--------------------\n";
	while (<$rpmbuild>)
	{
		print "| ".$_;
	}
	print "\\--------------------\n";
	$rpmbuild->close();
	
	# Make sure the expected RPM now exist.
	if ( -e $rpm )
	{
		print " - Success! Found the RPM below as expected.\n";
		print " - $rpm\n";
	}
	else
	{
		print "[ERROR]\n";
		print "I failed to find the expected, newly-compiled, RPM:\n";
		print " - $rpm\n\n";
		print "Exiting.\n";
		exit -9;
	}
}

# This installs the referenced source RPM. It is assumed that the file's
# existence was confirmed before this step.
sub install_src_rpm
{
	my ($conf, $file, $spec)=@_;
	
	# Before I install, do a check to see if there is a '.spec' file yet.
	print "Now installing the source RPM:\n";
	print " - $file\n";
	if ( -e $spec )
	{
		print " - Skipping as the spec file below was found to already exist.\n";
		print " - $file\n";
		return;
	}
	
	my $wget=IO::Handle->new();
	my $shell_call="$conf->{path}{rpm} $conf->{args}{rpm_src} $file 2>&1 |";
# 	die "Shell call: [$shell_call]\n";
	open ($wget, $shell_call) || die "Failed to call: [$shell_call]\n";
	print "/--------------------\n";
	while (<$wget>)
	{
		print "| ".$_;
	}
	print "\\--------------------\n";
	$wget->close();
	
	if ( -e $spec )
	{
		print "Install successful!\n";
	}
	else
	{
		print "[ERROR]\n";
		print "Install seems to have failed. Didn't find the expected spec file:\n";
		print " - $spec\n";
		exit -8;
	}
}

# This downloads the requested file to the user's home directory.
sub download_file
{
	my ($conf, $url, $wget_arg)=@_;
	
	# Make the URL and file cleaner.
	my ($file)=($url=~/.*\/(.*?)$/);
	if ($wget_arg eq "wget_config")
	{
		$file=".config";
	}
	elsif ($file !~ /.patch$/)
	{
		# Make sure I'm in the user's home directory.
		chdir "$ENV{HOME}" || die "failed to change the directory: $!\n";
	}
	
	# Download the file if it doesn't already exist.
	if ( -e $file )
	{
		print "The target file below already exists, skipping download.\n";
		print " - $file\n";
	}
	else
	{
		# Download it with wget.
		print "Fetching: [$url] \n";
		my $wget=IO::Handle->new();
		my $shell_call="$conf->{path}{wget} $conf->{args}{$wget_arg} $url 2>&1 |";
		open ($wget, $shell_call) || die "Failed to call: [$shell_call]\n";
		print "/--------------------\n";
		while (<$wget>)
		{
			print "| ".$_;
		}
		print "\\--------------------\n";
		$wget->close();
		
		# Make sure it's now downloaded.
		if ( -e $file )
		{
			print "Download successful!\n";
		}
		else
		{
			print "[ERROR]\n";
			print "I tried to download the file:\n";
			print " - $file\n";
			print "From the URL:\n";
			print " - $url\n";
			print "Into the directory:\n";
			print " - "; system ('pwd');
			print "This appears to have failed.\n\n";
			exit -7;
		}
	}
	return ($file);
}

# Install dependent packages.
sub install_dep_packages
{
	my ($conf, $pass)=@_;
	
	print "Now installing Packages to satisfy dependencies.\n";
	get_installed($conf);
	
	# Sort out already installed groups.
	my $install_string="";
	foreach my $package (@{$conf->{files}{yum_depend_pkg}})
	{
		my $match=0;
		foreach my $installed_package (@{$conf->{installed}{packages}})
		{
			# I want to make sure that the arch suffix doesn't
			# cause a missed match.
			$match = 1 if lc($installed_package) eq lc($package);
# 			print " - Package: [$package] already installed, skipping.\n" if $match;
			last if $match;
		}
		if (not $match)
		{
			$install_string.=" $package";
			print " - Queued:  [$package]\n";
		}
		$match=0;
	}
	if (not $install_string)
	{
		print " - All packages are installed, returning.\n";
		return 0;
	}
	elsif ($pass == 2)
	{
		# This was the second pass, and should have found no packages
		# to install. Seeing as I found one, something went wrong.
		print "[ERROR]\n";
		print "It would seem that one or more packages failed to install on the first pass. As\n";
		print "such, I can not guarantee that all the packages that will be needed are";
		print "installed. Please check your Internet connection and try again.\n\n";
		print "Exiting\n";
		exit -6;
	}
	
	my $yum=IO::Handle->new();
	$install_string=~s/^s+//;
	my $shell_call="$conf->{path}{yum} $conf->{args}{yum_install_pkg} $install_string 2>&1 |";
# 	print "Calling: [$shell_call]\n";
	print "WARNING: This will look like it has hung during the download, please be\n";
	print "         patient! Use 'top' from another terminal to confirm that all is ok.\n";
	sleep 2;
	open ($yum, $shell_call) || die "Failed to call: [$shell_call]\n";
	print "/--------------------\n";
	while (<$yum>)
	{
		print "| ".$_;
	}
	print "\\--------------------\n";
	$yum->close();
	
	# Check that it worked.
	### TODO Some package names don't match from 'yum list installed' and the entry in the array.
}

# Install dependent groups.
sub install_dep_groups
{
	my ($conf, $pass)=@_;
	
	print "Now installing Package Groups to satisfy dependencies.\n";
	get_installed($conf);
	
	# Sort out already installed groups.
	my $install_string="";
	foreach my $group (@{$conf->{files}{yum_depend_grp}})
	{
		my $match=0;
		foreach my $installed_group (@{$conf->{installed}{groups}})
		{
			$match=1 if lc($installed_group) eq lc($group);
# 			print " - Group:  [$installed_group] already installed, skipping.\n" if $match;
			last if $match;
		}
		if (not $match)
		{
			$install_string.=" \"$group\"";
			print " - Queued: [$group]\n";
		}
		$match=0;
	}
	if (not $install_string)
	{
		print " - All package groups are installed, returning.\n";
		return;
	}
	elsif ($pass == 2)
	{
		# This was the second pass, and should have found no packages
		# to install. Seeing as I found one, something went wrong.
		if ( $install_string eq " \"System administration tools\"" )
		{
			print "\nWARNING! It *looks* like the package group 'System administration tools' did\n";
			print "         not install. However, this is the only group reported to still be\n";
			print "         missing so this may be a bug (see below). As such, the install will\n";
			print "         proceed, but it might fail. Proceeding in ten seconds.\n\n";
			print "         Please see:\n";
			print "         - https://bugzilla.redhat.com/show_bug.cgi?id=655281\n\n";
			sleep 10;
		}
		else
		{
			print "[ERROR]\n";
			print "It would seem that one or more package groups failed to install on the first\n";
			print "pass. As such, I can not guarantee that all the package groups that will be\n";
			print "needed are installed. Please check your Internet connection and try again.\n\n";
			print "Exiting\n";
			exit -5;
		}
	}
	
	my $yum=IO::Handle->new();
	$install_string=~s/^s+//;
	my $shell_call="$conf->{path}{yum} $conf->{args}{yum_install_grp} $install_string 2>&1 |";
# 	print "Calling: [$shell_call]\n";
	print "WARNING: This will look like it has hung during the download, please be\n";
	print "         patient! Use 'top' from another terminal to confirm that all is ok.\n";
	sleep 2;
	open ($yum, $shell_call) || die "Failed to call: [$shell_call]\n";
	print "/--------------------\n";
	while (<$yum>)
	{
		print "| ".$_;
	}
	print "\\--------------------\n";
	$yum->close();
	
	# Check that it worked.
	### TODO when https://bugzilla.redhat.com/show_bug.cgi?id=655281 is fixed.
}

# Ask the user to confirm the install.
sub confirm
{
	my ($conf)=@_;
	
print q|
This will now create and install the Xen 4.0.1 hypervisor, 2.6.32-25 based dom0
kernel. This installer is based on Pasi Kärkkäinen's tutorial available at:

- http://wiki.xen.org/xenwiki/RHEL6Xen4Tutorial

Depending on your Internet connection speed and processing power, this
installer could take quite a long time to complete. Buffering is disabled so
you should see a relatively steady stream of output. Be prepared to leave this
program running for an hour or two.

Before proceeding, make sure that:
 - You have a working Internet connection.
 - That all network interfaces are set to 'NM_CONTROLLED="no"
   - /etc/sysconfig/network-scripts/ifcfg-eth*
 - Make sure that the 'NetworkManager' service is disabled and that 'network'
   is enabled.
 - Make sure that your hostname is in '/etc/hosts'
 - If you run into trouble, try disabling SELinux.

This is potentially risky, so please do not run this until you have thuroughly
tested this on a test installation.

|;
	
	if ($conf->{confirm})
	{
		print "Are you sure you wish to proceed? [y/N] ";
		my $proceed = <>;
		chomp($proceed);
		if (lc($proceed) eq "y")
		{
			print "\nProceeding.\n\n"; 
		}
		else
		{
			print "\nExiting.\n";
			exit 1;
		}
	}
}

# Make sure this is running as 'root'.
sub is_root
{
	my ($conf)=@_;
	if ( $< != 0 )
	{
		# Exit, not running as root.
		print "[ERROR]\nI am sorry, but you must run this with 'root' user access.\n";
		exit -1;
	}
}

# Make sure that the 'RHEL Server Optional' repository is available.
sub check_repo
{
	my ($conf)=@_;
	
	print "Checking that the 'RHEL Server Optional' repository is available.\n";
	my $check_repo=IO::Handle->new();
	my $shell_call="$conf->{path}{yum} $conf->{args}{yum_repo} 2>&1 |";
	open ($check_repo, $shell_call) || die "Failed to call: [$shell_call]\n";
	my $opt_repo_found=0;
	while (<$check_repo>)
	{
		$opt_repo_found = /$conf->{string}{opt_repo}/ ?  1 : 0;
		last if $opt_repo_found;
	}
	$check_repo->close();
	
	# Exit if I didn't find it.
	if (not $opt_repo_found)
	{
		print "[ERROR]\n";
		print "It doesn't look like the 'RHEL Server Optional' repository has been enabled\n";
		print "for this server. Please log in to Red Hat Network, https://rhn.redhat.com,\n";
		print "browse to 'Subscription Management' and click on the entry for server: \n\n";
		print "- $ENV{HOSTNAME}\n\n";
		print "Then click on 'Alter Channel Subscriptions', locate and then click to select\n";
		print "the 'RHEL Server Optional (v. 6 <arch>)' repository. Scroll down and then click\n";
		print "on the 'Change Subscription' button. Once done, please re-run this installer.\n\n";
		print "If it is enabled, make sure that your Internet connection is working.\n\n";
		print "Exiting.\n";
		exit -2;
	}
	print " - Found!\n";
}

# This gets a list of installed groups and packages.
sub get_installed
{
	my ($conf)=@_;
	
	# Clear the arrays.
	$conf->{installed}{groups}=[];
	$conf->{installed}{packages}=[];
	
	# Groups
	print "Getting a list of installed package groups:\n";
	my $yum=IO::Handle->new();
	my $shell_call="$conf->{path}{yum} $conf->{args}{yum_installed_g} 2>&1 |";
	open ($yum, $shell_call) || die "Failed to call: [$shell_call]\n";
	my $record=0;
	while (<$yum>)
	{
		my $line=$_;
		chomp($line);
		if (not $record)
		{
			$record=1 if $line =~/$conf->{string}{grp_list_begin}/;
		}
		else
		{
			last if $line =~/$conf->{string}{grp_list_end}/;
			$line=~s/^\s+//g;
			$line=~s/\s+$//g;
			push @{$conf->{installed}{groups}}, $line;
		}
	}
	$yum->close();
	if (@{$conf->{installed}{groups}} > 1)
	{
		print " - Done, found: [".@{$conf->{installed}{groups}}."] groups.\n";
	}
	else
	{
		print "[ERROR]\n";
		print "Failed to read and installed groups.\n";
		print "There may be an Internet connection problem.\n\n";
		print "Exiting.\n\n";
		die -3;
	}
	
	# Packages
	print "Getting a list of installed packages:\n";
	$yum=IO::Handle->new();
	$shell_call="$conf->{path}{yum} $conf->{args}{yum_installed_p} 2>&1 |";
	open ($yum, $shell_call) || die "Failed to call: [$shell_call]\n";
	$record=0;
	while (<$yum>)
	{
		my $line=$_;
		chomp($line);
		if (not $record)
		{
			$record=$line =~/$conf->{string}{pkg_list_begin}/ ? 1 : 0;
		}
		else
		{
			$line=~s/^\s+//g;
			$line=~s/\s.*$//;
			push @{$conf->{installed}{packages}}, $line;
		}
	}
	$yum->close();
	if (@{$conf->{installed}{packages}} > 1)
	{
		print " - Done, found: [".@{$conf->{installed}{packages}}."] packages.\n";
	}
	else
	{
		print "[ERROR]\n";
		print "Failed to read and installed packages.\n";
		print "There may be an Internet connection problem.\n\n";
		print "Exiting.\n\n";
		die -4;
	}
}
