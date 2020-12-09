# archlinux/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# $pkgmgr_install $pkgs_cmdln_tools 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_fetch='pacman --noconfirm --needed -Sw'
pkgmgr_install='pacman --noconfirm --needed -S'
pkgmgr_search='pacman -Ss'
pkgmgr_update='pacman --noconfirm -Syy'

pkg_repos_sources() {
	sep='#--------------------#'
	argX='grep -ve "^#" -ve "^\s*$" /etc/pacman.conf ; head -n10 /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist-arch'

	#printf "${sep}\n$argX\n" | cat - $argX
	printf "${sep}\n$argX\n" ; eval `echo $argX`
}

pkgs_installed() {
	METHOD=${1:-explicit}

	sleep 3 ; pacman --noconfirm -Syyq

	#echo '### for pkg message: see /var/log/pacman.log ###'
	if [ "leaf" = "$METHOD" ] ; then
		pkg_nms=$(pacman -Qqt) ;
		(for pkg_nm in $pkg_nms ; do
			pkg_grp=$(pacman -Qi $pkg_nm | grep -e Groups | tr -s ' ' '\t' | cut -f 3 ) ;
			pkg_repo=$(pacman -Si $pkg_nm | grep -e Repository | tr -s ' ' '\t' | cut -f 3 ) ;
			echo "($pkg_repo) $pkg_grp/$pkg_nm" ;
		done) | sort | column ;
	else
	  echo "=== Display package holds ===" ;
	  echo "grep -e '^IgnorePkg' /etc/pacman.conf" ;
	  grep -e '^IgnorePkg' /etc/pacman.conf ;
	  echo "=============================" ;

		# -Qqe for explicitly installed; -Qqd for dependencies
		pkg_nms=$(pacman -Qqe) ;
		(for pkg_nm in $pkg_nms ; do
			pkg_grp=$(pacman -Qi $pkg_nm | grep -e Groups | tr -s ' ' '\t' | cut -f 3 ) ;
			pkg_repo=$(pacman -Si $pkg_nm | grep -e Repository | tr -s ' ' '\t' | cut -f 3 ) ;
			echo "($pkg_repo) $pkg_grp/$pkg_nm" ;
		done) | sort | column ;
	fi
}
