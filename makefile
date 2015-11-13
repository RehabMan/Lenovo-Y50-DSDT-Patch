# makefile

#
# Patches/Installs/Builds DSDT patches for Lenovo y50-70
#
# Created by RehabMan 
#

BUILDDIR=./build
RESOURCES=./Resources_ALC283
HDAINJECT=AppleHDA_ALC283.kext
HDALAYOUT=layout3
USBINJECT=USBXHC_y50.kext
BACKLIGHTINJECT=AppleBacklightInjector.kext

VERSION_ERA=$(shell ./print_version.sh)
ifeq "$(VERSION_ERA)" "10.10-"
	INSTDIR=/System/Library/Extensions
else
	INSTDIR=/Library/Extensions
endif
SLE=/System/Library/Extensions

# set build products
PRODUCTS=$(BUILDDIR)/SSDT-HACK.aml

IASLFLAGS=-vw 2095
IASL=iasl

.PHONY: all
all: $(PRODUCTS) $(HDAINJECT)

$(BUILDDIR)/SSDT-HACK.aml: ./SSDT-HACK.dsl
	$(IASL) $(IASLFLAGS) -p $@ $<

.PHONY: clean
clean:
	rm -f $(BUILDDIR)/*.dsl $(BUILDDIR)/*.aml

# Clover Install
.PHONY: install
install: $(PRODUCTS)
	$(eval EFIDIR:=$(shell sudo ./mount_efi.sh /))
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-HACK.aml
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/DSDT.aml
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-1.aml
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-2.aml
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-3.aml
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-4.aml
	rm -f $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-9.aml
	cp $(BUILDDIR)/SSDT-HACK.aml $(EFIDIR)/EFI/CLOVER/ACPI/patched/SSDT-HACK.aml

$(HDAINJECT): $(RESOURCES)/ahhcd.plist $(RESOURCES)/layout/Platforms.xml.zlib $(RESOURCES)/layout/$(HDALAYOUT).xml.zlib ./patch_hda.sh
	./patch_hda.sh
	touch $@

$(RESOURCES)/layout/Platforms.xml.zlib: $(RESOURCES)/layout/Platforms.plist $(SLE)/AppleHDA.kext/Contents/Resources/Platforms.xml.zlib
	./tools/zlib inflate $(SLE)/AppleHDA.kext/Contents/Resources/Platforms.xml.zlib >/tmp/rm_Platforms.plist
	/usr/libexec/plistbuddy -c "Delete ':PathMaps'" /tmp/rm_Platforms.plist
	/usr/libexec/plistbuddy -c "Merge $(RESOURCES)/layout/Platforms.plist" /tmp/rm_Platforms.plist
	./tools/zlib deflate /tmp/rm_Platforms.plist >$@

$(RESOURCES)/layout/$(HDALAYOUT).xml.zlib: $(RESOURCES)/layout/$(HDALAYOUT).plist
	./tools/zlib deflate $< >$@

$(BACKLIGHTINJECT): Backlight.plist patch_backlight.sh
	./patch_backlight.sh
	touch $@

.PHONY: update_kernelcache
update_kernelcache:
	sudo touch $(SLE)
	sudo kextcache -update-volume /

.PHONY: install_hda
install_hda:
	sudo rm -Rf $(INSTDIR)/$(HDAINJECT)
	sudo cp -R ./$(HDAINJECT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(INSTDIR)/$(HDAINJECT); fi
	make update_kernelcache

.PHONY: install_usb
install_usb:
	sudo rm -Rf $(INSTDIR)/$(USBINJECT)
	sudo cp -R ./$(USBINJECT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(INSTDIR)/$(USBINJECT); fi
	make update_kernelcache

.PHONY: install_backlight
install_backlight:
	sudo rm -Rf $(INSTDIR)/$(BACKLIGHTINJECT)
	sudo cp -R ./$(BACKLIGHTINJECT) $(INSTDIR)
	if [ "`which tag`" != "" ]; then sudo tag -a Blue $(INSTDIR)/$(BACKLIGHTINJECT); fi
	make update_kernelcache

