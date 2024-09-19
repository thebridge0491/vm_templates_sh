#!/bin/sh -eux

if [ "root" = "${USER}" ] || [ "${SUDO_USER}" ] ; then
  echo ; echo "ERROR: Do not run script as root or under sudo. Exiting." ;
  echo ; exit 1 ;
fi

PREFIX=${PREFIX:-${HOME}/.local} ; EDITOR=${EDITOR:-nano}
LANGS=${@:-py c jvm} ; export LANGS

if grep -q -E "csh" "${SHELL}" ; then
  shell_rc=${shell_rc:-${HOME}/.cshrc} ;
elif grep -q -E "bash" "${SHELL}" ; then
  shell_rc=${shell_rc:-${HOME}/.bashrc} ;
elif grep -q -E "zsh" "${SHELL}" ; then
  shell_rc=${shell_rc:-${HOME}/.zshrc} ;
else
  shell_rc=${shell_rc:-${HOME}/.shrc} ;
fi
if command -v bind > /dev/null ; then
  if ! grep -q -E "history.*-search" ${HOME}/.inputrc ; then
    cat << EOF >> ${HOME}/.inputrc
"\e[A": history-search-backward
"\e[B": history-search-forward

EOF
  fi ;
  echo "(info) bind -p | grep -e 'history.*-search'" >> /dev/stderr ;
  bind -p | grep -e 'history.*-search' >> /dev/stderr ; sleep 3 ;
elif command -v bindkey > /dev/null ; then
  echo "(info) bindkey | grep -e 'history.*-search'" >> /dev/stderr ;
  bindkey | grep -e 'history.*-search' >> /dev/stderr ; sleep 3 ;
fi
## NOTES for bind (linux) or bindkey (freebsd|macOS) history search [back|for]ward
##   equivalent: \e (escape char) <--> \M- (meta prefix) <--> ^[
##
##   linux ${HOME}/.inputrc OR /etc/inputrc
##   --------------------
##   #"\M-[A": history-search-backward
##   #"\M-[B": history-search-forward
##   "\e[A": history-search-backward
##   "\e[B": history-search-forward
##
##   freebsd ${HOME}/.cshrc OR [/usr/local]/etc/inputrc
##   --------------------
##   ..
##   if ( $?tcsh ) then
##     bindkey "^W" backward-delete-word
##     bindkey -k up history-search-backward
##     bindkey -k down history-search-forward
##   endif
##   ..
##
##   macOS ${HOME}/.zshrc
##   --------------------
##   bindkey "^R" history-incremental-search-backward
##   bindkey "^S" history-incremental-search-forward
##   #bindkey "^[[A" history-search-backward
##   #bindkey "^[[B" history-search-forward
##   bindkey "\e[A" history-search-backward
##   bindkey "\e[B" history-search-forward

cp -an ${0} /var/tmp/

set +e

_prep_lang_c() {
  echo "Configuring for C language ..." >> /dev/stderr ; sleep 3
  #mkdir -p ${HOME}/{Downloads,Documents,bin} ${PREFIX}/{bin,include,lib/pkgconfig,share}
  for dirX in Downloads Documents bin ; do mkdir -p ${HOME}/${dirX} ; done
  for dirX in bin include lib/pkgconfig share ; do mkdir -p ${PREFIX}/${dirX} ; done
}

_prep_lang_py() {
  echo "Configuring for Python language ..." >> /dev/stderr ; sleep 3
  #echo "TBD: No config steps needed, as yet." >> /dev/stderr ; sleep 3
  ${PYTHON:-python3} -m pip install --user build
  #${PYTHON:-python3} -m pip install --user wheel pytest pytest-timeout nose2 \
  #  hyothesis coverage pylint pep8 pycodestyle pydocstyle sphinx cffi click \
  #  pyyaml toml configparser
}

