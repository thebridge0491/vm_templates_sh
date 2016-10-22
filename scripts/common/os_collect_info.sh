#!/bin/sh

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su [-m root] -c 'sh -xs - arg1 argN'" < script.sh

OS_NAME=$(uname -s) ; sep='#--------------------#'

#[aria2c --check-certificate=false | fetch --no-verify-peer | ftp -S dont | \
#  wget -N --no-check-certificate | curl -kOL]
#aria2c --check-certificate=false <url_prefix>/script.sh

#===========================================================================#
concat_sep() {
	if [ -f "$@" ] ; then
		printf "${sep}\n$@\n" | cat - $@ ;
	else
		printf "${sep}\n$@\n" ;
		$@ ;
	fi
}

concat_sep_head1() {
	if [ -f "$@" ] ; then
		printf "${sep}\n$@ | head -n 1\n" | cat - $@ | head -n 2 ;
	else
		printf "${sep}\n$@ | head -n 1\t" ;
		$@ | head -n 1 ;
	fi
}

lang_devel_versions() {
    echo "lang_devel_versions" ; echo -e "\nlang_c\n"
    for cmd in 'gcc --version' 'clang --version' 'cmake --version' \
    		'automake --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
    echo -e "$sep\n(gmake --version || make --version)\t$(gmake --version | head -n 1 || make --version | head -n 1)"
    echo -e "$sep\n(swig3.0 -version || swig2.0 -version || swig -version)\n"
    for cmd in 'swig3.0' 'swig2.0' 'swig' ; do
        echo -e "$($cmd -version | head -n 2)" ;
    done
    for cmd in 'gfortran --version' 'go version' 'gopm --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
    echo -e "\nlang_rust\n"
    for cmd in 'rustc --version' 'cargo --version' 'swiftc -version' ; do
    	concat_sep_head1 "$cmd" ;
    done
    echo -e "$sep\nscalac -version\t$(scalac -version 2>&1 | head -n 1)"
	echo -e "\nlang_oo_c\n"
	for cmd in 'g++ --version' 'clang++ --version' 'msc -version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	#nuget ; #monodevelop
    echo -e "$sep\njavac -version\t$(javac -version 2>&1 | head -n 1)"
    echo -e "$sep\ngradle --version\n$(gradle --version | head -n 3)"
	for cmd in 'sbt version' 'ant -version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	#netbeans ; #eclipse
	concat_sep_head1 'valac --version'
	echo -e "\nlang_lisp\n"
	concat_sep_head1 "clojure -e '(println (str \"Clojure \" (clojure-version)))'"
	#leiningen
	concat_sep_head1 'sbcl -version' #; #quicklisp
	concat_sep_head1 'gosh -V'
	echo -e "\nlang_ml\n"
	for cmd in 'fsharpc --help' 'ghc --version' 'stack --version' \
			'ocamlbuild -version' 'opam --version' 'oasis version' 'sml -h' ; do
    	concat_sep_head1 "$cmd" ;
    done
	echo -e "\nlang_scripting\n"
    echo -e "$sep\n(node --version || nodejs --version) 2>/dev/null\n$($(node --version || nodejs --version) 2>/dev/null)"
	for cmd in 'npm --version' 'php --version' 'pear -V' 'pecl -V' 'composer -V' ; do
    	concat_sep_head1 "$cmd" ;
    done
    echo -e "$sep\n(python2 --version || python --version)\t$(python2 --version 2>&1 || python --version 2>&1)"
    echo -e "$sep\n(pip2 --version || pip --version)\t$(pip2 --version 2>&1 || pip --version 2>&1)"
	echo -e "$sep\n(pip2 list --local | grep -e setuptools -e invoke || pip list --local | grep -e setuptools -e invoke)\n$(pip2 list --local | grep -e setuptools -e invoke || pip list --local | grep -e setuptools -e invoke)"
	echo -e "$sep\n(jython --version | head -n 2)\t$(jython --version 2>&1 | head -n 2)"
	for cmd in 'ruby --version' 'rake --version' 'gem --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	echo -e "$sep\n(gem list --local | grep -e hoe)\t$(gem list --local | grep -e hoe)"
	for cmd in 'jruby --version' 'lua -v' 'luarocks --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	echo -e "$sep\n(perl -v | head -n 2)\t$(perl -v | head -n 2)"
	for cmd in 'cpanm --version' 'groovy --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	echo -e "\n========================================"
}

