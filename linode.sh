#!/bin/bash

# <udf name="sys_hostname" label="Hostname" />
# <udf name="deploy_password" label="Deploy User Password" />
# <udf name="my_ssh_public_key" label="Your SSH Public Key" />
# <udf name="ruby" label="Ruby to Install" oneOf="ree,ruby-1.8.7,ruby-1.9.2,jruby,rbx" default="ruby-1.9.2" />
# <udf name="persistence" label="Persistence" manyOf="MySQL,PostgreSQL,MongoDB,Redis,CouchDB" example="All but MySQL are not yet implemented" default="MySQL" />
# <udf name="servers" label="Servers" manyOf="Apache,nginx,node.js" example="None of these are implemented" />

function system_install_logrotate {
  apt-get -y install logrotate
}

function rvm_install {
  # $1 - username
  RVM_USER=$1
  apt-get -y install build-essential bison openssl libreadline5 libreadline-dev curl git-core zlib1g zlib1g-dev libssl-dev libsqlite3-0 libsqlite3-dev sqlite3 libxml2-dev
  AS_USER="sudo -u $RVM_USER -i"
  $AS_USER 'bash < <( curl http://rvm.beginrescueend.com/releases/rvm-install-head )'
  $AS_USER "sed -i -e 's/^\[ -z \"\$PS1\" \] && return$/if [[ -n \"\$PS1\" ]]; then/' .bashrc && echo 'fi' >> .bashrc"
  $AS_USER "echo '[[ -s \"\$HOME/.rvm/scripts/rvm\" ]] && . \"\$HOME/.rvm/scripts/rvm\"' >> .bashrc"
}

function rvm_default_ruby {
  # $1 - username
  # $2 - ruby
  RVM_USER=$1
  THE_RUBY=$2
  AS_USER="sudo -u $RVM_USER -i"
  $AS_USER "rvm install $THE_RUBY"
  $AS_USER "rvm --default $THE_RUBY"
}

exec &> /root/stackscript.log
source <ssinclude StackScriptID="1">
source <ssinclude StackScriptID="123">
system_update

system_add_user deploy $DEPLOY_PASSWORD "users,sudo"
system_user_add_ssh_key deploy "$MY_SSH_PUBLIC_KEY"

goodstuff

source <ssinclude StackScriptID="123"> #lib-system-ubuntu
system_enable_universe
system_security_ufw_install
system_security_ufw_configure_basic
system_update_locale_en_US_UTF_8
system_install_logrotate

system_sshd_permitrootlogin No
system_sshd_passwordauthentication No
system_sshd_pubkeyauthentication Yes

/etc/init.d/ssh restart

system_update_hostname "$SYS_HOSTNAME"

rvm_install deploy
rvm_default_ruby deploy "$RUBY"