_cachepath_lang_jvm() {
  IVYJAR=${IVYJAR:-`find ${HOME}/.ant/lib -type f -name 'ivy*.jar' | head -n1`}
  for org_mod_rev in com.puppycrawl.tools:checkstyle:'[8.33,)' \
      com.beautiful-scala:scalastyle_2.13:'[1.4.0,)' org.codenarc:CodeNarc:'[1.6,)' \
      org.scala-lang:scala-compiler:'[2.13.2,)' org.scala-lang:scalap:'[2.13.2,)' \
      org.codehaus.groovy:groovy-all:'[3.0.5,)' org.clojure:clojure:'[1.10.1,)' ; do
    orgX=`echo ${org_mod_rev} | cut -d: -f1` ;
    modX=`echo ${org_mod_rev} | cut -d: -f2` ;
    revX=`echo ${org_mod_rev} | cut -d: -f3` ;

    java -Divy.settings.defaultResolver=main -jar ${IVYJAR} -dependency ${orgX} ${modX} ${revX} -confs default \
      -cachepath ${HOME}/.ant/lib/classpath_`echo ${modX} | cut -d_ -f1`.txt ;
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
  for cmd_mainclass in checkstyle:com.puppycrawl.tools.checkstyle.Main \
      CodeNarc:org.codenarc.CodeNarc scala:scala.tools.nsc.MainGenericRunner \
      scalac:scala.tools.nsc.Main scaladoc:scala.tools.nsc.ScalaDoc \
      scalap:scala.tools.scalap.Main fsc:scala.tools.nsc.fsc.CompileClient \
      scalastyle:org.scalastyle.Main groovy:groovy.ui.GroovyMain \
      groovyc:org.codehaus.groovy.tools.FileSystemCompiler \
      groovydoc:org.codehaus.groovy.tools.groovydoc.Main \
      groovysh:org.codehaus.groovy.tools.shell.Main \
      groovyConsole:groovy.ui.Console \
      grape:org.codehaus.groovy.tools.GrapeMain clojure:clojure.main ; do
    cmd=`echo ${cmd_mainclass} | cut -d: -f1` ;
    mainclass=`echo ${cmd_mainclass} | cut -d: -f2` ;

    # skip creating alias, if cmd exists
    if command -v ${cmd} > /dev/null ; then continue ; fi ;

    if ! grep -q -E "^alias ${cmd}" ${shell_rc} ; then
      if grep -q -E "csh" "${SHELL}" ; then
        case ${cmd} in
          scalac|scala|scaladoc|fsc)
            echo alias "${cmd} 'java \${JAVA_OPTS} -cp \`cat ${HOME}/.ant/lib/classpath_scala-compiler.txt\` ${mainclass} -usejavacp'" >> ${shell_rc} ;;
          groovyc|groovy|groovydoc|groovysh|groovyConsole|grape)
            echo alias "${cmd} 'java \${JAVA_OPTS} -cp \`cat ${HOME}/.ant/lib/classpath_groovy-all.txt\` ${mainclass}'" >> ${shell_rc} ;;
          *) echo alias "${cmd} 'java \${JAVA_OPTS} -cp \`cat ${HOME}/.ant/lib/classpath_${cmd}.txt\` ${mainclass}'" >> ${shell_rc} ;;
        esac ;
      else
        case ${cmd} in
          scalac|scala|scaladoc|fsc)
            echo alias "${cmd}='java \${JAVA_OPTS} -cp \`cat ${HOME}/.ant/lib/classpath_scala-compiler.txt\` ${mainclass} -usejavacp'" >> ${shell_rc} ;;
          groovyc|groovy|groovydoc|groovysh|groovyConsole|grape)
            echo alias "${cmd}='java \${JAVA_OPTS} -cp \`cat ${HOME}/.ant/lib/classpath_groovy-all.txt\` ${mainclass}'" >> ${shell_rc} ;;
          *) echo alias "${cmd}='java \${JAVA_OPTS} -cp \`cat ${HOME}/.ant/lib/classpath_${cmd}.txt\` ${mainclass}'" >> ${shell_rc} ;;
        esac ;
      fi
    fi
  done

  if ! command -v jython > /dev/null ; then
    ## jython java -jar ${PREFIX}/lib/jython2.7/jython-*.jar
    ## jython-standalone java -jar ${PREFIX}/bin/jython-standalone-*.jar
    if ! grep -q -E "^alias jython-standalone" ${shell_rc} ; then
      if grep -q -E "csh" "${SHELL}" ; then
        echo alias "jython-standalone 'java \${JAVA_OPTS} -cp ${PREFIX}/bin/jython-standalone-*.jar org.python.util.jython'" >> ${shell_rc} ;
      else
        echo alias "jython-standalone='java \${JAVA_OPTS} -cp ${PREFIX}/bin/jython-standalone-*.jar org.python.util.jython'" >> ${shell_rc} ;
      fi
    fi
  fi
  if ! command -v jruby > /dev/null ; then
    if ! grep -q -E "^alias jruby" ${shell_rc} ; then
      if grep -q -E "csh" "${SHELL}" ; then
        echo alias "jruby 'java \${JAVA_OPTS} -cp ${PREFIX}/bin/jruby-complete-*.jar org.jruby.Main'" >> ${shell_rc} ;
      else
        echo alias "jruby='java \${JAVA_OPTS} -cp ${PREFIX}/bin/jruby-complete-*.jar org.jruby.Main'" >> ${shell_rc} ;
      fi
    fi
  fi
}

