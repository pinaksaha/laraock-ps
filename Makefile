# Convenience targets. Run from the docker/ directory.
# Use APP=<name> to target a specific Laravel app.

APP ?= app1
DC  := docker compose

.PHONY: help up down restart build rebuild logs ps shell php-shell mysql-shell redis-shell artisan composer test new-app

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

up: ## Start the stack (nginx, php, mysql, redis)
	$(DC) up -d

up-workers: ## Start the stack including queue + scheduler
	$(DC) --profile workers up -d

up-tools: ## Start the stack including phpMyAdmin
	$(DC) --profile tools up -d

down: ## Stop and remove containers
	$(DC) down

down-volumes: ## Stop and remove containers + volumes (DESTROYS DB DATA)
	$(DC) down -v

restart: ## Restart all services
	$(DC) restart

build: ## Build images
	$(DC) build

rebuild: ## Build images without cache
	$(DC) build --no-cache

logs: ## Tail logs from all services
	$(DC) logs -f --tail=200

ps: ## Show service status
	$(DC) ps

shell: php-shell ## Alias for php-shell

php-shell: ## Open a bash shell in the php container as www-data
	$(DC) exec php bash

mysql-shell: ## Open a mysql client shell
	$(DC) exec mysql sh -c 'mysql -uroot -p"$$MYSQL_ROOT_PASSWORD"'

redis-shell: ## Open a redis-cli shell
	$(DC) exec redis redis-cli

artisan: ## Run an artisan command for $(APP). Usage: make artisan APP=app1 ARGS="migrate --seed"
	$(DC) exec -w /var/www/apps/$(APP) php php artisan $(ARGS)

composer: ## Run composer for $(APP). Usage: make composer APP=app1 ARGS="install"
	$(DC) exec -w /var/www/apps/$(APP) php composer $(ARGS)

test: ## Run pest/phpunit for $(APP)
	$(DC) exec -w /var/www/apps/$(APP) php php artisan test

new-app: ## Scaffold a new Laravel app at apps/$(APP) via composer create-project
	@if [ -d "../apps/$(APP)" ]; then \
		echo "apps/$(APP) already exists. Aborting."; exit 1; \
	fi
	$(DC) exec -w /var/www/apps php composer create-project laravel/laravel $(APP)
	@echo ""
	@echo "Created apps/$(APP). Next steps:"
	@echo "  1. cp nginx/sites/_template.conf.example nginx/sites/$(APP).conf and edit it."
	@echo "  2. Add the database name to MYSQL_MULTIPLE_DATABASES in .env (or create it manually)."
	@echo "  3. In apps/$(APP)/.env set DB_HOST=mysql, REDIS_HOST=redis."
	@echo "  4. make restart"
