#!/bin/sh

MODULE_REGEX='^[_a-zA-Z][_a-zA-Z0-9?-]+$'
module_name='{{ cookiecutter.project_slug }}'

if [ "" = "$(echo $module_name | grep -E $MODULE_REGEX)" ] ; then
    printf 'ERROR: The package (%s) is not a valid ?? module name. Please do not use a - and use _ instead\n' "$module_name" ;
    
    #Exit to cancel project generation
    exit 1;
fi