_prep_lang_jvm() {
  echo "Configuring for JVM language(s) ..." >> /dev/stderr ; sleep 3
  mkdir -p ${HOME}/.m2 ${HOME}/.ivy2 ${HOME}/.ant/lib

  if [ ! -f "${HOME}/.m2/settings-online.xml" ] ; then
    cat << EOF > ${HOME}/.m2/settings-online.xml ;
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
  if [ ! -f "${HOME}/.m2/settings.xml" ] ; then
    cat << EOF > ${HOME}/.m2/settings.xml ;
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
  if [ ! -f "${HOME}/.ivy2/ivysettings.xml" ] ; then
    cat << EOF > ${HOME}/.ivy2/ivysettings.xml ;
<ivysettings>
  <include url = "\${ivy.default.settings.dir}/ivysettings.xml"/>

  <property name = 'rsrc_path' value = "\${ivy.basedir}/src/main/resources"/>
  <properties file = "\${rsrc_path}/versions.properties"/>
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
  IVYJAR=${IVYJAR:-`find ${HOME}/.ant/lib /usr -type f -name 'ivy*.jar' | head -n1`}
  if [ -z "${IVYJAR}" ] ; then
    #mvn -Dartifact=org.apache.ivy:ivy:2.5.0:jar -DoutputDirectory=${HOME}/.ant/lib \
    #  -Dtransitive=false -s ${HOME}/.m2/settings-online \
    #  org.apache.maven.plugins:maven-dependency-plugin:2.6:copy ;
    cd ${HOME}/Downloads ;
    #curl -LO https://dlcdn.apache.org/ant/ivy/2.5.0/apache-ivy-2.5.0-bin.zip ;
    #unzip apache-ivy-2.5.0-bin.zip ; cp -a apache-ivy-2.5.0-bin/ivy-*.jar ${HOME}/.ant/lib/ ;
    curl -LO https://repo1.maven.org/maven2/org/apache/ivy/ivy/2.5.0/ivy-2.5.0.jar ;
    cp -a ivy-*.jar ${HOME}/.ant/lib/ ;
  else
    #? installed pkg [gradle|groovy]: {gradle/lib/plugins,groovy/lib}/ivy-*.jar
    java -Divy.settings.defaultResolver=main -jar ${IVYJAR} -settings ${HOME}/.ivy2/ivysettings.xml \
      -dependency org.apache.ivy ivy '[2.5.0,)' -notransitive -types jar \
      -retrieve "${HOME}/.ant/lib/[artifact]-[revision].[ext]" ;
  fi

  _cachepath_lang_jvm ; ls ${HOME}/.ant/lib/classpath_*.txt ; sleep 5
  _alias_lang_jvm ; alias ; sleep 5
}
## NOTES to dnld build tool wrappers for JVM languages
## wrapper for maven (./mvnw[.cmd], .mvn/wrapper/___.[properties|jar]):
##  curl -LO https://repo1.maven.org/maven2/org/apache/maven/wrapper/maven-wrapper-distribution/[3.1.0]/maven-wrapper-distribution-[3.1.0]-bin.zip
##  unzip maven-wrapper-distribution-[3.1.0]-bin.zip
##  cat << EOF > .mvn/wrapper/maven-wrapper.properties
##  distributionUrl=https://repo.maven.apache.org/maven2/org/apache/maven/apache-maven/[3.3.9]/apache-maven-[3.3.9]-bin.zip
##  wrapperUrl=https://repo.maven.apache.org/maven2/org/apache/maven/wrapper/maven-wrapper/[3.1.0]/maven-wrapper-[3.1.0].jar
##  EOF
##  ./mvnw[.cmd] --help
## ----------------------------------------------
## wrapper for gradle (./gradlew[.bat], gradle/wrapper/___.[properties|jar]):
##  curl --create-dirs -Lo gradle/wrapper/gradle-wrapper.[properties|jar] https://github.com/gradle/gradle/raw/[master|v6.9.0]/gradle/wrapper/gradle-wrapper.[properties|jar]
##  java -cp gradle/wrapper/gradle-wrapper.jar org.gradle.wrapper.GradleWrapperMain wrapper [--gradle-version 6.9]
##  ./gradlew[.bat] help
## ----------------------------------------------
## wrapper for sbt (./sbtw):
##  curl -Lo sbtw https://git.io.sbt
##  chmod +x ./sbtw ; ./sbtw [-sbt-version 1.5.2] -sbt-create
## OR
##  java -jar ivy.jar -dependency org.scala-sbt sbt-launch [1.5.2] -retrieve "${HOME}/.sbt/launchers/[revision]/[artifact](-[classifier]).[ext]"
##  echo "java -cp \${HOME}/.sbt/launchers/[1.5.2]/sbt-launch.jar xsbt.boot.Boot \${@}" > sbtw
##  chmod +x ./sbtw ; ./sbtw help
## ----------------------------------------------
## wrapper for leiningen (./leinw):
##  curl -Lo leinw https://github.com/technomancy/leiningen/raw/[stable|2.9.5]/bin/lein
##  chmod +x ./leinw [; ./leinw upgrade [2.9.5]]
## ----------------------------------------------

