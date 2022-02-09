#!/bin/sh -eux

if [ "root" = "${USER}" ] || [ "${SUDO_USER}" ] ; then
  echo ; echo "ERROR: Do not run script as root or under sudo. Exiting." ;
  echo ; exit 1 ;
fi

PREFIX=${PREFIX:-$HOME/.local} ; EDITOR=${EDITOR:-nano}
LANGS=${@:-py c jvm} ; export LANGS

set +e

_prep_lang_c() {
  echo "Configuring for C language ..." >> /dev/stderr ; sleep 3
  #mkdir -p $HOME/{Downloads,Documents,bin} ${PREFIX}/{bin,include,lib/pkgconfig,share}
  for dirX in Downloads Documents bin ; do mkdir -p $HOME/$dirX ; done
  for dirX in bin include lib/pkgconfig share ; do mkdir -p $PREFIX/$dirX ; done
}

_prep_lang_py() {
  echo "Configuring for Python language ..." >> /dev/stderr ; sleep 3
  #echo "TBD: No config steps needed, as yet." >> /dev/stderr ; sleep 3
  pip install --user build
  #pip install --user wheel future pytest pytest-timeout nose2 hyothesis coverage pylint \
  #  pep8 pycodestyle pydocstyle Sphinx cffi click PyYAML toml configparser
}

_cachepath_lang_jvm() {
  IVYJAR=${IVYJAR:-$HOME/.ant/lib/ivy-*.jar}
  for org_mod_rev in com.puppycrawl.tools:checkstyle:'[8.33,)' \
      com.beautiful-scala:scalastyle_2.13:'[1.4.0,)' org.codenarc:CodeNarc:'[1.6,)' \
      org.scala-lang:scala-compiler:'[2.13.2,)' org.scala-lang:scalap:'[2.13.2,)' \
      org.codehaus.groovy:groovy-all:'[3.0.5,)' org.clojure:clojure:'[1.10.1,)' ; do
    orgX=`echo $org_mod_rev | cut -d: -f1` ;
    modX=`echo $org_mod_rev | cut -d: -f2` ;
    revX=`echo $org_mod_rev | cut -d: -f3` ;

    java -Divy.settings.defaultResolver=main -jar ${IVYJAR} -dependency $orgX $modX $revX -confs default \
      -cachepath $HOME/.ant/lib/classpath_`echo $modX | cut -d_ -f1`.txt ;
  done

  #mkdir -p ${PREFIX}/lib/jython2.7
  #java -Divy.settings.defaultResolver=main -jar ${IVYJAR} -dependency org.python jython '[2.7.2,)' -notransitive -types jar \
  #  -retrieve "${PREFIX}/lib/jython2.7/[artifact]-[revision](-[classifier]).[ext]"
  java -Divy.settings.defaultResolver=main -jar ${IVYJAR} -dependency org.python jython-standalone '[2.7.2,)' -notransitive -types jar \
    -retrieve "${PREFIX}/bin/[artifact]-[revision](-[classifier]).[ext]"
  java -Divy.settings.defaultResolver=main -jar ${IVYJAR} -dependency org.jruby jruby-complete '[9.2.11.1,)' -notransitive -types jar bundle \
    -retrieve "${PREFIX}/bin/[artifact]-[revision](-[classifier]).[ext]"
}

