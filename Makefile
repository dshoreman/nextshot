PREFIX ?= /usr

all:
	@echo "To install Nextshot, run 'make install'."

install:
	@echo "Preparing package structure"
	@mkdir -p "$(DESTDIR)$(PREFIX)/bin"

	@echo "Installing Nextshot..."
	@cp -p nextshot.sh "$(DESTDIR)$(PREFIX)/bin/nextshot"

uninstall:
	@echo "Uninstalling Nextshot..."
	@rm -v "$(DESTDIR)$(PREFIX)/bin/nextshot"
	@echo "Uninstall complete"
