# void/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# $pkgmgr_install $pkgs_cmdln_tools 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_install='xbps-install'
pkgmgr_search='xbps-query -Rs'
pkgmgr_update='xbps-install -S'

pkg_repos_sources() {
	sep='#--------------------#'
	argX='xbps-query -L'

	#printf "${sep}\n$argX\n" | cat - $argX
	printf "${sep}\n$argX\n" ; $argX
}

pkgs_installed() {
	METHOD=${1:-explicit}

	sleep 3 ; xbps-install -S > /dev/null

	if [ "leaf" = "$METHOD" ] ; then
		# -l for installed packages # -X for reverse depns
		pkg_nms=$(xbps-query -l | cut -d' ' -f2) ;
		(for pkg_nm in $pkg_nms ; do
			if [ -z "$(xbps-query -X $pkg_nm | tr '\n' ' ')" ] ; then
				echo $pkg_nm ;
			fi
		done) | sort | column ;
	else
	  echo "=== Display package holds ===" ;
	  echo "xbps-query --list-hold-pkgs" ; xbps-query --list-hold-pkgs ;
	  echo "=============================" ;

		# -m for explicitly installed
		xbps-query -m | sort | column ;
	fi
}