_prep_lang_dotnet() {
  nuget_ver=${nuget_ver:-latest} ; framework=${framework:-net471}
  echo "Synchronize certificate store for Mono ..." >> /dev/stderr ; sleep 3
  if [ "Linux" = "`uname -s`" ] ; then
    #cert-sync --user /etc/pki/tls/certs/ca-bundle.crt ; # RedHat
    cert-sync --user /etc/ssl/certs/ca-certificates.crt ; # Debian,Void
  elif [ "FreeBSD" = "`uname -s`" ] ; then
    #cert-sync --user /usr/local/etc/ssl/cert.pem ;
    cert-sync --user /usr/local/share/certs/ca-root-nss.crt ;
  fi
  echo "Configuring for .NET language(s) ..." >> /dev/stderr ; sleep 3
  mkdir -p ${HOME}/bin ${HOME}/.nuget/packages ${HOME}/nuget/packages ; cd ${HOME}/bin
  curl -LO https://dist.nuget.org/win-x86-commandline/${nuget_ver}/nuget.exe
  for pkg_ver in netstandard.library:2.0.3 fsharp.core:4.7.2 mono.gendarme:2.11.0.20121120 ilrepack:2.0.18 ; do
    pkgX=$(echo ${pkg_ver} | cut -d: -f1) ;
    verX=$(echo ${pkg_ver} | cut -d: -f2) ;
    mono ${HOME}/bin/nuget.exe install -framework ${framework} -excludeversion -o ${HOME}/nuget/packages ${pkgX} -version ${verX} ;
  done
  #cd ${HOME}/Downloads
  #curl -LO https://dotnet.microsoft.com/download/dotnet/scripts/v1/dotnet-install.sh
  #sh ./dotnet-install.sh --channel ${dotnet_ver:-LTS}
  #if ! grep -q -E "DOTNET_ROOT" ${shell_rc} ; then
  #  if grep -q -E "csh" "${SHELL}" ; then
  #    echo setenv DOTNET_ROOT \${HOME}/.dotnet >> ${shell_rc} ;
  #    echo "set path = (${path} \${HOME}/.dotnet)" >> ${shell_rc} ;
  #  else
  #    echo export DOTNET_ROOT=\${HOME}/.dotnet >> ${shell_rc} ;
  #    echo export PATH=${PATH}:\${HOME}/.dotnet >> ${shell_rc} ;
  #  fi ;
  #fi
}

