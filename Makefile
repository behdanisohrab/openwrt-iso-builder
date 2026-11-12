.PHONY: all iso test-vm test-headless test-boot clean help

all: iso

iso:
	./build.sh

test-vm:
	./test-vm.sh --interactive

test-curses:
	./test-vm.sh --curses

test-headless:
	./test-vm.sh --headless

test-boot:
	./test-vm.sh --boot-disk

clean:
	rm -rf .build dist /tmp/openwrt-test-vm.qcow2

help:
	@echo "OpenWrt VM Installer Build Targets:"
	@echo "  make iso            - Build the VM installer ISO image"
	@echo "  make test-vm        - Test installer ISO in QEMU (window GUI)"
	@echo "  make test-curses    - Test installer ISO in QEMU (terminal curses)"
	@echo "  make test-headless  - Run automated unattended test"
	@echo "  make test-boot      - Boot QEMU from installed VM disk"
	@echo "  make clean          - Remove build artifacts and temporary files"
