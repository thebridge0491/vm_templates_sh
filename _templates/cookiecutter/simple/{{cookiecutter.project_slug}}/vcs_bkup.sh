#!/bin/sh

# usage: sh vcs_bkup.sh <func> [revID]

if [ ! -e "./vcs_bkup_info.txt" ] ; then
	echo 'Missing vcs_bkup_info.txt --- exiting' ; exit ;
else
	echo '--- sourcing provided vcs_bkup_info.txt: ' ;
	cat ./vcs_bkup_info.txt ;
fi

# source ./vcs_bkup_info.txt
. ./vcs_bkup_info.txt

bundle_revsets() {
	revsets=${@:-'--all'}
	echo revsets: ${revsets}
	
	if [ -e ".hg" ] ; then
		hg bundle --type v1 ${revsets} ${project}_${lang_ext}.hg ;
	elif [ -e ".git" ] ; then
		git bundle create ${project}_${lang_ext}.git ${revsets} ;
	fi
}

archive_rev() {
	namePrefix=${1:-${project}} #; revID=${2:-default}
	opts=${3:-}
	
	if [ -e ".hg" ] ; then
		hg archive --rev ${2:-default} ${opts} ${namePrefix}_${lang_ext}.zip ;
	elif [ -e ".git" ] ; then
		git archive --output ${namePrefix}_${lang_ext}.zip \
			--prefix ${namePrefix}_${lang_ext}/ ${2:-HEAD} ${opts} ;
	fi
}

fix_template() {
	opts=$@
	if [ -e ".hg" ] ; then
		hg archive --rev fix_template -I _templates $opts \
			template_${lang_ext}.zip ;
	elif [ -e ".git" ] ; then
		git archive --output template_${lang_ext}.zip \
			--prefix template_${lang_ext}/ fix_template _templates $opts ;
	fi
}

# list all revision hashes (ascending order):
#  hg log -r : -T '{node|short}'
#  git log --all --reverse --format="%h"
#  git rev-list --all --reverse --abbrev-commit HEAD

changed_files_archive() {
	namePrefix=${1:-changedFiles} #; revID=${2:-HEAD}
	
	if [ -e ".hg" ] ; then
		#filesX=$(hg status --change ${2:-default} --no-status | sed 's|^| -I |') ;
		filesX=$(hg log -r ${2:-default} -T '{join(files, " -I ")}') ;
		hg archive --rev ${2:-default} -I $filesX ${namePrefix}.zip ;
	elif [ -e ".git" ] ; then
		##nullHash=$(echo -n '' | git hash-object -t tree --stdin) ;
		#revXtoY=${2:-HEAD}~1..${2:-HEAD} ;
		#filesX=$(git diff --diff-filter=ACMRTUXB --name-only ${revXtoY}) ;
		filesX=$(git diff-tree --no-commit-id --name-only -r ${2:-HEAD}) ;
		git archive --output ${namePrefix}.zip --prefix ${namePrefix}/ \
			${2:-HEAD} $filesX ;
	fi
}

func=$1 ; shift ;
${func} $@ ;

#--------------------------------------------------------------------
