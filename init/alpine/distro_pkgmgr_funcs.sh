# alpine/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# ${pkgmgr_install} ${pkgs_cmdln_tools} 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_install='apk add'
pkgmgr_search='apk search'
pkgmgr_update='apk update'

pkg_repos_sources() {
	sep='#--------------------#'
	argX='/etc/apk/repositories'

	printf "${sep}\n${argX}\n" | cat - ${argX}
	#printf "${sep}\n${argX}\n" ; ${argX}
}

pkgs_installed() {
	METHOD=${1:-explicit}

	sleep 3 ; apk update -q

	#echo "=== Display package holds ===" ;
	## ?? how to display held/pinned packages ??
	#echo "=============================" ;

	# apk info for installed # -qr for reverse depns
	pkg_nms=$(apk info)
	(for pkg_nm in ${pkg_nms} ; do
		if [ -z "$(apk info -qr ${pkg_nm})" ] ; then
			echo ${pkg_nm} ;
		fi
	done) | sort | column
}
