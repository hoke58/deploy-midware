PACKAGE_NAME = deploy-midware.tgz
EXCLUDE_LIST = --exclude=Dockerfile --exclude=.gitignore --exclude=.git --exclude=images

MAKE_PATH := $(shell pwd)
$(eval PARENT_PATH := $(realpath $(MAKE_PATH)/..))
MAKEFILE_DIR_PATSUBST := $(patsubst %/,%,$(MAKE_PATH))
CURRENT_DIR := $(notdir $(MAKE_PATH))

.PHONY: package

all:
	@echo $(MAKE_PATH)
	@echo $(PARENT_PATH)
	@echo $(MAKEFILE_DIR_PATSUBST)
	@echo $(CURRENT_DIR)

package:
	mkdir -p $(MAKE_PATH)/target
	tar zcvPf $(MAKE_PATH)/target/$(PACKAGE_NAME) $(EXCLUDE_LIST) -C $(PARENT_PATH) $(CURRENT_DIR)