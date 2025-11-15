# manifest variables

HOST ?= $(shell hostname -f)
USER ?= $(shell whoami)
TIMESTAMP ?= $(shell date -u +"%y%m%dT%H%M%SZ")
CI_JOB_ID ?= undefined
TOOLCHAIN := $(shell which vivado)
GIT_COMMIT_SHORT := $(shell git rev-parse --short=8 HEAD)
GIT_COMMIT := $(shell git rev-parse HEAD)
GIT_BRANCH := $(shell git rev-parse --abbrev-ref HEAD | sed 's#[/ ]#-#g')
GIT_TAG := $(shell git describe --exact-match --tags HEAD 2>/dev/null || echo no-tag-matching-$(GIT_COMMIT_SHORT))
GIT_STATUS := $(shell git status --porcelain)
GIT_REMOTE := $(shell git remote get-url origin)
LOCAL_REPO_STATE := $(if $(strip $(GIT_STATUS)),dirty,clean)
VARIANT_STR ?= passing-string-values-via-verilog-generics-is-ok-or-is-it-question-mark
VARIANT_HEX32 ?= 0xAA55CC33

# build variables

#PART ?= xcku5p-ffvb676-3-e
PART ?= xc7z020-clg484-2-e
TASK ?= all
VERBOSE ?= 0
Q := $(if $(filter 1,$(VERBOSE)),,@)
DRY_RUN ?= 0
ECHO_CMD := $(if $(filter 1,$(DRY_RUN)),echo "Dry-run:",)
VVD ?= vivado
VVD_MODE ?= batch
VVD_FLAGS := -mode $(VVD_MODE) -nojournal -notrace -script ../src/vivado.tcl
VVD_ARGS := -tclargs \
	TASK=$(TASK) \
	PART=$(PART) \
	GIT_COMMIT=$(GIT_COMMIT_SHORT) \
	VARIANT_HEX32=$(VARIANT_HEX32)
BUILD_DIR_PREFIX := build__

# Targets

.PHONY: all FORCE

all: $(BUILD_DIR_PREFIX)__$(GIT_COMMIT_SHORT)

$(BUILD_DIR_PREFIX)%: FORCE
	$(Q)mkdir -p $@
    # there must be a better way for generating the JSON manifest...
	$(Q)jq -n -c \
        --arg timestamp "$(TIMESTAMP)" \
        --arg user "$(USER)" \
        --arg host "$(HOST)" \
        --arg job_id "$(CI_JOB_ID)" \
        --arg toolchain "$(TOOLCHAIN)" \
        --arg local_repo_state "$(LOCAL_REPO_STATE)" \
        --arg branch "$(GIT_BRANCH)" \
        --arg tag "$(GIT_TAG)" \
        --arg release "undefined" \
        --arg commit "$(GIT_COMMIT)" \
        --arg remote "$(GIT_REMOTE)" \
        --arg host "$(HOST)" \
        --arg variant_hex32 "$(VARIANT_HEX32)" \
        --arg variant_str "$(VARIANT_STR)" \
        -f src/firmware_manifest.jq > $@/firmware_manifest.json
    # xxd shifts unaligned words towards LSB
    # we must fill last data word with spaces ` ` for preserving alignment
	$(Q)PADDING=$$(((4 - $$(stat -c%s $@/firmware_manifest.json) % 4) % 4 )); \
	    if [ $$PADDING -ne 0 ]; then printf '%*s' "$$PADDING" >> $@/firmware_manifest.json; fi
    $(Q)xxd -g 4 $@/firmware_manifest.json > $@/firmware_manifest.json.xxd
    $(Q)xxd -ps -c 4 $@/firmware_manifest.json > $@/firmware_manifest.hex
	$(Q)cd $@ && $(ECHO_CMD) $(VVD) $(VVD_FLAGS) $(VVD_ARGS)

.PHONY: clean

clean:
	$(Q)$(RM) -rf $(BUILD_DIR_PREFIX)*
