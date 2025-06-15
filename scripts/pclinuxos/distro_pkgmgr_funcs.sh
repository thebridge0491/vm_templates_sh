# pclinuxos/{distro_pkgs.ini,distro_pkgmgr_funcs.sh}
# to use variables|functions, source these file(s):
# source distro_pkgs.ini ; source distro_pkgmgr_funcs.sh
# ${pkgmgr_install} ${pkgs_cmdln_tools} 2> /tmp/pkgsInstall_stderr.txt | tee /tmp/pkgsInstall_stdout.txt

pkgmgr_install='apt-get -y --option Retries=3 install'
pkgmgr_search='apt-cache search'
pkgmgr_update='apt-get update'

pkg_repos_sources() {
  sep='#--------------------#'
  argX='grep -Hn -ve "^#" /etc/apt/sources.list /etc/apt/sources.list.d/*.list'

  #printf "${sep}\n${argX}\n" | cat - ${argX}
  printf "${sep}\n${argX}\n" ; eval `echo ${argX}`
}

pkgs_installed() {
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
