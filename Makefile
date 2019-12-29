PREFIX ?= /usr

all:
	@echo "To install Nextshot, run 'make install'."

install:
	@echo "Preparing package structure"
	@mkdir -vp "$(DESTDIR)$(PREFIX)/bin"
	@echo "Installing Nextshot..."
	@cp -vp nextshot.sh "$(DESTDIR)$(PREFIX)/bin/nextshot"
	@echo "Install complete"

uninstall:
	@echo "Uninstalling Nextshot..."
	@rm -vf "$(DESTDIR)$(PREFIX)/bin/nextshot"
	@echo "Uninstall complete"