_alias_lang_jvm() {
  if grep -q -E "csh" "$SHELL" ; then
  	shell_rc=${shell_rc:-$HOME/.cshrc} ;
  else
  	shell_rc=${shell_rc:-$HOME/.bashrc} ;
  fi

  for cmd_mainclass in checkstyle:com.puppycrawl.tools.checkstyle.Main \
      scalastyle:org.scalastyle.Main CodeNarc:org.codenarc.CodeNarc \
      scalac:scala.tools.nsc.Main scala:scala.tools.nsc.MainGenericRunner \
      scaladoc:scala.tools.nsc.ScalaDoc scalap:scala.tools.scalap.Main \
      fsc:scala.tools.nsc.fsc.CompileClient \
      groovyc:org.codehaus.groovy.tools.FileSystemCompiler \
      groovy:groovy.ui.GroovyMain groovydoc:org.codehaus.groovy.tools.groovydoc.Main \
      groovysh:org.codehaus.groovy.tools.shell.Main \
      grape:org.codehaus.groovy.tools.GrapeMain clojure:clojure.main ; do
    cmd=`echo $cmd_mainclass | cut -d: -f1` ;
    mainclass=`echo $cmd_mainclass | cut -d: -f2` ;

    # skip creating alias, if cmd exists
    if command -v $cmd > /dev/null ; then continue ; fi ;

    if ! grep -q -E "alias $cmd" ${shell_rc} ; then
		  if grep -q -E "csh" "$SHELL" ; then
				case $cmd in
				  scalac|scala|scaladoc|fsc)
				    echo alias $cmd java -cp `cat $HOME/.ant/lib/classpath_scala-compiler.txt` $mainclass >> ${shell_rc} ;;
				  groovyc|groovy|groovydoc|groovysh|grape)
				    echo alias $cmd java -cp `cat $HOME/.ant/lib/classpath_groovy-all.txt` $mainclass >> ${shell_rc} ;;
				  *) echo alias $cmd java -cp `cat $HOME/.ant/lib/classpath_$cmd.txt` $mainclass >> ${shell_rc} ;;
				esac ;
      else
				case $cmd in
				  scalac|scala|scaladoc|fsc)
				    echo alias "$cmd='java -cp `cat $HOME/.ant/lib/classpath_scala-compiler.txt` $mainclass'" >> ${shell_rc} ;;
				  groovyc|groovy|groovydoc|groovysh|grape)
				    echo alias "$cmd='java -cp `cat $HOME/.ant/lib/classpath_groovy-all.txt` $mainclass'" >> ${shell_rc} ;;
				  *) echo alias "$cmd='java -cp `cat $HOME/.ant/lib/classpath_$cmd.txt` $mainclass'" >> ${shell_rc} ;;
				esac ;
      fi
    fi
  done

  if ! command -v jython > /dev/null ; then
    ## jython java -jar ${PREFIX}/lib/jython2.7/jython-*.jar
    ## jython-standalone java -jar ${PREFIX}/bin/jython-standalone-*.jar
		if ! grep -q -E "alias jython-standalone" ${shell_rc} ; then
		  if grep -q -E "csh" "$SHELL" ; then
		    echo alias jython-standalone java -jar ${PREFIX}/bin/jython-standalone-*.jar >> ${shell_rc} ;
		  else
		    echo "alias jython-standalone='java -jar ${PREFIX}/bin/jython-standalone-*.jar'" >> ${shell_rc} ;
		  fi
		fi
  fi
  if ! command -v jruby > /dev/null ; then
		if ! grep -q -E "alias jruby" ${shell_rc} ; then
		  if grep -q -E "csh" "$SHELL" ; then
		    echo alias jruby java -jar ${PREFIX}/bin/jruby-complete-*.jar >> ${shell_rc} ;
		  else
		    echo "alias jruby='java -jar ${PREFIX}/bin/jruby-complete-*.jar'" >> ${shell_rc} ;
		  fi
		fi
  fi
}

