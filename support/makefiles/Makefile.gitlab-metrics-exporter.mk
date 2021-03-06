gitlab_metrics_exporter_version = $(shell support/resolve-dependency-commitish "${gitlab_development_root}/gitlab/GITLAB_METRICS_EXPORTER_VERSION")

.PHONY: gitlab-metrics-exporter-setup
ifeq ($(gitlab_metrics_exporter_enabled),true)
gitlab-metrics-exporter-setup: gitlab-metrics-exporter/bin/gitlab-metrics-exporter
else
gitlab-metrics-exporter-setup:
	@true
endif

.PHONY: gitlab-metrics-exporter-update
ifeq ($(gitlab_metrics_exporter_enabled),true)
gitlab-metrics-exporter-update: gitlab-metrics-exporter-update-timed
else
gitlab-metrics-exporter-update:
	@true
endif

.PHONY: gitlab-metrics-exporter-update-run
gitlab-metrics-exporter-update-run: gitlab-metrics-exporter/.git/pull gitlab-metrics-exporter-clean-bin gitlab-metrics-exporter/bin/gitlab-metrics-exporter

.PHONY: gitlab-metrics-exporter-clean-bin
gitlab-metrics-exporter-clean-bin:
	$(Q)$(MAKE) -C gitlab-metrics-exporter clean

gitlab-metrics-exporter/.git:
	$(Q)support/component-git-clone --quiet --branch "${gitlab_metrics_exporter_version}" ${git_depth_param} ${gitlab_metrics_exporter_repo} gitlab-metrics-exporter

.PHONY: gitlab-metrics-exporter/bin/gitlab-metrics-exporter
gitlab-metrics-exporter/bin/gitlab-metrics-exporter: gitlab-metrics-exporter/.git/pull
	@echo
	@echo "${DIVIDER}"
	@echo "Building gitlab-org/gitlab-metrics-exporter version ${gitlab_metrics_exporter_version}"
	@echo "${DIVIDER}"
	$(Q)$(MAKE) -C gitlab-metrics-exporter ${QQ}

.PHONY: gitlab-metrics-exporter/.git/pull
gitlab-metrics-exporter/.git/pull: gitlab-metrics-exporter/.git
	@echo
	@echo "${DIVIDER}"
	@echo "Updating gitlab-org/gitlab-metrics-exporter"
	@echo "${DIVIDER}"
	$(Q)support/component-git-update gitlab_metrics_exporter gitlab-metrics-exporter "${gitlab_metrics_exporter_version}" main
