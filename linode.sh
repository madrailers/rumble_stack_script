#!/bin/bash

# <udf name="sys_hostname" label="Hostname" />
# <udf name="project_name" label="Project Name" example="Will be used to name folders and files" />
# <udf name="deploy_password" label="Non-root Password" example="Non-root password for all services and users" />
# <udf name="my_ssh_public_key" label="Your SSH Public Key" example="REQUIRED! try `cat ~/.ssh/id_rsa.pub | pbcopy`" />
# <udf name="ruby" label="Ruby to Install" oneOf="ree,ruby-1.8.7,ruby-1.9.2,jruby,rbx" default="ruby-1.9.2" />
# <udf name="persistence" label="Persistence" manyOf="MySQL,PostgreSQL,MongoDB,Redis,CouchDB" example="All but MySQL are not yet implemented" default="MySQL" />
# <udf name="servers" label="Servers" manyOf="Apache,nginx,node.js" example="None of these are implemented" />

function split {
  echo $(echo $1 | tr "," "\n")
}

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

function rvm_setup_project {
  # $1 - username
  # $2 - project_name
  AS_USER="sudo -u $1 -i"
  PROJ=$2
  $AS_USER "rvm gemset create $PROJ && rvm gemset use $PROJ && gem install --pre passenger"
}

# function rvm_setup_project_with_apache {
#   # $1 - username
#   # $2 - project_name
#   AS_USER="sudo -u $1 -i"
#   PROJ="$2"
#   $AS_USER "rvm gemset use $PROJ && passenger-install-apache2-module"
# }

function rvm_setup_project_with_nginx {
  # $1 - username
  # $2 - project_name
  USERNAME=$1
  PROJ=$2
  AS_USER="sudo -u $USERNAME -i"
  apt-get install -y libcurl4-openssl-dev
  mkdir /opt/nginx
  chown $USERNAME:$USERNAME /opt/nginx
  $AS_USER "rvm gemset create $PROJ
  $AS_USER "rvm gemset use $PROJ && passenger-install-nginx-module --auto --prefix=/opt/nginx --auto-download --extra-configure-flags=--with-http_ssl_module"
  curl http://github.com/ivanvanderbyl/rails-nginx-passenger-ubuntu/raw/master/nginx/nginx -o /etc/init.d/nginx && chmod +x /etc/init.d/nginx
  /etc/init.d/nginx start
  /usr/sbin/update-rc.d -f nginx defaults
}

function normalize_mem_users {
  # $1 - comma-separated persistence engines
  # $2 - comma-separated servers
  filename="/home/deploy/normalize_mem_users.sh"
  AS_USER="sudo -u deploy -i"

  cat > ~deploy/normalize_mem_users.rb << EOF
tuners = {
  'MySQL' => 'mysql_tune',
  'Apache' => 'apache_tune'
}

mem_users = '$1'.split(',') + '$2'.split(',')
balance = Hash.new(40)
balance['nginx'] = balance['node.js'] = 20

mem_users = mem_users.inject({}) {|memo, user| memo.merge(user => balance[user]) }
max_mem = 80.0
mem_scalar = max_mem / mem_users.values.inject(0){|m,v| m + v}
mem_users.each_key{|k| mem_users[k] *= mem_scalar }

File.open('$filename', 'w') do |f|
  mem_users.each do |k,v|
    if tuners[k]
      f.puts "#{tuners[k]} #{v}"
    end
  end
end

EOF
  chown deploy:deploy ~deploy/normalize_mem_users.rb

  $AS_USER "ruby ~deploy/normalize_mem_users.rb"
  source $filename
}

function install_persistence_and_servers {
  for service in $(split $1)
  do
    case $service in
      MySQL)
        mysql_install $DEPLOY_PASSWORD
        ;;
      PostgreSQL)
        # postgres_install $DEPLOY_PASSWORD
        ;;
      MongoDB)
        # mongodb_install $DEPLOY_PASSWORD
        ;;
      Redis)
        # redis_install $DEPLOY_PASSWORD
        ;;
      CouchDB)
        # couchdb_install
        ;;
      Apache)
        apache_install
        apache_virutalhost $SYS_HOSTNAME
        ;;
      nginx)
        # nginx needs passenger pre-installed. Skip here
        ;;
      node.js)
        # node_install
        ;;


MySQL,PostgreSQL,MongoDB,Redis,CouchDB
Apache,nginx,node.js
    esac
  done
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

system_install_logrotate

rvm_install deploy
rvm_default_ruby deploy "$RUBY"

install_persistence_and_servers $PERSISTENCE
install_persistence_and_servers $SERVERS
normalize_mem_users "$PERSISTENCE" "$SERVERS"

rvm_setup_project deploy "$PROJECT_NAME"
if [[ -n "$(echo $SERVERS | grep 'Apache')" ]]; then
  rvm_setup_project_with_apache deploy $PROJECT_NAME
fi
if [[ -n "$(echo $SERVERS | grep 'nginx')" ]]; then
  rvm_setup_project_with_nginx deploy $PROJECT_NAME
fi
