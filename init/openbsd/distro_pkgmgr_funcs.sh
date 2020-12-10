# openbsd/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# $pkgmgr_install $pkgs_cmdln_tools 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_fetch='pkg_add -n'
pkgmgr_install='pkg_add'
pkgmgr_search='pkg_info'
pkgmgr_update='pkg_add -u'

pkg_repos_sources() {
	sep='#--------------------#'
	argX='/etc/installurl'

	printf "${sep}\n$argX\n" | cat - $argX
	#printf "${sep}\n$argX\n" ; $argX
}

pkgs_installed() {
	METHOD=${1:-explicit}

	#echo '### for pkg-message: pkg_info -M $pkg_nm ###'
	if [ "leaf" = "$METHOD" ] ; then
		# 'pkg_info -tq' for no reverse depns; 'pkg_info -R' for reverse depns
		pkg_info -tq ;
	else
		# 'pkg_info -mq' for explicitly installed
		pkg_info -mq ;
	fi
}
