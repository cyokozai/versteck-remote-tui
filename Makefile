SHELL := /bin/bash

NAME       := versteck-remote-tui
PREFIX     ?= /usr/local
DESTDIR    ?=
VERSION    ?=
TEST_BASE  ?= ubuntu:26.04
TEST_IMAGE ?= versteck-remote-tui-test:local
DIST_DIR   ?= dist

LIBS    := $(wildcard lib/$(NAME)/*.sh)
SCRIPTS := bin/$(NAME) tests/fixtures/fake-backend $(wildcard tests/fixtures/bin/*) tests/test_helper.bash

.PHONY: test check lint unit install dist clean

# 手元の入口。テストはコンテナの中で回す（手元に gum・bats・jq を入れない）。
# 例: make test TEST_BASE=versteck-ci:local
test:
	docker build --build-arg BASE=$(TEST_BASE) -t $(TEST_IMAGE) -f Dockerfile.test .
	docker run --rm -v "$(CURDIR):/src" -w /src $(TEST_IMAGE) make check

# コンテナの中（CI を含む）で走らせる検査
check: lint unit

# lib の各ファイルは互いの変数を使うので、ファイル単位の「未使用の変数」(SC2034) だけは外す
lint:
	shellcheck -x $(SCRIPTS)
	shellcheck -x --exclude=SC2034 $(LIBS)

unit:
	bats tests

install:
	install -d "$(DESTDIR)$(PREFIX)/bin" "$(DESTDIR)$(PREFIX)/lib/$(NAME)" "$(DESTDIR)$(PREFIX)/share/doc/$(NAME)"
	install -m 0755 bin/$(NAME) "$(DESTDIR)$(PREFIX)/bin/$(NAME)"
	install -m 0644 lib/$(NAME)/*.sh "$(DESTDIR)$(PREFIX)/lib/$(NAME)/"
	install -m 0644 README.md LICENSE docs/*.md "$(DESTDIR)$(PREFIX)/share/doc/$(NAME)/"

# make dist VERSION=1.2.3 → dist/versteck-remote-tui-v1.2.3.tar.gz と dist/SHA256SUMS
dist:
	@[[ "$(VERSION)" =~ ^[0-9]+\.[0-9]+\.[0-9]+$$ ]] || { echo "VERSION=X.Y.Z を渡してください（v は付けない）" >&2; exit 2; }
	rm -rf "$(DIST_DIR)/$(NAME)-v$(VERSION)"
	mkdir -p "$(DIST_DIR)/$(NAME)-v$(VERSION)"
	cp -R bin lib docs LICENSE README.md "$(DIST_DIR)/$(NAME)-v$(VERSION)/"
	printf 'VRT_VERSION=%s\n' "$(VERSION)" >"$(DIST_DIR)/$(NAME)-v$(VERSION)/lib/$(NAME)/version.sh"
	tar -C "$(DIST_DIR)" --sort=name --owner=0 --group=0 --numeric-owner \
	  --mtime='1970-01-01 00:00:00Z' -cf - "$(NAME)-v$(VERSION)" | gzip -n >"$(DIST_DIR)/$(NAME)-v$(VERSION).tar.gz"
	rm -rf "$(DIST_DIR)/$(NAME)-v$(VERSION)"
	cd "$(DIST_DIR)" && sha256sum "$(NAME)-v$(VERSION).tar.gz" >SHA256SUMS

clean:
	rm -rf "$(DIST_DIR)"
