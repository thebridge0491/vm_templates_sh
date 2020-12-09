# suse/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# $pkgmgr_install $pkgs_cmdln_tools 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_install='zypper --non-interactive --no-recommends install'
pkgmgr_search='zypper search'
pkgmgr_update='zypper --non-interactive refresh'

pkg_repos_sources() {
	sep='#--------------------#'
	argX='zypper --no-refresh repos -u'

	#printf "${sep}\n$argX\n" | cat - $argX
	printf "${sep}\n$argX\n" ; $argX
}

pkgs_installed() {
	METHOD=${1:-explicit}

	echo 'zypper --no-refresh search --installed-only --type pattern'
	zypper --non-interactive -q refresh
	echo '----------' ; zypper --no-refresh search -i -t pattern ; echo ''

	if [ "leaf" = "$METHOD" ] ; then
		pkg_nms=$(zypper --no-refresh search --installed-only | grep ^i | cut -d'|' -f2) ;
		(for pkg_nm in $pkg_nms ; do
			no_rdepns=$(rpm -q --whatrequires $pkg_nm | grep -e 'no package requires') ;
			if [ ! -z "$no_rdepns" ] ; then continue ; fi ;

			pkg_repo=$(zypper --no-refresh info $pkg_nm | grep -e Repository | cut -d: -f2 | tr -d ' ') ;

			echo "($pkg_repo)" $(rpm -q --queryformat '%{group}/%{name} \n' $pkg_nm) ;
		done) | sort | column ;
	else
	  echo "=== Display package holds ===" ;
	  echo "zypper locks" ; zypper locks ;
	  echo "=============================" ;

		pkg_nms=$(sudo awk -F\| '$6 && $2 == "install" {print $3}' /var/log/zypp/history | sort | uniq) ;
		(for pkg_nm in $pkg_nms ; do
			pkg_grp=$(rpm -qi $pkg_nm | grep -e Group | cut -d: -f2 | tr -d ' ') ;
			pkg_repo=$(zypper --no-refresh info $pkg_nm | grep -e Repository | cut -d: -f2 | tr -d ' ') ;
			echo "($pkg_repo) $pkg_grp/$pkg_nm" ;
		done) | sort | column ;
	fi
}
