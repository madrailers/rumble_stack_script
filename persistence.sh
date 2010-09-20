#!/bin/bash

# This entire file is currently a big ol' TODO.

function postgresql_install {
  apt-get -y install postgresql
}

function postgresql_tune {
    # Tunes postgresql's memory usage to utilize the percentage of memory you specify, defaulting to 40%

    # $1 - the percent of system memory to allocate towards postgresql

    if [ ! -n "$1" ];
        then PERCENT=40
        else PERCENT="$1"
    fi

    # sed -i -e 's/^#skip-innodb/skip-innodb/' /etc/mysql/my.cnf # disable innodb - saves about 100M

    MEM=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo) # how much memory in MB this system has
    PGMEM=$((MEM*PERCENT/100)) # how much memory we'd like to tune postgresql with
    PGMEMCHUNKS=$((PGMEM/4)) # how many 4MB chunks we have to play with

    # postgresql config options we want to set to the percentages in the second list, respectively
    # OPTLIST=(key_buffer sort_buffer_size read_buffer_size read_rnd_buffer_size myisam_sort_buffer_size query_cache_size)
    # DISTLIST=(75 1 1 1 5 15)

    # for opt in ${OPTLIST[@]}; do
        # sed -i -e "/\[mysqld\]/,/\[.*\]/s/^$opt/#$opt/" /etc/mysql/my.cnf
    # done

    # for i in ${!OPTLIST[*]}; do
        # val=$(echo | awk "{print int((${DISTLIST[$i]} * $MYMEMCHUNKS/100))*4}")
        # if [ $val -lt 4 ]
            # then val=4
        # fi
        # config="${config}\n${OPTLIST[$i]} = ${val}M"
    # done

    # sed -i -e "s/\(\[mysqld\]\)/\1\n$config\n/" /etc/mysql/my.cnf

    /etc/init.d/postgresql restart
}

function postgresql_create_database {
    # $1 - the postgresql root password
    # $2 - the db name to create

    if [ ! -n "$1" ]; then
        echo "postgresql_create_database() requires the root pass as its first argument"
        return 1;
    fi
    if [ ! -n "$2" ]; then
        echo "postgresql_create_database() requires the name of the database as the second argument"
        return 1;
    fi

    psql -c "CREATE DATABASE $2;" template1
}

function postgresql_create_user {
}

function postgresql_grant_user {
}

function mongodb_install {
}

function mongodb_tune {
}

function mongodb_create_database {
}

function mongodb_create_user {
}

function mongodb_grant_user {
}

function redis_install {
}

function redis_tune {
}

function redis_create_database {
}

function redis_create_user {
}

function redis_grant_user {
}

function couchdb_install {
}

function couchdb_tune {
}

function couchdb_create_database {
}

function couchdb_create_user {
}

function couchdb_grant_user {
}

function mysql_tune {
}

function mysql_create_database {
}

function mysql_create_user {
    # $1 - the mysql root password
    # $2 - the user to create
    # $3 - their password

    if [ ! -n "$1" ]; then
        echo "mysql_create_user() requires the root pass as its first argument"
        return 1;
    fi
    if [ ! -n "$2" ]; then
        echo "mysql_create_user() requires username as the second argument"
        return 1;
    fi
    if [ ! -n "$3" ]; then
        echo "mysql_create_user() requires a password as the third argument"
        return 1;
    fi
    echo "CREATE USER '$2'@'localhost' IDENTIFIED BY '$3';" | mysql -u root -p$1
}
function mysql_grant_user {

