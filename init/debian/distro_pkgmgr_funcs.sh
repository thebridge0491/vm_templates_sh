# debian/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# ${pkgmgr_install} ${pkgs_cmdln_tools} 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_install='apt-get -y --no-install-recommends install'
pkgmgr_search='apt-cache search'
pkgmgr_update='apt-get update'

pkg_repos_sources() {
	sep='#--------------------#'
	argX='grep -ve "^#" /etc/apt/sources.list'

	#printf "${sep}\n${argX}\n" | cat - ${argX}
	printf "${sep}\n${argX}\n" ; ${argX}
}

pkgs_installed() {
	METHOD=${1:-explicit}

	echo -e 'tasksel --list-tasks\n----------'
	apt-get -q update
	tasksel --list-tasks | column ; echo ''
	echo -e 'dpkg -l | grep -Ee "meta[-]*package" | sed -n "s|^\w*\s*\(\S*\)\s*.*|\1|p"\n----------'
	dpkg -l | grep -Ee "meta[-]*package" | sed -n 's|^\w*\s*\(\S*\)\s*.*|\1|p' | column ; echo '' ; sleep 3

	#echo '### for pkg message: see /var/log/[dpkg.log | apt/history.log] ###'
	if [ "leaf" = "${METHOD}" ] ; then
		pkg_nms=$(dpkg-query --show -f='${binary:Package} ') ;
		(for pkg_nm in ${pkg_nms} ; do
			rdepns_info=$(apt-cache rdepends --installed ${pkg_nm}) ;
			no_rdepns=$(echo -n ${rdepns_info} | sed '/Reverse Depends:/ s|.*: \(.*\)|\1|') ;
			if [ -z "${no_rdepns}" ] ; then continue ; fi ;

			pkg_pool=$(apt-cache show ${pkg_nm} | sed -n 's|Filename: pool\/\(\w*\)\/.*|\1|p' | head -n 1) ;
			if [ "updates" = "${pkg_pool}" ] ; then
				pkg_pool=$(apt-cache show ${pkg_nm} | sed -n 's|Filename: pool\/updates\/\(\w*\)\/.*|\1|p' | head -n 1) ;
			fi ;
			if [ "" = "${pkg_pool}" ] ; then pkg_pool="BLANK" ; fi ;

			echo "(${pkg_pool})" $(dpkg-query --show -f='${Section}/${Package}\n' ${pkg_nm}) ;
		done) | sort | column ;
	else
	  echo "=== Display package holds ===" ;
	  echo "apt-mark showhold" ; apt-mark showhold ; #dpkg -l | grep "^hi" ;
	  echo "=============================" ;

		# '~i !~M' for explicitly installed; '~i ~M' for dependencies
		#pkg_nms=$(aptitude search '~i !~M' | tr -s ' ' '\t' | cut -f 2)
		# showmanual for explicitly installed; showauto for dependencies
		pkg_nms=$(apt-mark showmanual) ;
		(for pkg_nm in ${pkg_nms} ; do
			sect_pkg=$(dpkg-query --show --showformat='${Section}/${Package}\n' ${pkg_nm}) ;
			pkg_pool=$(apt-cache show ${pkg_nm} | sed -n 's|Filename: pool\/\(\w*\)\/.*|\1|p' | head -n 1) ;
			if [ "updates" = "${pkg_pool}" ] ; then
				pkg_pool=$(apt-cache show ${pkg_nm} | sed -n 's|Filename: pool\/updates\/\(\w*\)\/.*|\1|p' | head -n 1) ;
			fi ;
			if [ "" = "${pkg_pool}" ] ; then pkg_pool="BLANK" ; fi ;
			echo "(${pkg_pool}) ${sect_pkg}" ;
		done) | sort | column ;
	fi
}
