#!/bin/bash
set -eo pipefail
shopt -s nullglob
# logging functions
mysql_log() {
	local type="$1"; shift
	printf '%s [%s] [Entrypoint]: %s\n' "$(date --rfc-3339=seconds)" "$type" "$*"
}
mysql_note() {
	mysql_log Note "$@"
}
mysql_warn() {
	mysql_log Warn "$@" >&2
}
mysql_error() {
	mysql_log ERROR "$@" >&2
	exit 1
}

declare DATABASE_ALREADY_EXISTS
if [ -f "data/mysql/user.frm" ]; then
		DATABASE_ALREADY_EXISTS='true'
fi

_mysql_passfile() {
	# echo the password to the "file" the client uses
	# the client command will use process substitution to create a file on the fly
	# ie: --defaults-extra-file=<( _mysql_passfile )
	if [ '--dont-use-mysql-root-password' != "$1" ] && [ -n "$MYSQL_ROOT_PASSWORD" ]; then
		cat <<-EOF
			[client]
			password="${MYSQL_ROOT_PASSWORD}"
		EOF
	fi
}

docker_process_sql() {
	mysql_note "invoke sql"
	passfileArgs=()
	if [ '--dont-use-mysql-root-password' = "$1" ]; then
		passfileArgs+=( "$1" )
		shift
	fi
	# args sent in can override this db, since they will be later in the command
	if [ -n "$MYSQL_DATABASE" ]; then
		set -- --database="$MYSQL_DATABASE" "$@"
	fi

	bin/mysql --defaults-extra-file=<( _mysql_passfile "${passfileArgs[@]}") -uroot "$@"
}

docker_setup_db() {
	mysql_note "Setup db start..."
	local rootCreate=
	if [ -n "$MYSQL_ROOT_HOST" ] && [ "$MYSQL_ROOT_HOST" != 'localhost' ]; then
		# no, we don't care if read finds a terminating character in this heredoc
		# https://unix.stackexchange.com/questions/265149/why-is-set-o-errexit-breaking-this-read-heredoc-expression/265151#265151
		read -r -d '' rootCreate <<-EOSQL || true
			GRANT ALL ON *.* TO 'root'@'${MYSQL_ROOT_HOST}' WITH GRANT OPTION ;
		EOSQL
	fi
	local passwordSet=
	read -r -d '' passwordSet <<-EOSQL || true
			UPDATE mysql.user SET Password=PASSWORD('${MYSQL_ROOT_PASSWORD}') WHERE User='root';
		EOSQL
	docker_process_sql --dont-use-mysql-root-password --database=mysql <<-EOSQL
		-- What's done in this file shouldn't be replicated
		--  or products like mysql-fabric won't work
		SET @@SESSION.SQL_LOG_BIN=0;
		${rootCreate}
		FLUSH PRIVILEGES ;
		${passwordSet}
		GRANT ALL ON *.* TO 'root' WITH GRANT OPTION ;
		FLUSH PRIVILEGES ;
		DROP DATABASE IF EXISTS test ;
	EOSQL
	mysql_note "Setup db end."
}

docker_temp_server_start() {
	"$@" --skip-networking --socket="${SOCKET}" &
	mysql_note "Waiting for server startup"
	local i
		for i in {4..0}; do
		
			# only use the root password if the database has already been initializaed
			# so that it won't try to fill in a password file when it hasn't been set yet
			extraArgs=()
			if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
				extraArgs+=( '--dont-use-mysql-root-password' )
			fi
			sleep 10
			mysql_note "Waiting ..."
			if docker_process_sql "${extraArgs[@]}" --database=information_schema <<<'show databases' &> /dev/null; then
				break
			fi
		done
		if [ "$i" = 0 ]; then
			mysql_error "Unable to start server."
		fi
}

_main() {
	mysql_note "MYSQL_ROOT_HOST is:$MYSQL_ROOT_HOST"
	if [ -z "$DATABASE_ALREADY_EXISTS" ]; then
		scripts/mysql_install_db
		mysql_note "First time start DB."
		docker_temp_server_start "$@"
		mysql_note "First time start DB end."
		docker_setup_db
		if ! bin/mysqladmin --defaults-extra-file=<( _mysql_passfile ) shutdown -uroot -p$MYSQL_ROOT_PASSWORD; then
			mysql_error "Unable to shut down server."
		fi
	fi
	mysql_note "Start DB."
	exec "$@"
	mysql_note "Start DB end."
}

_main "$@"