_prep_lang_jvm() {
  echo "Configuring for JVM language(s) ..." >> /dev/stderr ; sleep 3
  mkdir -p $HOME/.m2 $HOME/.ivy2 $HOME/.ant/lib

  if [ ! -f "$HOME/.m2/settings-online.xml" ] ; then
    cat << EOF > $HOME/.m2/settings-online.xml ;
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
					  https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository/>
  <interactiveMode/>
  <offline/>
  <pluginGroups/>
  <servers/>
  <mirrors>
    <mirror>
      <id>central-secure</id>
      <url>https://repo.maven.apache.org/maven2</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
  <proxies/>
  <profiles/>
  <activeProfiles/>
</settings>
EOF
  fi
  if [ ! -f "$HOME/.m2/settings.xml" ] ; then
    cat << EOF > $HOME/.m2/settings.xml ;
<settings xmlns="http://maven.apache.org/SETTINGS/1.0.0"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/SETTINGS/1.0.0
					  https://maven.apache.org/xsd/settings-1.0.0.xsd">
  <localRepository/>
  <interactiveMode/>
  <offline>true</offline>
  <pluginGroups/>
  <servers/>
  <mirrors>
    <mirror>
      <id>central-secure</id>
      <url>https://repo.maven.apache.org/maven2</url>
      <mirrorOf>central</mirrorOf>
    </mirror>
  </mirrors>
  <proxies/>
  <profiles/>
  <activeProfiles/>
</settings>
EOF
  fi
  if [ ! -f "$HOME/.ivy2/ivysettings.xml" ] ; then
    cat << EOF > $HOME/.ivy2/ivysettings.xml ;
<ivysettings>
  <include url = "\${ivy.default.settings.dir}/ivysettings.xml"/>

  <properties file = "\${ivy.basedir}/src/main/resources/versions.properties"/>
  <property name = 'maven.local.default.root'
    value = "\${user.home}/.m2/repository"/>
  <property name = 'maven.local.default.ivy.pattern'
    value = '[organization]/[module]/[revision]/[module](-[revision])(-[classifier]).pom'/>
  <property name = 'maven.local.default.artifact.pattern'
    value = '[organization]/[module]/[revision]/[artifact](-[revision])(-[classifier]).[ext]'/>
  <settings defaultResolver = "\${ivy.settings.defaultResolver}"/>

  <resolvers>
    <!--<filesystem name = 'shared'>
      <ivy pattern = "\${ivy.shared.default.root}/\${ivy.shared.default.ivy.pattern}"/>
      <artifact pattern = "\${ivy.shared.default.root}/\${ivy.shared.default.artifact.pattern}"/>
    </filesystem>-->

    <!--<filesystem name = 'maven-local' m2compatible = 'true'>
      <ivy pattern = "\${maven.local.default.root}/\${maven.local.default.ivy.pattern}"/>
      <artifact pattern = "\${maven.local.default.root}/\${maven.local.default.artifact.pattern}"/>
    </filesystem>-->
    <ibiblio name = 'maven-local' m2compatible = 'true'
      root = "file://\${maven.local.default.root}"
      pattern = "\${maven.local.default.artifact.pattern}"/>

    <!-- https://repo.maven.apache.org/maven2 -->
    <!--<ibiblio name = 'public' m2compatible = 'true'
      root = 'https://repo.maven.apache.org/maven2'/>-->

    <url name = 'typesafe-ivy'>
      <ivy pattern = "https://dl.bintray.com/typesafe/ivy-releases/\${ivy.local.default.ivy.pattern}"/>
      <artifact pattern = "https://dl.bintray.com/typesafe/ivy-releases/\${ivy.local.default.artifact.pattern}"/>
    </url>

    <chain name = 'default' returnFirst = 'true'>
      <resolver ref = 'local'/> <!--<resolver ref = 'shared'/>-->
      <resolver ref = 'maven-local'/> </chain>
    <chain name = 'main' returnFirst = 'true'>
      <resolver ref = 'public'/> <resolver ref = 'typesafe-ivy'/> </chain>
  </resolvers>
</ivysettings>
EOF
  fi

  # download up-to-date ivy jar
  IVYJAR=${IVYJAR:-`find /usr -type f -name 'ivy*.jar' | head -n1`}
  if [ -z "${IVYJAR}" ] ; then
    #mvn -Dartifact=org.apache.ivy:ivy:2.5.0:jar -DoutputDirectory=$HOME/.ant/lib \
    #  -Dtransitive=false -s $HOME/.m2/settings-online \
    #  org.apache.maven.plugins:maven-dependency-plugin:2.6:copy ;
    cd $HOME/Downloads ;
    #curl -LO https://dlcdn.apache.org/ant/ivy/2.5.0/apache-ivy-2.5.0-bin.zip ;
    #unzip apache-ivy-2.5.0-bin.zip ; cp apache-ivy-2.5.0-bin/ivy-*.jar $HOME/.ant/lib/ ;
    curl -LO https://repo1.maven.org/maven2/org/apache/ivy/ivy/2.5.0/ivy-2.5.0.jar ;
    cp ivy-*.jar $HOME/.ant/lib/ ;
  else
    #? installed pkg [gradle|groovy]: {gradle/lib/plugins,groovy/lib}/ivy-*.jar
    java -Divy.settings.defaultResolver=main -jar ${IVYJAR} -settings $HOME/.ivy2/ivysettings.xml \
      -dependency org.apache.ivy ivy '[2.5.0,)' -notransitive -types jar \
      -retrieve "$HOME/.ant/lib/[artifact]-[revision].[ext]" ;
  fi

  _cachepath_lang_jvm ; ls $HOME/.ant/lib/classpath_*.txt ; sleep 5
  _alias_lang_jvm ; alias ; sleep 5
}

_prep_lang_dotnet() {
  nuget_ver=${nuget_ver:-latest} ; framework=${framework:-net471}
  echo "Configuring for .NET language(s) ..." >> /dev/stderr ; sleep 3
  mkdir -p $HOME/bin $HOME/.nuget/packages $HOME/nuget/packages ; cd $HOME/bin
  curl -LO https://dist.nuget.org/win-x86-commandline/${nuget_ver}/nuget.exe
  for pkg_ver in netstandard.library:2.0.3 fsharp.core:4.7.2 mono.gendarme:2.11.0.20121120 ilrepack:2.0.18 ; do
  	pkgX=$(echo $pkg_ver | cut -d: -f1) ;
  	verX=$(echo $pkg_ver | cut -d: -f2) ;
  	mono $HOME/bin/nuget.exe install -framework ${framework} -excludeversion $pkgX -version $verX ;
  done
}

_prep_lang_scm() {
  echo "Configuring for Scheme language ..." >> /dev/stderr ; sleep 3
  mkdir -p ${PREFIX}/share/scheme-r7rs/sitelib
}

