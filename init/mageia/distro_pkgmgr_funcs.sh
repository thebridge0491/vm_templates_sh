# mageia/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# ${pkgmgr_install} ${pkgs_cmdln_tools} 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

#pkgmgr_install='urpmi --no-recommends'
#pkgmgr_search='urpmq'
#pkgmgr_update='urpmi.update -a'
pkgmgr_install='dnf -C --setopt=install_weak_deps=False -y install'
pkgmgr_search='dnf -C search'
pkgmgr_update='dnf -y check-update'

pkg_repos_sources() {
	sep='#--------------------#'
	#argX='urpmq --list-media active'
	argX='dnf -C repolist -v enabled | grep -e "Repo-id" -e "Repo-name" -e "Repo-mirrors" -e "Repo-baseurl"'

	#printf "${sep}\n${argX}\n" | cat - ${argX}
	printf "${sep}\n${argX}\n" ; eval `echo ${argX}`
}

pkgs_installed_urpmi() {
	METHOD=${1:-explicit}

	sleep 3 ; urpmi.update -a > /dev/null

	if [ "leaf" = "${METHOD}" ] ; then
		pkg_nms=$(rpm -qa --queryformat '%{name} \n')
		(for pkg_nm in ${pkg_nms} ; do
			no_rdepns=$(rpm -q --whatrequires ${pkg_nm} | grep -e 'no package requires') ;
			if [ ! -z "${no_rdepns}" ] ; then continue ; fi ;

			rpm -q --queryformat '%{group}/%{name} \n' ${pkg_nm} ;
		done) | sort | column ;
	else
		pkg_nms=$(urpmi_rpm-find-leaves) ;
		(for pkg_nm in ${pkg_nms} ; do
			#pkg_grp=$(urpmq -i ${pkg_nm} | grep -e Group | head -n 1 | cut -d: -f2) ;
			pkg_grp=$(rpm -qi ${pkg_nm} | grep -e Group | cut -d: -f2 | tr -d ' ') ;
			echo "${pkg_grp}/${pkg_nm}" ;
		done) | sort | column ;
	fi
}

pkgs_installed() {
	METHOD=${1:-explicit}

	echo -e "dnf -C group list installed hidden\n----------"
	dnf -yq check-update
	dnf -C group list installed hidden ; echo '' ; sleep 3

	if [ "leaf" = "${METHOD}" ] ; then
		#pkg_nms=$(repoquery -C --installed) ;
		pkg_nms=$(dnf -C repoquery --queryformat '%{name}' --installed) ;
		(for pkg_nm in ${pkg_nms} ; do
			no_rdepns=$(rpm -q --whatrequires ${pkg_nm} | grep -e 'no package requires') ;
			if [ ! -z "${no_rdepns}" ] ; then continue ; fi ;

			pkg_repo=$(dnf -C repoquery --queryformat '%{reponame}' ${pkg_nm}) ;

			echo "(${pkg_repo})" $(rpm -q --queryformat '%{group}/%{name} \n' ${pkg_nm}) ;
		done) | sort | column ;
	else
	  echo "=== Display package holds ===" ;
	  echo "dnf -C versionlock list" ; dnf -C versionlock list ;
	  echo "=============================" ;

		# user for explicitly installed ; dep for dependencies
		pkgnms_ver=$(dnf -C history userinstalled | tail -n +2 | grep -e '^\S' | tr -s '\n' ' ') ;
		(for pkgnm_ver in ${pkgnms_ver} ; do
			pkg_nm=$(dnf -C info ${pkgnm_ver} | grep -e Name | cut -d: -f2 | tr -d ' ') ;
			pkg_grp=$(rpm -qi ${pkg_nm} | grep -e Group | cut -d: -f2 | tr -d ' ') ;
			pkg_repo=$(dnf -C repoquery --queryformat '%{reponame}' ${pkg_nm}) ;
			echo "(${pkg_repo}) ${pkg_grp}/${pkg_nm}" ;
		done) | sort | column ;
	fi
}
