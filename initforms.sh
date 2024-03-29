#!/bin/sh
MYDIR="$( /usr/bin/dirname $0 )"
MYPATH="$( /bin/realpath ${MYDIR} )"
HELPER="clonos_database"

. /etc/rc.conf

if [ -z "${cbsd_workdir}" ]; then
	echo "Error: CBSD workdir is not initialized"
	echo "Please init CBSD first, e.g:"
	echo "  env workdir=/usr/jails /usr/local/cbsd/sudoexec/initenv"
	echo
	exit 1
fi

workdir="${cbsd_workdir}"

set -e
. /usr/local/cbsd/cbsd.conf
. ${subr}
set +e

MYPATH="${moduledir}/forms.d/${HELPER}"
DBFILE="/var/db/clonos/clonos.sqlite"
SALT_FILE="/var/db/clonos/salt"

if [ ! -r ${SALT_FILE} ]; then
	SALT=$( /usr/bin/head -c 30 /dev/random | /usr/bin/uuencode -m - | /usr/bin/tail -n 2 | /usr/bin/head -n1 )
	echo ${SALT} > ${SALT_FILE}
	chmod 0440 ${SALT_FILE}
	chown www:cbsd ${SALT_FILE}
fi

# sys_helpers_list, jails_helper_wl
/usr/local/bin/cbsd ${miscdir}/updatesql ${DBFILE} ${MYPATH}/sys_helpers_list.schema sys_helpers_list
/usr/local/bin/cbsd ${miscdir}/updatesql ${DBFILE} ${MYPATH}/sys_helpers_list.schema jails_helpers_list
/usr/local/bin/cbsd ${miscdir}/updatesql ${DBFILE} ${MYPATH}/auth_user.schema auth_user
/usr/local/bin/cbsd ${miscdir}/updatesql ${DBFILE} ${MYPATH}/auth_list.schema auth_list

/usr/local/bin/sqlite3 ${DBFILE} << EOF
BEGIN TRANSACTION;
DELETE FROM sys_helpers_list;
INSERT INTO sys_helpers_list ( module ) VALUES ( "consul" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "redis" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "redminestandalone" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "memcached" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "ldapstandalone" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "php" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "postgresql" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "prometheus" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "rtorrent" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "wordpressstandalone" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "jenkins" );
INSERT INTO sys_helpers_list ( module ) VALUES ( "ldapize" );
COMMIT;

BEGIN TRANSACTION;
DELETE FROM jails_helpers_list;
INSERT INTO jails_helpers_list ( module ) VALUES ( "consul" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "redis" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "redminestandalone" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "memcached" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "ldapstandalone" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "php" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "postgresql" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "prometheus" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "rtorrent" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "wordpressstandalone" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "jrctl" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "users" );
INSERT INTO jails_helpers_list ( module ) VALUES ( "ldapize" );
COMMIT;
EOF

admin_user=$( /usr/local/bin/sqlite3 ${DBFILE} "SELECT username FROM auth_user" 2>/dev/null )


if [ -z "${admin_user}" ]; then
	SALT=$( cat ${SALT_FILE} |awk '{printf $1}' )
	echo "Add new admin user: admin/admin with salt: ${SALT}"
	echo ${SALT} > ${SALT_FILE}
	password="admin"
	hash1=$( sha256 -qs "${password}" )
	hash2="${hash1}${SALT}"
	salted_hash=$( sha256 -qs "${hash2}" )

/usr/local/bin/sqlite3 ${DBFILE} << EOF
BEGIN TRANSACTION;
INSERT INTO auth_user ( username,password,first_name,last_name,is_active ) VALUES ( "admin", "${salted_hash}", "Admin", "Admin", 1 );
COMMIT;
EOF
fi

chown www:www ${DBFILE}
