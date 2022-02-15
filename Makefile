SHELL = bash -eo pipefail
GNU_SED := $(shell command -v gsed || command -v sed)
PREFIX ?= /usr

all:
	@echo -n "Building Nextshot... "
	@cat src/main.bash src/_*.bash | \
		$(GNU_SED) -e '/^source ".*\.bash"$$/,+1d' \
			-e '/^main "$$@"$$/{H;d};$${p;x;s/^\n//}' \
			-e '/^\(SCRIPT_ROOT=\|$$\)/d' \
		> nextshot
	@chmod +x nextshot && echo "Done!"

install:
	@echo "Preparing package structure"
	@mkdir -vp "$(DESTDIR)$(PREFIX)/bin"
	@mkdir -vp "$(DESTDIR)$(PREFIX)/share/pixmaps"
	@echo "Installing Nextshot..."
	@cp -v resources/icons/16x16.png "$(DESTDIR)$(PREFIX)/share/pixmaps/nextshot-16x16.png"
	@cp -vp nextshot.sh "$(DESTDIR)$(PREFIX)/bin/nextshot"
	@echo "Install complete"

uninstall:
	@echo "Uninstalling Nextshot..."
	@rm -vf "$(DESTDIR)$(PREFIX)/bin/nextshot"
	@rm -vf "$(DESTDIR)$(PREFIX)/share/pixmaps/nextshot-16x16.png"
	@echo "Uninstall complete"
