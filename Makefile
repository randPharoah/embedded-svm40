drivers=svm40
clean_drivers=$(foreach d, $(drivers), clean_$(d))
release_drivers=$(foreach d, $(drivers), release/$(d)) release/svm40_arduino

.PHONY: FORCE all $(release_drivers) $(clean_drivers) style-check style-fix \
	    prepare

all: prepare $(drivers)

prepare: svm40/svm40_git_version.c

$(drivers): prepare
	cd $@ && $(MAKE) $(MFLAGS)

svm40/svm40_git_version.c: FORCE
	git describe --always --dirty | \
		awk 'BEGIN \
		{print "/* THIS FILE IS AUTOGENERATED */"} \
		{print "#include \"svm40_git_version.h\""} \
		{print "const char * SVM40_DRV_VERSION_STR = \"" $$0"\";"} \
		END {}' > $@ || echo "Can't update version, not a git repository"


$(release_drivers): prepare
	export rel=$@ && \
	export driver=$${rel#release/} && \
	export tag="$$(git describe --always --dirty)" && \
	export pkgname="$${driver}-$${tag}" && \
	export pkgdir="release/$${pkgname}" && \
	rm -rf "$${pkgdir}" && mkdir -p "$${pkgdir}" && \
	cp -r embedded-common/hw_i2c/ "$${pkgdir}" && \
	cp -r embedded-common/sw_i2c/ "$${pkgdir}" && \
	cp embedded-common/sensirion_arch_config.h "$${pkgdir}" && \
	cp embedded-common/sensirion_common.c "$${pkgdir}" && \
	cp embedded-common/sensirion_common.h "$${pkgdir}" && \
	cp embedded-common/sensirion_i2c.h "$${pkgdir}" && \
	cp -r $${driver}/* "$${pkgdir}" && \
	cp CHANGELOG.md LICENSE "$${pkgdir}" && \
	rm "$${pkgdir}/svm40_example_usage_arduino.ino" && \
	echo 'sensirion_common_dir = .' >> $${pkgdir}/user_config.inc && \
	echo "$${driver}_dir = ." >> $${pkgdir}/user_config.inc && \
	cd "$${pkgdir}" && $(MAKE) $(MFLAGS) && $(MAKE) clean $(MFLAGS) && cd - && \
	cd release && zip -r "$${pkgname}.zip" "$${pkgname}" && cd - && \
	ln -sfn $${pkgname} $@

release/svm40_arduino: prepare
	$(RM) $@
	export rel=$@ && \
	export driver=$${rel#release/} && \
	export tag="$$(git describe --always --dirty)" && \
	export pkgname="$${driver}-$${tag}" && \
	export pkgdir="release/$${pkgname}/svm40_example_usage_arduino" && \
	rm -rf "$${pkgdir}" && mkdir -p "$${pkgdir}" && \
	cp embedded-common/hw_i2c/sample-implementations/arduino/sensirion_hw_i2c_implementation.cpp "$${pkgdir}" && \
	cp embedded-common/sensirion_arch_config.h "$${pkgdir}" && \
	cp embedded-common/sensirion_common.c "$${pkgdir}" && \
	cp embedded-common/sensirion_common.h "$${pkgdir}" && \
	cp embedded-common/sensirion_i2c.h "$${pkgdir}" && \
	cp svm40/*.[hc] "$${pkgdir}" && \
	cp "svm40/svm40_example_usage_arduino.ino" "$${pkgdir}" && \
	cp README-ARDUINO.rst "release/$${pkgname}" && \
	rm "$${pkgdir}/svm40_example_usage.c" && \
	cd release && zip -r "$${pkgname}.zip" "$${pkgname}" && cd - && \
	ln -sfn $${pkgname} $@

release: clean $(release_drivers)

$(clean_drivers):
	export rel=$@ && \
	export driver=$${rel#clean_} && \
	cd $${driver} && $(MAKE) clean $(MFLAGS) && cd -

clean: $(clean_drivers)
	rm -rf release
	$(RM) svm40/svm40_git_version.c

style-fix:
	@if [ $$(git status --porcelain -uno 2> /dev/null | wc -l) -gt "0" ]; \
	then \
		echo "Refusing to run on dirty git state. Commit your changes first."; \
		exit 1; \
	fi; \
	git ls-files | grep -e '\.\(c\|h\|cpp\)$$' | xargs clang-format -i -style=file;

style-check: style-fix
	@if [ $$(git status --porcelain -uno 2> /dev/null | wc -l) -gt "0" ]; \
	then \
		echo "Style check failed:"; \
		git diff; \
		git checkout -f; \
		exit 1; \
	fi;
