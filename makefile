# makefile

#
# Patches/Installs/Builds DSDT patches for Lenovo y50-70
#
# Created by RehabMan 
#

# set build products
BUILDDIR=./build
AML_PRODUCTS=$(BUILDDIR)/SSDT-HACK.aml
PRODUCTS=$(AML_PRODUCTS)

IASLFLAGS=-vw 2095 -vw 2146
IASL=iasl

.PHONY: all
all: $(PRODUCTS)

$(BUILDDIR)/SSDT-HACK.aml: SSDT-HACK.dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

.PHONY: clean
clean:
	rm -f $(BUILDDIR)/*.dsl $(BUILDDIR)/*.aml

