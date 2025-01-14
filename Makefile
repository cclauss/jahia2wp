#!make
# Default values, can be overridden either on the command line of make
# or in .env
WP_ENV ?= your-env
WP_PORT_HTTP ?= 80
WP_PORT_HTTPS ?= 443
# Used to clean vEnv with name used by Travis because it is already used for 'generate-many' functional-tests locally
# and we have to clean this vEnv correctly for the test to execute correctly
WP_TRAVIS_TEST_ENV = 'test'

check-env:
ifeq ($(wildcard .env),)
	@echo "Please create your .env file first, from .env.sample"
	@exit 1
else
include .env
endif

_mgmt_container = $(shell docker ps -q --filter "label=ch.epfl.jahia2wp.mgmt.env=${WP_ENV}")
_httpd_container = $(shell docker ps -q --filter "label=ch.epfl.jahia2wp.httpd.env=${WP_ENV}")

test: check-env
# The "test-raw" target is in Makefile.mgmt
	docker exec --user=www-data $(_mgmt_container) make -C /srv/$$WP_ENV/jahia2wp test-raw

functional-tests: check-env
# The "functional-tests-raw" target is in Makefile.mgmt
# WP_ENV hardcoded to 'test'
	docker exec --user=www-data \
      -e HTTPD_CONTAINER=$(_httpd_container) \
      $(_mgmt_container) make -C /srv/$$WP_ENV/jahia2wp functional-tests-raw

vars: check-env
	@echo 'Environment-related vars:'
	@echo '  WP_ENV=${WP_ENV}'
	@echo '  _mgmt_container=${_mgmt_container}'
	@echo '  _httpd_container=${_httpd_container}'

	@echo ''
	@echo DB-related vars:
	@echo '  MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}'
	@echo '  MYSQL_DB_HOST=${MYSQL_DB_HOST}'
	@echo '  MYSQL_SUPER_USER=${MYSQL_SUPER_USER}'
	@echo '  MYSQL_SUPER_PASSWORD=${MYSQL_SUPER_PASSWORD}'

	@echo ''
	@echo 'Wordpress-related vars:'
	@echo '  WP_VERSION=${WP_VERSION}'
	@echo '  WP_ADMIN_USER=${WP_ADMIN_USER}'
	@echo '  WP_ADMIN_EMAIL=${WP_ADMIN_EMAIL}'
	@echo '  WP_PORT_HTTP=${WP_PORT_HTTP}'
	@echo '  WP_PORT_HTTPS=${WP_PORT_HTTPS}'

	@echo ''
	@echo 'WPManagement-related vars:'
	@echo '  WP_PORT_PHPMA=${WP_PORT_PHPMA}'
	@echo '  WP_PORT_SSHD=${WP_PORT_SSHD}'
	@echo '  PLUGINS_CONFIG_BASE_PATH=${PLUGINS_CONFIG_BASE_PATH}'

	@echo ''
	@echo 'Jahia-related vars:'
	@echo '  JAHIA_ZIP_PATH=${JAHIA_ZIP_PATH}'
	@echo '  JAHIA_USER=${JAHIA_USER}'
	@echo '  JAHIA_PASSWORD=${JAHIA_PASSWORD}'
	@echo '  JAHIA_HOST=${JAHIA_HOST}'

build: check-env
	docker build -t epflidevelop/os-wp-base ../wp-ops/docker/wp-base
	docker-compose build

up: build
	@WP_ENV=${WP_ENV} \
		MYSQL_DB_HOST=${MYSQL_DB_HOST} \
		MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
		WP_PORT_HTTP=${WP_PORT_HTTP} \
		WP_PORT_HTTPS=${WP_PORT_HTTPS} \
		docker-compose up -d

exec: check-env
	@docker exec --user www-data -it  \
	  -e WP_ENV=${WP_ENV} \
	  -e MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD} \
	  -e MYSQL_DB_HOST=${MYSQL_DB_HOST} \
	  $(_mgmt_container) bash -l

httpd: check-env
	@docker exec -it $(_httpd_container) bash -l

down: check-env
	@WP_PORT_HTTP=${WP_PORT_HTTP} \
	 WP_PORT_HTTPS=${WP_PORT_HTTPS} \
	 docker-compose down

bootstrap-local: build 
	[ -f .env ] || cp .env.sample .env
	[ -f etc/.bash_history ] || cp etc/.bash_history.sample etc/.bash_history
	sudo chown -R `whoami`:33 .
	sudo chmod -R g+w .
ifdef WP_ENV
	@echo "WP_ENV already set to $(WP_ENV)"
	make up
else
	echo " \
export WP_ENV=$(ENV)" >> ~/.bashrc
	WP_ENV=$(ENV) make up
endif
	@echo ""
	@echo "Done with your local env. You can now"
	@if test -z "${WP_ENV}"; then echo "    $ source ~/.bashrc (to update your environment with WP_ENV value)"; fi
	@echo "    $ make exec        (to connect into your container)"

clean: down
	@bin/clean.sh $(WP_ENV) ${WP_TRAVIS_TEST_ENV}

connect-OS:
	@oc login --token="$$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" --insecure-skip-tls-verify=true https://pub-os-exopge.epfl.ch:443

disconnect-OS:
	@oc logout

new-route: connect-OS
	@bin/new-route.sh -s httpd-$(WP_ENV) -h $(site) | oc -n wwp create -f -

delete-route: connect-OS
	@oc delete route httpd-$${site%%.*}

config-debugger:
	@echo "Copying SSH key..."
	@docker cp ~/.ssh/id_rsa.pub  $(_mgmt_container):/var/www/.ssh/authorized_keys
	@docker exec -it $(_mgmt_container) /bin/chmod 644 /var/www/.ssh/authorized_keys
	@docker exec -it $(_mgmt_container) /bin/chown www-data:www-data /var/www/.ssh/authorized_keys
