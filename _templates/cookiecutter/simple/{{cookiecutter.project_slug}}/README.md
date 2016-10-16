# {{ cookiecutter.title }}
<!-- .md to .html: markdown foo.md > foo.html
                   pandoc -s -f markdown_strict -t html5 -o foo.html foo.md -->

{{ cookiecutter.description }}

## Download options
source code tarball download:
        
        # [aria2c --check-certificate=false | wget --no-check-certificate | curl -kOL]
        FETCHCMD='aria2c --check-certificate=false'
        $FETCHCMD https://bitbucket.org/{{ cookiecutter.repo_acct }}/{{ cookiecutter.project_slug }}/get/master.zip
        $FETCHCMD https://github.com/{{ cookiecutter.repo_acct }}/{{ cookiecutter.project_slug }}/archive/master.zip

version control repository clone:
        
        # https://[bitbucket.org | github.com]
        git clone https://bitbucket.org/{{ cookiecutter.repo_acct }}/{{ cookiecutter.project_slug }}.git

## Usage
        TODO - fix usage info

## Author/Copyright
Copyright (c) {{ cookiecutter.year }} by {{ cookiecutter.author }} <{{ cookiecutter.email }}>
{% if 'Not open source' != cookiecutter.license %}

## License
Licensed under the {{ cookiecutter.license }} License. See LICENSE for details.
{%- endif %}
