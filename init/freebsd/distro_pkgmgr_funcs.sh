# freebsd/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# ${pkgmgr_install} ${pkgs_cmdln_tools} 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_fetch='pkg fetch -dy'
pkgmgr_install='pkg install -y'
pkgmgr_search='pkg search --regex'
pkgmgr_update='pkg update'

pkg_repos_sources() {
	sep='#--------------------#'
	#argX='pkg -vv | grep -A99 -e "Repositories:"'
	argX='pkg -vv | sed -n "/Repositories:/,/}/p"'

	#printf "${sep}\n${argX}\n" | cat - ${argX}
	printf "${sep}\n${argX}\n" ; ${argX}
}

pkgs_installed() {
	METHOD=${1:-explicit}

	#echo '### for pkg-message: pkg query "%o\n%M" ${pkg_nm} ###'
	pkg update -q
	if [ "leaf" = "${METHOD}" ] ; then
		# '%#r = 0' for no reverse depns; '%#r > 0' for reverse depns
		pkg query -e '%#r=0' %o ;
	else
	  echo "=== Display package holds ===" ;
	  echo "pkg lock -lq" ; pkg lock -lq ;
	  echo "=============================" ;

		# '%a = 0' for explicitly installed; '%a = 1' for dependencies
		pkg query -e '%a=0' %o ;
	fi
}
