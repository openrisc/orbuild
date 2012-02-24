
# -----------------------------------------------------
#
# Configure and build a standard autotools-based project.
#
#  $(1) is: - The name prefix for the related makefile variables. For example, for prefix "NEWLIB"
#              variables named in the form NEWLIB_xxx will be defined.
#           - Part of the name in all files and directories created for this component.
#  $(2) is the user-friendly name.
#  $(3) is the path to the src directory.
#
# Add these targets to your makefile to trigger the actions:
#  
#  $(prefix_INSTALL_SENTINEL)   # Triggers configure, make, make install.
#  $(prefix_CHECK_SENTINEL)     # Optional, triggers "make check".
#  $(prefix_DISTCHECK_SENTINEL) # Triggers configure, make, make install.

define autotool_project_template_variables

  ifeq ($(origin $(1)_EXTRA_CONFIG_ARGS), undefined)
    $(1)_EXTRA_CONFIG_ARGS :=
  endif

  # Extra arguments passed to the 'make', 'make install' and 'make check' and 'make distcheck' phases.
  ifeq ($(origin $(1)_EXTRA_GLOBAL_MAKE_ARGS), undefined)
    $(1)_EXTRA_GLOBAL_MAKE_ARGS :=
  endif

  ifeq ($(origin $(1)_EXTRA_INSTALL_ARGS), undefined)
    $(1)_EXTRA_INSTALL_ARGS :=
  endif

  ifeq ($(origin $(1)_AUTOCONF_PREPEND_PATH), undefined)
    $(1)_AUTOCONF_PATH_TO_USE := $(PATH)
  else
    $(1)_AUTOCONF_PATH_TO_USE := $(value $(1)_AUTOCONF_PREPEND_PATH):$(PATH)
  endif

  ifeq ($(origin $(1)_MAKE_TARGETS), undefined)
    $(1)_MAKE_TARGETS :=
  endif

  ifeq ($(origin $(1)_INSTALL_TARGETS), undefined)
    $(1)_INSTALL_TARGETS := install
  endif

  ifeq ($(origin $(1)_CHECK_TARGETS), undefined)
    $(1)_CHECK_TARGETS := check
  endif

  $(1)_SRC_DIR := $(2)
  $(1)_OBJ_DIR := $(ORBUILD_BUILD_DIR)/$(1)-obj

  # The user can override the bin directory.
  ifeq ($(origin $(1)_BIN_DIR), undefined)
    $(1)_BIN_DIR := $(ORBUILD_BUILD_DIR)/$(1)-bin
  endif

  $(1)_CONFIG_LOG_FILENAME    := $(ORBUILD_PUBLIC_REPORTS_DIR)/$(1).ConfigureLog.txt
  $(1)_MAKE_LOG_FILENAME      := $(ORBUILD_PUBLIC_REPORTS_DIR)/$(1).MakeLog.txt
  $(1)_INSTALL_LOG_FILENAME   := $(ORBUILD_PUBLIC_REPORTS_DIR)/$(1).InstallLog.txt
  $(1)_CHECK_LOG_FILENAME     := $(ORBUILD_PUBLIC_REPORTS_DIR)/$(1).CheckLog.txt
  $(1)_DISTCHECK_LOG_FILENAME := $(ORBUILD_PUBLIC_REPORTS_DIR)/$(1).DistcheckLog.txt

  $(1)_CONFIG_REPORT_FILENAME    := $(ORBUILD_INTERNAL_REPORTS_DIR)/$(1).Configure.report
  $(1)_MAKE_REPORT_FILENAME      := $(ORBUILD_INTERNAL_REPORTS_DIR)/$(1).Make.report
  $(1)_INSTALL_REPORT_FILENAME   := $(ORBUILD_INTERNAL_REPORTS_DIR)/$(1).Install.report
  $(1)_CHECK_REPORT_FILENAME     := $(ORBUILD_INTERNAL_REPORTS_DIR)/$(1).Check.report
  $(1)_DISTCHECK_REPORT_FILENAME := $(ORBUILD_INTERNAL_REPORTS_DIR)/$(1).Distcheck.report

  $(1)_CONFIGURE_SENTINEL   := $(ORBUILD_BUILD_SENTINELS_DIR)/$(1).ConfigureSentinel
  $(1)_MAKE_SENTINEL        := $(ORBUILD_BUILD_SENTINELS_DIR)/$(1).MakeSentinel
  $(1)_INSTALL_SENTINEL     := $(ORBUILD_BUILD_SENTINELS_DIR)/$(1).InstallSentinel
  $(1)_CHECK_SENTINEL       := $(ORBUILD_BUILD_SENTINELS_DIR)/$(1).CheckSentinel
  $(1)_DISTCHECK_SENTINEL   := $(ORBUILD_BUILD_SENTINELS_DIR)/$(1).DistcheckSentinel