_prep_lang_hs() {
  echo "Configuring for Haskell language ..." >> /dev/stderr ; sleep 3
  if grep -q -E "csh" "$SHELL" ; then
  	shell_rc=${shell_rc:-$HOME/.cshrc} ;
  else
  	shell_rc=${shell_rc:-$HOME/.bashrc} ;
  fi
  RESOLVER=${RESOLVER:-lts-13.30}

  mkdir -p $HOME/.stack/global-project
  if ! grep -q -E "system-ghc" $HOME/.stack/config.yaml ; then
  	cat << EOF >> $HOME/.stack/config.yaml ;
templates:
    params: null
system-ghc: true
#allow-newer: true
#extra-include-dirs: [${PREFIX}/include]
#extra-lib-dirs: [${PREFIX}/lib]
EOF
	fi
  echo "NOTE: Update/fix (as needed) $HOME/.stack/config.yaml" >> /dev/stderr ;
  sleep 2 ; $EDITOR $HOME/.stack/config.yaml
  if ! grep -q -E "resolver:" $HOME/.stack/global-project/stack.yaml ; then
  	cat << EOF >> $HOME/.stack/global-project/stack.yaml ;
packages: []
resolver: ${RESOLVER}
EOF
	fi
  echo "NOTE: Update/fix (as needed) $HOME/.stack/global-project/stack.yaml" >> /dev/stderr ;
  sleep 2 ; $EDITOR $HOME/.stack/global-project/stack.yaml

  if ! grep -q -E "alias stack" ${shell_rc} ; then
    if grep -q -E "csh" "$SHELL" ; then
      echo alias stack stack --resolver ${RESOLVER} >> ${shell_rc} ;
    else
      echo "alias stack='stack --resolver ${RESOLVER}'" >> ${shell_rc} ;
    fi
  fi
  #outside of project
  stack --resolver ${RESOLVER} setup
}

_prep_lang_lisp() {
  echo "Configuring for Common Lisp language ..." >> /dev/stderr ; sleep 3
  mkdir -p $HOME/Downloads ; cd $HOME/Downloads
  # www.quicklisp.org/beta
  curl -LO https://beta.quicklisp.org/quicklisp.lisp
  curl -LO https://beta.quicklisp.org/quicklisp.lisp.asc
  curl -LO https://beta.quicklisp.org/release-key.txt
  gpg --import release-key.txt ; gpg --verify quicklisp.lisp.asc quicklisp.lisp
  # [sbcl | ccl]
  echo "sbcl --load quicklisp.lisp"
  echo "  * (quicklisp-quickstart:install)"
  echo "  * (ql:add-to-init-file)" ; sleep 5
  sbcl --load quicklisp.lisp
}

_prep_lang_ml() {
  echo "Configuring for OCaml language ..." >> /dev/stderr ; sleep 3
  opam init ; eval `opam env`
  opam switch create ocaml-system.${OCAMLVER:-4.05.0} ; eval `opam env`

  #opam install dune bisect batteries odoc oUnit qcheck ocaml-inifiles yojson ezjsonm \
  #  ctypes ctypes-foreign bolt
}

_prep_lang_go() {
  echo "Configuring for Go language ..." >> /dev/stderr ; sleep 3
  mkdir -p $HOME/go/src/bitbucket.org/${BBUSER:-imcomputer}
}

_prep_lang_rs() {
  echo "Configuring for Rust language ..." >> /dev/stderr ; sleep 3
  echo "TBD: No config steps needed, as yet." >> /dev/stderr ; sleep 3
}

_prep_lang_rb() {
  echo "Configuring for Ruby language ..." >> /dev/stderr ; sleep 3
  #echo "TBD: No config steps needed, as yet." >> /dev/stderr ; sleep 3
  if ! grep -q -E ":ipv4_fallback_enabled:" $HOME/.gemrc ; then
  	echo ':ipv4_fallback_enabled: true' >> $HOME/.gemrc ;
  fi
  #gem install --user-install bundler rspec rubocop yard ffi log4r logging rake rdoc \
  #  minitest simplecov rake-compiler
}

_prep_lang_swift() {
  echo "Configuring for Swift language ..." >> /dev/stderr ; sleep 3
  echo "TBD: No config steps needed, as yet." >> /dev/stderr ; sleep 3
}

for langX in ${LANGS} ; do
  case ${langX} in
    py) _prep_lang_py ;;
    c) _prep_lang_c ;;
    jvm|java|scala|groovy|clj) _prep_lang_jvm ;;
    dotnet|cs|fs) _prep_lang_dotnet ;;
    scm) _prep_lang_scm ;;
    hs) _prep_lang_hs ;;
    lisp) _prep_lang_lisp ;;
    ml) _prep_lang_ml ;;
    go) _prep_lang_go ;;
    rs) _prep_lang_rs ;;
    rb) _prep_lang_rb ;;
    swift) _prep_lang_swift ;;
    *) _prep_lang_py ;;
  esac
done

#========================================================================#
