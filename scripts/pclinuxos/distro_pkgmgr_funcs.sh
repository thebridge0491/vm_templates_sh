# pclinuxos/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# ${pkgmgr_install} ${pkgs_cmdln_tools} 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

if command -v dnf > /dev/null ; then
  pkgmgr_install='dnf -C --setopt=install_weak_deps=False -y install'
  pkgmgr_search='dnf -C search'
  pkgmgr_update='dnf -y --refresh check-update'
else
  pkgmgr_install='apt-get -y --option Retries=3 install'
  pkgmgr_search='apt-cache search'
  pkgmgr_update='apt-get update'
fi

pkg_repos_sources_aptrpm() {
  sep='#--------------------#'
  argX='grep -Hn -ve "^#" /etc/apt/sources.list /etc/apt/sources.list.d/*.list'

  #printf "${sep}\n${argX}\n" | cat - ${argX}
  printf "${sep}\n${argX}\n" ; eval `echo ${argX}`
}

pkg_repos_sources_dnf() {
  sep='#--------------------#'
  argX='dnf -C repolist -v --enabled | grep -e "Repo-id" -e "Repo-name" -e "Repo-mirrors" -e "Repo-baseurl"'

  #printf "${sep}\n${argX}\n" | cat - ${argX}
  printf "${sep}\n${argX}\n" ; eval `echo ${argX}`
}

pkg_repos_sources() {
  if command -v dnf > /dev/null ; then
    pkg_repos_sources_dnf
  else
    pkg_repos_sources_aptrpm
  fi
}

pkgs_installed_aptrpm() {
  METHOD=${1:-explicit}

  printf 'tasksel --list-tasks\n----------\n'
  #sudo apt-get -q update
  tasksel --list-tasks | column -xc 78 ; echo ''
  printf 'dpkg -l | grep -Ee "meta[-]*package" | sed -n "s|^\w*\s*\(\S*\)\s*.*|\1|p"\n----------\n'
  dpkg -l | grep -Ee "meta[-]*package" | sed -n 's|^\w*\s*\(\S*\)\s*.*|\1|p' | column -xc 78 ; echo '' ; sleep 3

  #if [ "leaf" = "${METHOD}" ] ; then
  # ;
  #else
  # ;
  #fi
  echo "=== Display package holds ===" ;
  echo "grep -e '^Hold' /etc/apt/apt.conf" ;
  grep -e '^Hold' /etc/apt/apt.conf ;
  echo "=============================" ;

  pkg_nms=$(rpm -qa --queryformat '%{name} \n')
  (for pkg_nm in ${pkg_nms} ; do
    no_rdepns=$(rpm -q --whatrequires ${pkg_nm} | grep -e 'no package requires') ;
    if [ ! -z "${no_rdepns}" ] ; then continue ; fi ;

    rpm -q --queryformat '%{group}/%{name} \n' ${pkg_nm} ;
  done) | sort | column -xc 78
}

pkgs_installed_dnf() {
  METHOD=${1:-explicit}

  printf 'dnf -C group list --hidden ids\n----------\n'
  dnf -C group list --hidden ids ; echo '' ; sleep 3
  printf 'dnf -C group list --installed hidden ids\n----------\n'
  #sudo dnf -yq --refresh check-update
  dnf -C group list --installed hidden ids ; echo '' ; sleep 3

  if [ "leaf" = "${METHOD}" ] ; then
    #pkg_nms=$(repoquery -C --installed) ;
    pkg_nms=$(dnf -C repoquery --queryformat '%{name}' --installed) ;
    (for pkg_nm in ${pkg_nms} ; do
      no_rdepns=$(rpm -q --whatrequires ${pkg_nm} | grep -e 'no package requires') ;
      if [ ! -z "${no_rdepns}" ] ; then continue ; fi ;

      pkg_repo=$(dnf -C repoquery --queryformat '%{reponame}' ${pkg_nm}) ;

      echo "(${pkg_repo})" $(rpm -q --queryformat '%{group}/%{name} \n' ${pkg_nm}) ;
    done) | sort | column -xc 78 ;
  else
    echo "=== Display package holds ===" ;
    echo "dnf -C versionlock list" ; dnf -C versionlock list | column -xc 78 ;
    echo "=============================" ;

    # user for explicitly installed ; dep for dependencies
    pkgnms_ver=$(dnf -C history userinstalled | tail -n +2 | grep -e '^\S' | tr -s '\n' ' ') ;
    (for pkgnm_ver in ${pkgnms_ver} ; do
      pkg_nm=$(dnf -C info ${pkgnm_ver} | grep -e Name | cut -d: -f2 | tr -d ' ') ;
      pkg_grp=$(rpm -qi ${pkg_nm} | grep -e Group | cut -d: -f2 | tr -d ' ') ;
      pkg_repo=$(dnf -C repoquery --queryformat '%{reponame}' ${pkg_nm}) ;
      echo "(${pkg_repo}) ${pkg_grp}/${pkg_nm}" ;
    done) | sort | column -xc 78 ;
  fi
}

pkgs_installed() {
  METHOD=${1:-explicit}
  if command -v dnf > /dev/null ; then
    pkgs_installed_dnf ${METHOD}
  else
    pkgs_installed_aptrpm ${METHOD}
  fi
}
