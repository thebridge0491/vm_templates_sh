#!/bin/sh

proj_dir=$(pwd)

mkdir -p build ; cp -R choices build/
rm -r choices

if ! [ 'Not open source' = '{{ cookiecutter.license }}' ] ; then
    cp build/choices/license/LICENSE_{{ cookiecutter.license }} LICENSE ;
fi

if [ -d '_templates' ] && [ -e '{{ cookiecutter._template }}' ] ; then
	mkdir -p _templates/cookiecutter ;
	cp -R {{ cookiecutter._template }} _templates/cookiecutter/ ;
fi
