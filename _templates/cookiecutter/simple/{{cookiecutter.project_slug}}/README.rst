{{ cookiecutter.title }}
===========================================
.. .rst to .html: rst2html5 foo.rst > foo.html
..                pandoc -s -f rst -t html5 -o foo.html foo.rst

{{ cookiecutter.description }}

Download options
----------------
source code tarball download:
        
        # [aria2c --check-certificate=false | wget --no-check-certificate | curl -kOL]
        
        FETCHCMD='aria2c --check-certificate=false'

        $FETCHCMD https://bitbucket.org/{{ cookiecutter.repo_acct }}/{{ cookiecutter.project_slug }}/get/master.zip
        
        $FETCHCMD https://github.com/{{ cookiecutter.repo_acct }}/{{ cookiecutter.project_slug }}/archive/master.zip

version control repository clone:
        
        # https://[bitbucket.org | github.com]
        
        git clone https://bitbucket.org/{{ cookiecutter.repo_acct }}/{{ cookiecutter.project_slug }}.git

Usage
-----
        TODO - fix usage info

Author/Copyright
----------------
Copyright (c) {{ cookiecutter.year }} by {{ cookiecutter.author }} <{{ cookiecutter.email }}>
{% if 'Not open source' != cookiecutter.license %}

License
-------
Licensed under the {{ cookiecutter.license }} License. See LICENSE for details.
{%- endif %}
