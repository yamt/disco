export

DISCO_VERSION = 0.4.1
DISCO_RELEASE = 0.4.1

# standard make installation variables
sysconfdir    = /etc
prefix        = /usr/local
exec_prefix   = $(prefix)
localstatedir = $(prefix)/var
datarootdir   = $(prefix)/share
datadir       = $(datarootdir)
bindir        = $(exec_prefix)/bin
libdir        = $(exec_prefix)/lib

SHELL           = /bin/sh
INSTALL         = /usr/bin/install -c
INSTALL_PROGRAM = $(INSTALL)
INSTALL_DATA    = $(INSTALL) -m 644
INSTALL_TREE    = cp -r

# relative directory paths
RELBIN = $(bindir)
RELLIB = $(libdir)/disco
RELDAT = $(datadir)/disco
RELCFG = $(sysconfdir)/disco
RELSRV = $(localstatedir)/disco

# installation directories
TARGETBIN = $(DESTDIR)$(bindir)
TARGETLIB = $(DESTDIR)$(libdir)/disco
TARGETDAT = $(DESTDIR)$(datadir)/disco
TARGETCFG = $(DESTDIR)$(sysconfdir)/disco
TARGETSRV = $(DESTDIR)$(localstatedir)/disco

# options to python and sphinx for building the lib and docs
PYTHONENVS = DISCO_VERSION=$(DISCO_VERSION) DISCO_RELEASE=$(DISCO_RELEASE)
SPHINXOPTS = "-D version=$(DISCO_VERSION) -D release=$(DISCO_RELEASE)"

# used to choose which conf file will be generated
UNAME = $(shell uname)

# utilities used for building disco
DIALYZER   = dialyzer
TYPER      = typer
PYTHON     = python
PY_INSTALL = $(PYTHONENVS) $(PYTHON) setup.py install --root=$(DESTDIR)/ --prefix=$(prefix) $(PY_INSTALL_OPTS)

WWW   = master/www
EBIN  = master/ebin
ESRC  = master/src
EDEP  = master/deps

DEPS     = mochiweb lager
EDEPS    = $(foreach dep,$(DEPS),$(EDEP)/$(dep)/ebin)
ELIBS    = $(ESRC) $(ESRC)/ddfs
ESOURCES = $(foreach lib,$(ELIBS),$(wildcard $(lib)/*.erl))

EPLT  = .dialyzer_plt

.PHONY: master clean test \
	contrib \
	dep dep-clean \
	debian debian-clean \
	doc doc-clean doc-test
.PHONY: install uninstall \
	install-core \
	install-discodb \
	install-examples \
	install-master \
	install-node \
	install-tests
.PHONY: dialyzer dialyzer-clean typer

master: dep
	@ (cd master && ./rebar compile)

clean:
	@ (cd master && ./rebar clean)
	- rm -Rf lib/build lib/disco.egg-info

test:
	@ (cd master && ./rebar -C eunit.config get-deps eunit)

contrib:
	git submodule init
	git submodule update

dep:
	@ (cd master && ./rebar get-deps)

dep-clean:
	- rm -Rf master/deps

debian:
	$(MAKE) -C pkg/debian

debian-clean:
	$(MAKE) -C pkg/debian clean

doc:
	$(MAKE) -C doc html

doc-clean:
	$(MAKE) -C doc clean

doc-test:
	$(MAKE) -C doc doctest

install: install-core install-node install-master

uninstall:
	- rm -f  $(TARGETBIN)/disco $(TARGETBIN)/ddfs
	- rm -Rf $(TARGETLIB) $(TARGETDAT)
	- rm -Ri $(TARGETCFG) $(TARGETSRV)

install-core:
	(cd lib && $(PY_INSTALL))

install-discodb: contrib
	$(MAKE) -C contrib/discodb install

install-examples: $(TARGETLIB)/examples

install-master: install-node \
	$(TARGETDAT)/$(WWW) \
	$(TARGETBIN)/disco $(TARGETBIN)/ddfs \
	$(TARGETCFG)/settings.py

install-node: master \
	$(TARGETLIB)/$(EBIN) \
	$(addprefix $(TARGETLIB)/,$(EDEPS)) \
	$(TARGETSRV)

install-tests: $(TARGETLIB)/ext $(TARGETLIB)/tests

dialyzer: $(EPLT) master
	$(DIALYZER) --get_warnings -Wunmatched_returns -Werror_handling --plt $(EPLT) -r $(EBIN)


dialyzer-clean:
	- rm -Rf $(EPLT)

typer: $(EPLT)
	$(TYPER) --plt $(EPLT) -r $(ESRC)

$(EPLT):
	$(DIALYZER) --build_plt --output_plt $(EPLT) \
		    --apps stdlib kernel erts mnesia compiler crypto inets xmerl ssl syntax_tools

$(TARGETDAT)/% $(TARGETLIB)/%: %
	$(INSTALL) -d $(@D)
	$(INSTALL_TREE) $< $(@D)

$(TARGETBIN)/%: bin/%
	$(INSTALL) -d $(@D)
	$(INSTALL_PROGRAM) $< $@

$(TARGETCFG)/settings.py:
	$(INSTALL) -d $(@D)
	(cd conf && ./gen.settings.sys-$(UNAME) > $@ && chmod 644 $@)

$(TARGETSRV):
	$(INSTALL) -d $@