_prep_lang_scm() {
  echo "Configuring for Scheme language ..." >> /dev/stderr ; sleep 3
  mkdir -p ${PREFIX}/share/scheme-r7rs/sitelib
}

_prep_lang_hs() {
  echo "Configuring for Haskell language ..." >> /dev/stderr ; sleep 3
  RESOLVER=${RESOLVER:-lts-18.10}

  mkdir -p ${HOME}/.stack/global-project
  if ! grep -q -E "system-ghc" ${HOME}/.stack/config.yaml ; then
    cat << EOF >> ${HOME}/.stack/config.yaml ;
templates:
    params: null
system-ghc: true
#allow-newer: true
extra-include-dirs: [${PREFIX}/include]
extra-lib-dirs: [${PREFIX}/lib]
EOF
  fi
  echo "NOTE: Update/fix (as needed) ${HOME}/.stack/config.yaml" >> /dev/stderr ;
  sleep 2 ; ${EDITOR} ${HOME}/.stack/config.yaml
  if ! grep -q -E "resolver:" ${HOME}/.stack/global-project/stack.yaml ; then
    cat << EOF >> ${HOME}/.stack/global-project/stack.yaml ;
packages: []
resolver: ${RESOLVER}
EOF
  fi
  #outside of project
  stack --resolver ${RESOLVER} update ; stack --resolver ${RESOLVER} setup
}

_prep_lang_lisp() {
  LISP=${LISP:-sbcl}
  echo "Configuring for Common Lisp language ..." >> /dev/stderr ; sleep 3
  mkdir -p ${HOME}/Downloads ; cd ${HOME}/Downloads
  # www.quicklisp.org/beta
  curl -LO https://beta.quicklisp.org/quicklisp.lisp
  curl -LO https://beta.quicklisp.org/quicklisp.lisp.asc
  curl -LO https://beta.quicklisp.org/release-key.txt
  gpg --import release-key.txt ; gpg --verify quicklisp.lisp.asc quicklisp.lisp
  # [sbcl | clisp]
  if [ "clisp" = "${LISP}" ] ; then
    echo "${LISP} -i quicklisp.lisp" ;
    echo "  * (quicklisp-quickstart:install)" ;
    echo '  * (load "~/quicklisp/setup.lisp")' ;
    echo "  * (ql:add-to-init-file)" ;
    sleep 5 ; ${LISP} -i quicklisp.lisp ;
  else
    echo "${LISP} --load quicklisp.lisp" ;
    echo "  * (quicklisp-quickstart:install)" ;
    echo '  * (load "~/quicklisp/setup.lisp")' ;
    echo "  * (ql:add-to-init-file)" ;
    sleep 5 ; ${LISP} --load quicklisp.lisp ;
  fi
}

_prep_lang_ml() {
  echo "Configuring for OCaml language ..." >> /dev/stderr ; sleep 3
  opam init ; opam switch create ${OCAMLVER:-4.05.0} ; eval `opam env`
  #cp -a `which camlp4of | xargs dirname`/camlp4* ${HOME}/.opam/default/bin/

  #opam install pcre[.7.2.3] dune[.1.11.4] bisect odoc ounit2 qcheck \
  #  ocaml-inifiles yojson ezjsonm ctypes ctypes-foreign batteries volt
}

_prep_lang_go() {
  echo "Configuring for Go language ..." >> /dev/stderr ; sleep 3
  mkdir -p ${HOME}/go/src/${VCSHOST:-bitbucket.org}/${VCSUSER:-imcomputer}
}