endef

define autotool_project_template
  $(eval $(call autotool_project_template_variables,$(1),$(3)))

  $(value $(1)_CONFIGURE_SENTINEL):
	echo "Configuring $(2)..." && \
    PATH="$(value $(1)_AUTOCONF_PATH_TO_USE)" \
      "$(ORBUILD_TOOLS)/RunAndReport.sh" \
                    "$(2) configure" \
                    "$(value $(1)_CONFIG_LOG_FILENAME)" \
                    "$(value $(1)_CONFIG_REPORT_FILENAME)" \
                    report-always \
        "$(ORBUILD_TOOLS)/AutoconfConfigure.sh" \
                "$(value $(1)_SRC_DIR)" \
                "$(value $(1)_OBJ_DIR)" \
                "$(value $(1)_BIN_DIR)" \
                "$(value $(1)_EXTRA_CONFIG_ARGS)" \
                "$(value $(1)_CONFIGURE_SENTINEL)"

  $(value $(1)_MAKE_SENTINEL): $(value $(1)_CONFIGURE_SENTINEL)
	+echo "Making $(2)..." && \
    export MAKEFLAGS="$$(filter --jobserver-fds=%,$$(MAKEFLAGS)) $$(filter -j,$$(MAKEFLAGS))" && \
    PATH="$(value $(1)_AUTOCONF_PATH_TO_USE)" \
	  "$(ORBUILD_TOOLS)/RunAndReport.sh" \
                    "$(2) make" \
                    "$(value $(1)_MAKE_LOG_FILENAME)" \
                    "$(value $(1)_MAKE_REPORT_FILENAME)" \
                    report-always \
        "$(ORBUILD_TOOLS)/AutoconfMake.sh" \
                "$(value $(1)_OBJ_DIR)" \
                "$(value $(1)_EXTRA_GLOBAL_MAKE_ARGS) $(value $(1)_MAKE_TARGETS)" \
                "$(value $(1)_MAKE_SENTINEL)"

  $(value $(1)_INSTALL_SENTINEL): $(value $(1)_MAKE_SENTINEL)
	+echo "Installing $(2)..." && \
    export MAKEFLAGS="$$(filter --jobserver-fds=%,$$(MAKEFLAGS)) $$(filter -j,$$(MAKEFLAGS))" && \
    PATH="$(value $(1)_AUTOCONF_PATH_TO_USE)" \
	  "$(ORBUILD_TOOLS)/RunAndReport.sh" \
                    "$(2) install" \
                    "$(value $(1)_INSTALL_LOG_FILENAME)" \
                    "$(value $(1)_INSTALL_REPORT_FILENAME)" \
                    report-always \
        "$(ORBUILD_TOOLS)/AutoconfInstall.sh" \
                "$(value $(1)_OBJ_DIR)" \
                "$(value $(1)_EXTRA_GLOBAL_MAKE_ARGS) $(value $(1)_EXTRA_INSTALL_ARGS) $(value $(1)_INSTALL_TARGETS)" \
                "$(value $(1)_INSTALL_SENTINEL)"


  $(value $(1)_CHECK_SENTINEL): $(value $(1)_MAKE_SENTINEL)
	+echo "Make check $(2)..." && \
    export MAKEFLAGS="$$(filter --jobserver-fds=%,$$(MAKEFLAGS)) $$(filter -j,$$(MAKEFLAGS))" && \
    PATH="$(value $(1)_AUTOCONF_PATH_TO_USE)" \
      "$(ORBUILD_TOOLS)/RunAndReport.sh" \
                    "$(2) check" \
                    "$(value $(1)_CHECK_LOG_FILENAME)" \
                    "$(value $(1)_CHECK_REPORT_FILENAME)" \
                    report-always \
        "$(ORBUILD_TOOLS)/AutoconfMake.sh" \
                "$(value $(1)_OBJ_DIR)" \
                "$(value $(1)_EXTRA_GLOBAL_MAKE_ARGS) $(value $(1)_CHECK_TARGETS)" \
                "$(value $(1)_CHECK_SENTINEL)"


  $(value $(1)_DISTCHECK_SENTINEL): $(value $(1)_MAKE_SENTINEL)
	+echo "Distcheck $(2)..." && \
    export MAKEFLAGS="$$(filter --jobserver-fds=%,$$(MAKEFLAGS)) $$(filter -j,$$(MAKEFLAGS))" && \
    PATH="$(value $(1)_AUTOCONF_PATH_TO_USE)" \
      "$(ORBUILD_TOOLS)/RunAndReport.sh" \
                    "$(2) distcheck" \
                    "$(value $(1)_DISTCHECK_LOG_FILENAME)" \
                    "$(value $(1)_DISTCHECK_REPORT_FILENAME)" \
                    report-always \
        "$(ORBUILD_TOOLS)/AutoconfMake.sh" \
                "$(value $(1)_OBJ_DIR)" \
                "$(value $(1)_EXTRA_GLOBAL_MAKE_ARGS) distcheck" \
                "$(value $(1)_DISTCHECK_SENTINEL)"