bsd_info() {
	sudo cp /root/distro_pkgs.txt /tmp/ ; . /tmp/distro_pkgs.txt
	msgfile='msg5.txt' ; echo "($OS_NAME)" 'explicit_pkgs' >> $msgfile
	pkgs_installed explicit >> $msgfile
	msgfile='msg4.txt' ; echo "($OS_NAME)" 'leaf_pkgs' >> $msgfile
	pkgs_installed leaf >> $msgfile
	msgfile='msg3.txt' ; echo "($OS_NAME)" 'lang_devel_versions' > $msgfile
	lang_devel_versions >> $msgfile
	msgfile='msg2.txt' ; echo "($OS_NAME)" 'desktop applications' > $msgfile
	ls /usr/local/share/applications | column >> $msgfile
	
	msgfile='msg1.txt' ; echo "($OS_NAME)" 'collect_info' > $msgfile
	concat_sep 'uname -a' >> $msgfile
	concat_sep 'freebsd-version' >> $msgfile
    
    echo -e "$sep\ngrep sshd_enable /etc/rc.conf\n$(grep sshd_enable /etc/rc.conf)" >> $msgfile
    concat_sep 'sudo grep NOPASSWD `find /etc /usr/local/etc /usr/pkg/etc -type f -name sudoers 2>/dev/null`' >> $msgfile
	
	configs=$(find -L /boot /etc -type f -maxdepth 1 -name 'rc.conf*' -o -name 'loader.conf*')
	for conf in $configs ; do
		concat_sep $conf >> $msgfile ;
	done
	concat_sep 'kldstat' | column >> $msgfile
	concat_sep 'modstat' | column >> $msgfile
	concat_sep 'service -e' | column >> $msgfile
	concat_sep 'rcctl ls on' | column >> $msgfile
    
    concat_sep 'date' >> $msgfile
    concat_sep 'locale' >> $msgfile
    echo $sep >> $msgfile
    echo -e "ifconfig | grep -Ee '^[[:alnum:]]*:.*> metric .*' | sed 's|^\(.*>\).*|\1|':\n$(ifconfig | grep -Ee '^[[:alnum:]]*:.*> metric .*' | sed 's|^\(.*>\).*|\1|')" >> $msgfile ;
    ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
    echo $sep >> $msgfile
    echo -e "ip addr(s): ifconfig $ifdev | grep -e inet | cut -d' ' -f1-2\n$(ifconfig $ifdev | grep -e inet | cut -d' ' -f1-2)" >> $msgfile
    echo $sep >> $msgfile
    echo "hostname -s: $(hostname -s) ; domainname: $(domainname)" >> $msgfile
    for file in /etc/hostname /etc/myname /etc/hosts /etc/resolv.conf ; do
    	concat_sep $file >> $msgfile ;
    done
    concat_sep 'sysctl -a | grep -e kern.hostuuid -e hw.uuid' >> $msgfile
    pkg_repos_sources >> $msgfile
    
    concat_sep 'sudo fdisk sd0' >> $msgfile
    concat_sep 'sudo disklabel -hp m sd0' >> $msgfile
    concat_sep 'gpt show -l sd0' >> $msgfile
    concat_sep 'gpart show -l' >> $msgfile
	for g_type in label eli ; do
		concat_sep "geom $g_type status -as" >> $msgfile ;
	done
	printf "${sep}\nZFS info\n" >> $msgfile
	concat_sep 'zpool list -v' >> $msgfile
	concat_sep 'zfs list' >> $msgfile
    
	concat_sep /etc/fstab >> $msgfile
	concat_sep 'df -hT -c' >> $msgfile
	concat_sep 'df -h' >> $msgfile
	concat_sep 'sudo du -hd 1 / 2>/dev/null' | column -xc 78 >> $msgfile
    
	concat_sep 'ls -lh /home' >> $msgfile
	concat_sep "ls -lh /home/$(id -un)" >> $msgfile
	concat_sep 'id' >> $msgfile
    
    echo -e "$sep\nTERM: $TERM ; SHELL: $SHELL ; LANG: $LANG" >> $msgfile
    echo -e "$sep\nPATH: $PATH" >> $msgfile
    concat_sep 'lpstat -s' >> $msgfile
    concat_sep 'lpc status' >> $msgfile
    echo $sep >> $msgfile
    echo "/home/$(id -un)/[.xsession|.xinitrc]" >> $msgfile
    if [ -e "/home/$(id -un)/.xsession" ] ; then
        concat_sep "/home/$(id -un)/.xsession" >> $msgfile ;
    elif [ -e "/home/$(id -un)/.xinitrc" ] ; then
        concat_sep "/home/$(id -un)/.xinitrc" >> $msgfile ;
    else
        echo $sep >> $msgfile ;
    fi
}

