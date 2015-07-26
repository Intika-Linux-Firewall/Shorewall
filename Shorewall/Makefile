# Shorewall Makefile to restart if config-files are newer than last restart
VARDIR=$(shell /sbin/shorewall show vardir)
CONFDIR=/etc/shorewall
RESTOREFILE?=firewall

all: $(VARDIR)/$(RESTOREFILE)

$(VARDIR)/$(RESTOREFILE): $(CONFDIR)/*
	@/sbin/shorewall -q save >/dev/null; \
	if \
	    /sbin/shorewall -q reload >/dev/null 2>&1; \
	then \
	    /sbin/shorewall -q save >/dev/null; \
	else \
	    /sbin/shorewall -q restore 2>&1 | tail >&2; exit 1; \
	fi

clean:
	@rm -f $(CONFDIR)/*~ $(CONFDIR)/.*~

.PHONY: clean

# EOF