endef


# -----------------------------------------------------
#
# Triggers the autogen step on a standard autotools-based project.
# Note that the autogen step slightly pollutes the source repository its run upon.
#
#  $(1) is: - The name prefix for the related makefile variables. For example, for prefix "NEWLIB"
#              variables named in the form NEWLIB_xxx will be defined.
#           - Part of the name in all files and directories created for this component.
#  $(2) is the user-friendly name.

define autogen_template_variables

  $(1)_AUTOGEN_LOG_FILENAME     := $(ORBUILD_PUBLIC_REPORTS_DIR)/$(1).AutogenLog.txt
  $(1)_AUTOGEN_REPORT_FILENAME  := $(ORBUILD_INTERNAL_REPORTS_DIR)/$(1).Autogen.report
  $(1)_AUTOGEN_SENTINEL         := $(ORBUILD_BUILD_SENTINELS_DIR)/$(1).AutogenSentinel

endef

define autogen_project_template
  $(eval $(call autogen_template_variables,$(1)))

  ifeq ($$(origin $(1)_AUTOGEN_CMD), undefined)
    $$(error "Variable $(1)_AUTOGEN_CMD not defined.")
  endif

  $(value $(1)_CONFIGURE_SENTINEL): $(value $(1)_AUTOGEN_SENTINEL)

  $(value $(1)_AUTOGEN_SENTINEL):
	echo "Autogen $(2)..." && \
    "$(ORBUILD_TOOLS)/RunAndReport.sh" \
                    "$(2) autogen" \
                    "$(value $(1)_AUTOGEN_LOG_FILENAME)" \
                    "$(value $(1)_AUTOGEN_REPORT_FILENAME)" \
                    report-always \
        "$(ORBUILD_TOOLS)/AutoconfAutogen.sh" \
                "$(value $(1)_SRC_DIR)" \
                "$(value $(1)_AUTOGEN_CMD)" \
                "$(value $(1)_AUTOGEN_SENTINEL)"
endef