linux_info() {
	#distro_nm=$(lsb_release -i)
	distro_nm=$(grep -e '^NAME' /etc/os-release)
	sudo cp /root/distro_pkgs.txt /tmp/ ; . /tmp/distro_pkgs.txt
	msgfile='msg5.txt' ; echo "($distro_nm)" 'explicit_pkgs' >> $msgfile
	pkgs_installed explicit >> $msgfile
	msgfile='msg4.txt' ; echo "($distro_nm)" 'leaf_pkgs' >> $msgfile
	pkgs_installed leaf >> $msgfile
	msgfile='msg3.txt' ; echo "($distro_nm)" 'lang_devel_versions' > $msgfile
	lang_devel_versions >> $msgfile
	msgfile='msg2.txt' ; echo "($distro_nm)" 'desktop applications' > $msgfile
	ls /usr/share/applications | column >> $msgfile
	
	msgfile='msg1.txt' ; echo "($distro_nm)" 'collect_info' > $msgfile
    concat_sep 'uname -a' >> $msgfile
    concat_sep 'lsb_release -a' >> $msgfile
    concat_sep '/proc/version' >> $msgfile
    concat_sep '/etc/os-release' >> $msgfile
    
    #echo -e "$sep\nsudo find /boot/{efi,EFI} -iname '*.efi'\n$(sudo find /boot/{efi,EFI} -iname '*.efi')" >> $msgfile
    echo -e "$sep\nsudo find / -ipath /boot/efi/*/*.efi\n$(sudo find / -ipath /boot/efi/*/*.efi)" >> $msgfile
    concat_sep 'sudo service --status-all' >> $msgfile
    concat_sep 'sudo grep NOPASSWD /etc/sudoers' >> $msgfile
    
    concat_sep 'sudo hwclock -r' >> $msgfile
	concat_sep 'locale' >> $msgfile
    echo $sep >> $msgfile
    echo -e "sudo ip -o link show | sed 's|^\([[:digit:]]*:.*>\).*|\1|':\n$(sudo ip -o link show | sed 's|^\([[:digit:]]*:.*>\).*|\1|')" >> $msgfile ;
    ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')
    echo $sep >> $msgfile
    echo -e "sudo ip addr(s): ip addr show $ifdev | sed -n '/inet/ s|.*\(inet\S*\s*\S*\).*|\1|p'\n$(sudo ip addr show $ifdev | sed -n '/inet/ s|.*\(inet\S*\s*\S*\).*|\1|p')" >> $msgfile
    echo $sep >> $msgfile
    echo "hostname -f: $(hostname -f) ; domainname: $(domainname)" >> $msgfile
    for file in /etc/hostname /etc/hosts /etc/network/interfaces /etc/resolv.conf ; do
		concat_sep "$file" >> $msgfile ;
	done
	concat_sep 'ls -l /etc/machine-id /var/lib/dbus/machine-id' >> $msgfile
    pkg_repos_sources >> $msgfile
    hddev=$(lsblk -lnpo name,label,partlabel | grep -e ESP | cut -d' ' -f1)
    if [ "$(sudo which sgdisk)" ] ; then
        echo $sep >> $msgfile ;
        echo -e "sudo sgdisk -V:\n$(sudo sgdisk -V | head -n 1)" >> $msgfile ;
        concat_sep "sudo sgdisk --print $hddev" >> $msgfile ;
    fi
    if [ "$(sudo which sfdisk)" ] ; then
        echo $sep >> $msgfile ;
        echo -e "sudo sfdisk -v:\n$(sudo sfdisk -v | head -n 1)" >> $msgfile ;
        concat_sep "sudo sfdisk --list $hddev" >> $msgfile ;
    fi
    #echo -e "sudo parted -v:\n$(sudo parted -v | head -n 1)" >> $msgfile
	#concat_sep "sudo parted -s $hddev unit GiB print" >> $msgfile
	#concat_sep "sudo partx --verbose --show $hddev" >> $msgfile
    
	concat_sep 'lsblk' >> $msgfile
	echo $sep >> $msgfile
	echo "lsblk -nlpo partlabel" >> $msgfile
	lsblk -nlpo partlabel | column -xc 78 >> $msgfile
	echo $sep >> $msgfile
	echo "lsblk -nlpo label" >> $msgfile
	lsblk -nlpo label | column -xc 78 >> $msgfile
    
	echo -e "\nLVM info\n" >> $msgfile
	concat_sep 'sudo pvs' >> $msgfile
	concat_sep 'sudo vgs' >> $msgfile
	concat_sep 'sudo lvs -o vg_name,lv_name,lv_attr,lv_size' >> $msgfile
	for file in /etc/crypttab /etc/fstab ; do
		concat_sep "sudo cat $file" >> $msgfile ;
	done
	concat_sep 'df -hT --total' >> $msgfile
	echo $sep >> $msgfile
	echo "du -hd 1 /" >> $msgfile
	du -hd 1 / 2>/dev/null | column -xc 78 >> $msgfile
    
	concat_sep 'ls -lh /home' >> $msgfile
	concat_sep "ls -lh /home/$(id -un)" >> $msgfile
	concat_sep 'id' >> $msgfile
    
    echo -e "$sep\nTERM: $TERM ; SHELL: $SHELL ; LANG: $LANG" >> $msgfile
    echo -e "$sep\nPATH: $PATH" >> $msgfile
    concat_sep 'lpstat -s' >> $msgfile
    echo $sep >> $msgfile
    echo "/home/$(id -un)/[.xsession|.xinitrc]" >> $msgfile
    if [ -e "/home/$(id -un)/.xsession" ] ; then
        concat_sep "/home/$(id -un)/.xsession" >> $msgfile ;
    elif [ -e "/home/$(id -un)/.xinitrc" ] ; then
        concat_sep "/home/$(id -un)/.xinitrc" >> $msgfile ;
    else
        echo $sep >> $msgfile ;
    fi
}

