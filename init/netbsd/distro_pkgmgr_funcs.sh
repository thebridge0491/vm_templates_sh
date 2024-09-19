# netbsd/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# ${pkgmgr_install} ${pkgs_cmdln_tools} 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_fetch='pkgin -d install'
pkgmgr_install='pkgin install'
pkgmgr_search='pkgin search'
pkgmgr_update='pkgin update'

pkg_repos_sources() {
	sep='#--------------------#'
	argX='/etc/pkg_install.conf'

	printf "${sep}\n${argX}\n" | cat - ${argX}
	#printf "${sep}\n${argX}\n" ; ${argX}

	argY='/usr/pkg/etc/pkgin/repositories.conf'
	printf "${sep}\n${argY}\n" | cat - ${argY}
}

pkgs_installed() {
	METHOD=${1:-explicit}

	sleep 3 ; pkgin update > /dev/null

	#echo '### for pkg-message: pkg_info -D ${pkg_nm} ###'
	if [ "leaf" = "${METHOD}" ] ; then
		# -? for no reverse depns; -R for reverse depns
		pkg_nms=$(pkgin list | cut -d' ' -f1) ;
		(for pkg_nm in ${pkg_nms} ; do
			if [ -z "$(pkg_info -Rq ${pkg_nm})" ] ; then
				echo ${pkg_nm} ;
			fi
		done) | column ;
	else
		# -u for user installed; -n for dependencies
		pkg_info -u | cut -d' ' -f1 | column ;
	fi
}
