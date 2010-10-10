#!/bin/bash

# <udf name="sys_hostname" label="Hostname" />
# <udf name="project_name" label="Project Name" example="Will be used to name folders and files" />
# <udf name="deploy_password" label="Non-root Password" example="Non-root password for all services and users" />
# <udf name="my_ssh_public_key" label="Your SSH Public Key" example="REQUIRED! try `cat ~/.ssh/id_rsa.pub | pbcopy`" />
# <udf name="ruby" label="Ruby to Install" oneOf="ree,ruby-1.8.7,ruby-1.9.2,jruby,rbx" default="ruby-1.9.2" />
# <udf name="persistence" label="Persistence" manyOf="MySQL,MongoDB" default="MySQL,MongoDB" />
# <udf name="servers" label="Servers" manyOf="nginx,node.js" example="node.js is not implemented" />

function split {
  echo $(echo $1 | tr "," "\n")
}

function system_install_logrotate {
  apt-get -y install logrotate
}

function rvm_install {
  # $1 - username
  RVM_USER=$1
  apt-get -y install build-essential bison openssl libreadline5 libreadline5-dev curl git-core zlib1g zlib1g-dev libssl-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev
  AS_USER="sudo -u $RVM_USER -i --"
  $AS_USER 'bash < <( curl http://rvm.beginrescueend.com/releases/rvm-install-head )'
  $AS_USER "sed -i -e 's/^\[ -z \"\$PS1\" \] && return$/if [[ -n \"\$PS1\" ]]; then/' .bashrc && echo 'fi' >> .bashrc"
  $AS_USER "echo '[[ -s \"\$HOME/.rvm/scripts/rvm\" ]] && . \"\$HOME/.rvm/scripts/rvm\"' >> .bashrc"
}

function rvm_default_ruby {
  # $1 - username
  # $2 - ruby
  RVM_USER=$1
  THE_RUBY=$2
  AS_USER="sudo -u $RVM_USER -i --"
  $AS_USER "rvm install $THE_RUBY"
  $AS_USER "rvm --default $THE_RUBY"
}

function rvm_setup_project {
  # $1 - username
  # $2 - project_name
  AS_USER="sudo -u $1 -i --"
  PROJ=$2
  echo "Installing Phusion Passenger"
  $AS_USER "rvm gemset create $PROJ && rvm gemset use $PROJ && gem install --pre passenger"
  $AS_USER "mkdir ~/${PROJ}"
  $AS_USER "echo 'rvm gemset use $PROJ' > ~/${PROJ}/.rvmrc"
  $AS_USER "rvm rvmrc trust ~/${PROJ}"
}

function rvm_setup_project_with_nginx {
  # $1 - username
  # $2 - project_name
  USERNAME=$1
  PROJ=$2
  AS_USER="sudo -u $USERNAME -i --"

  apt-get install -y zlib1g-dev libcurl4-openssl-dev
  mkdir /opt/nginx
  chown $USERNAME:$USERNAME /opt/nginx
  echo "Installing Phusion Passenger for nginx"
  $AS_USER "cd $PROJ && passenger-install-nginx-module --auto --prefix=/opt/nginx --auto-download --extra-configure-flags=--with-http_ssl_module"
  curl http://github.com/ivanvanderbyl/rails-nginx-passenger-ubuntu/raw/master/nginx/nginx -o /etc/init.d/nginx && chmod +x /etc/init.d/nginx
  /etc/init.d/nginx start
  /usr/sbin/update-rc.d -f nginx defaults
}

function mongodb_install {
  echo "deb http://downloads.mongodb.org/distros/ubuntu 10.4 10gen" >> /etc/apt/sources.list
  apt-key adv --keyserver keyserver.ubuntu.com --recv 7F0CEB10
  aptitude update
  apt-get install -y mongodb-stable
}

exec &> /root/stackscript.log
source <ssinclude StackScriptID="1">
system_update

source <ssinclude StackScriptID="123">
system_add_user deploy $DEPLOY_PASSWORD "users,sudo"
system_user_add_ssh_key deploy "$MY_SSH_PUBLIC_KEY"

# stackscript 1
goodstuff

# stackscript 123
system_enable_universe
system_security_ufw_install
system_security_ufw_configure_basic
system_update_locale_en_US_UTF_8
system_sshd_permitrootlogin No
system_sshd_passwordauthentication No
system_sshd_pubkeyauthentication Yes
/etc/init.d/ssh restart
system_update_hostname "$SYS_HOSTNAME"

if [[ -n "$(echo $PERSISTENCE | grep 'MySQL')" ]]; then
  mysql_install "$DEPLOY_PASSWORD"
  mysql_tune 30
fi

if [[ -n "$(echo $PERSISTENCE | grep 'MongoDB')" ]]; then
  mongodb_install
fi

system_install_logrotate

rvm_install deploy
rvm_default_ruby deploy "$RUBY"

rvm_setup_project deploy "$PROJECT_NAME"
rvm_setup_project_with_nginx deploy "$PROJECT_NAME"