macos_info() {
	distro_nm=$(sw_vers -productName)
	msgfile='msg4.txt' ; echo "($distro_nm)" 'leaf_pkgs' > $msgfile
	(concat_sep 'brew leaves' | column ;
	concat_sep 'brew cask list' | column ;
	echo "==================") >> $msgfile
	msgfile='msg3.txt' ; echo "($distro_nm)" 'lang_devel_versions' > $msgfile
	lang_devel_versions >> $msgfile
	msgfile='msg2.txt' ; echo "($distro_nm)" 'desktop applications' > $msgfile
	ls -p /Applications | column >> $msgfile
	
	msgfile='msg1.txt' ; echo "($distro_nm)" 'collect_info' > $msgfile
	concat_sep 'uname -a' >> $msgfile
	concat_sep 'sw_vers' >> $msgfile
	
	concat_sep 'date' >> $msgfile
	echo $sep >> $msgfile
    echo -e "ifconfig | grep -Ee '^[[:alnum:]]*:.*> metric .*' | sed 's|^\(.*>\).*|\1|':\n$(ifconfig | grep -Ee '^[[:alnum:]]*:.*> metric .*' | sed 's|^\(.*>\).*|\1|')" >> $msgfile ;
    ifdev=$(ifconfig | grep '^[a-z]' | cut -d: -f1 | head -n 1)
    echo $sep >> $msgfile
    echo -e "ip addr(s): ifconfig $ifdev | grep -e 'inet ' | cut -d' ' -f1-2\n$(ifconfig $ifdev | grep -e 'inet ' | cut -d' ' -f1-2)" >> $msgfile
    echo $sep >> $msgfile
    echo "hostname: $(hostname) ; domainname: $(domainname)" >> $msgfile
	concat_sep /etc/hosts >> $msgfile
	
	concat_sep 'diskutil coreStorage list' >> $msgfile
	concat_sep 'diskutil list' >> $msgfile
	concat_sep 'df -h' >> $msgfile
	concat_sep 'du -hd 1 / 2>/dev/null' | column -xc 78 >> $msgfile
	
	concat_sep 'ls -lh /Users' >> $msgfile
	concat_sep "ls -lh /Users/$(id -un)" >> $msgfile
	concat_sep 'id' >> $msgfile
    
    echo -e "$sep\nTERM: $TERM ; SHELL: $SHELL ; LANG: $LANG" >> $msgfile
    echo -e "$sep\nPATH: $PATH" >> $msgfile
    concat_sep 'lpstat -s' >> $msgfile
}

collect_info() {
	tarext=${tarext:-} ; tarcmd=${tarcmd:-tar} # ? BSDs more features: gtar
	
	case $OS_NAME in
		'FreeBSD'|'OpenBSD'|'NetBSD') bsd_info ;;
		'Linux') linux_info ;;
		'Darwin') macos_info ;;
		*) echo 'ERROR: OS is not Linux | [Free | Open | Net]BSD | Darwin(MacOS)' ;
			echo '...exiting...' ; exit ;;
	esac
	
	for archive_cmd in "tar" "zip" "7za" ; do
		if [ ! "$(which $archive_cmd)" ] ; then
			continue ;
		fi ;
		case $archive_cmd in
			'tar') ${tarcmd} -caf info.tar${tarext} msg?.txt ;;
			'zip') zip -r info.zip msg?.txt ;;
			'7za') 7za a info.7z msg?.txt ;;
			*) echo 'ERROR: archive cmd is not tar | zip | 7za' ;
				echo '...exiting...' ; exit ;;
		esac ;
	done
}

#===========================================================================#

$@
