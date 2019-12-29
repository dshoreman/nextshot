PREFIX ?= /usr

all:
	@echo "To install Nextshot, run 'make install'."

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