_prep_lang_rs() {
  echo "Configuring for Rust language ..." >> /dev/stderr ; sleep 3
  echo "TBD: No config steps needed, as yet." >> /dev/stderr ; sleep 3
}

_prep_lang_rb() {
  echo "Configuring for Ruby language ..." >> /dev/stderr ; sleep 3
  #echo "TBD: No config steps needed, as yet." >> /dev/stderr ; sleep 3
  if ! grep -q -E ":ipv4_fallback_enabled:" ${HOME}/.gemrc ; then
    echo ':ipv4_fallback_enabled: true' >> ${HOME}/.gemrc ;
    echo '#:ssl_verify_mode: 0' >> ${HOME}/.gemrc ;
  fi
  gem install --user-install bundler
  if ! grep -q -E "GEM_HOME" ${shell_rc} ; then
    if grep -q -E "csh" "${SHELL}" ; then
      echo setenv GEM_HOME `ruby -e 'puts Gem.user_dir'` >> ${shell_rc} ;
      echo "set path = (${path} \${GEM_HOME}/bin)" >> ${shell_rc} ;
    else
      echo export GEM_HOME=`ruby -e 'puts Gem.user_dir'` >> ${shell_rc} ;
      echo export PATH=${PATH}:\${GEM_HOME}/bin >> ${shell_rc} ;
    fi
  fi
}

_prep_lang_swift() {
  ## note possible [x86_64|aarch64] versions: ${distro_ver:-distroN[-aarch64]}
  swift_ver=${swift_ver:-5.6} ; distro_ver=${distro_ver:-amazonlinux2}
  echo "(Linux) Configuring for Swift language ..." >> /dev/stderr ; sleep 3
  echo "See file ${0} to manually enter commands (if needed) ..." >> /dev/stderr ; sleep 3
  #echo "TBD: No config steps needed, as yet." >> /dev/stderr ; sleep 3
  #cd ${HOME}/Downloads
  #curl -LO https://download.swift.org/swift-${swift_ver}-release/${distro_ver}/swift-${swift_ver}-RELEASE/swift-${swift_ver}-RELEASE-${distro_ver}.tar.gz[.sig]
  #curl -Ls https://swift.org/keys/all-keys.asc | gpg --import -
  #gpg --keyserver hkp://keyserver.ubuntu.com --refresh-keys Swift
  #gpg --verify swift-${swift_ver}-RELEASE-${distro_ver}.tar.gz.sig
  #tar -xf swift-${swift_ver}-RELEASE-${distro_ver}.tar.gz -C ${HOME}/.local
  #if ! grep -q -E "SWIFT_ROOT" ${shell_rc} ; then
  #  if grep -q -E "csh" "${SHELL}" ; then
  #    echo "?? Currently incompatible w/ FreeBSD" >> /dev/stderr ; sleep 3 ;
  #    #echo setenv SWIFT_ROOT \${HOME}/.local/swift-${swift_ver}-RELEASE-${distro_ver} >> ${shell_rc} ;
  #    #echo "set path = (\${SWIFT_ROOT}/usr/bin ${path})" >> ${shell_rc} ;
  #  else
  #    echo export SWIFT_ROOT=\${HOME}/.local/swift-${swift_ver}-RELEASE-${distro_ver} >> ${shell_rc} ;
  #    echo export PATH=\${SWIFT_ROOT}/usr/bin:${PATH} >> ${shell_rc} ;
  #  fi ;
  #fi

  ## swift --version ---> Swift version ${swift_ver}  OR  fix errors
  ## check shared object depns errors:
  ##   (example) ldd `which swift-build` | grep -e 'not found' --->
  ##      libtinfo.so.5 => not found
  ##      libncurses.so.5 => not found
  ##   (Void Linux possible example fixes)
  ##      sudo ln -s /usr/lib/libncursesw.so.6.3 /usr/lib/libtinfo.so.5
  ##      sudo ln -s /usr/lib/libncurses.so.6.3 /usr/lib/libncurses.so.5
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
