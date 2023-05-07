SHELL = bash -eo pipefail
GNU_SED := $(shell command -v gsed || command -v sed)
PREFIX ?= /usr

all:
	@echo -n "Building Nextshot... "
	@# Append safe files, strip empty lines and includes
	@cat src/main.bash src/_[a-z]*.bash | $(GNU_SED) -e \
		'/^\($$\|source ".*\.bash"$$\|SCRIPT_ROOT=\)/d' > nextshot
	@# Append special files, retaining blank lines
	@cat src/__*.bash >> nextshot
	@# Move 'main' call to the end of the script
	@$(GNU_SED) -i -e '/^main "$$@"$$/{H;d};$${p;x}' nextshot
	@chmod +x nextshot && echo "Done!"

install:
	@echo "Preparing package structure"
	@mkdir -vp "$(DESTDIR)$(PREFIX)/bin"
	@mkdir -vp "$(DESTDIR)$(PREFIX)/share/pixmaps"
	@echo "Installing Nextshot..."
	@cp -v resources/icons/16x16.png "$(DESTDIR)$(PREFIX)/share/pixmaps/nextshot-16x16.png"
	@cp -vp nextshot "$(DESTDIR)$(PREFIX)/bin/nextshot"
	@echo "Install complete"

uninstall:
	@echo "Uninstalling Nextshot..."
	@rm -vf "$(DESTDIR)$(PREFIX)/bin/nextshot"
	@rm -vf "$(DESTDIR)$(PREFIX)/share/pixmaps/nextshot-16x16.png"
	@echo "Uninstall complete"
