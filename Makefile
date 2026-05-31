SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

include versions.env
export

.PHONY: help bootstrap cloud-provider-kind local-git-repo port-forward stop-port-forward verify-localhost wait endpoints smoke validate delete status

help:
	@printf "Targets:\n"
	@printf "  make bootstrap  Create kind, install Cilium and Argo CD, apply ApplicationSets\n"
	@printf "  make cloud-provider-kind  Start cloud-provider-kind for LoadBalancer services\n"
	@printf "  make local-git-repo  Serve this repository for local Argo CD bootstrap\n"
	@printf "  make port-forward  Expose local fallback ports for developer access\n"
	@printf "  make stop-port-forward  Stop local fallback port-forwards\n"
	@printf "  make verify-localhost  Verify localhost service access\n"
	@printf "  make wait       Wait for core workloads\n"
	@printf "  make endpoints  Print localhost access commands and mappings\n"
	@printf "  make smoke      Run Temporal smoke checks\n"
	@printf "  make validate   Validate local templates and scripts\n"
	@printf "  make delete     Delete the kind cluster\n"

bootstrap:
	./scripts/bootstrap.sh

cloud-provider-kind:
	./scripts/cloud-provider-kind.sh

local-git-repo:
	./scripts/local-git-repo.sh

port-forward:
	./scripts/port-forward.sh

stop-port-forward:
	./scripts/stop-port-forward.sh

verify-localhost:
	./scripts/verify-localhost.sh

wait:
	./scripts/wait.sh

endpoints:
	./scripts/endpoints.sh

smoke:
	./tests/scenarios/temporal-smoke.sh

validate:
	./scripts/validate.sh

delete:
	./scripts/delete.sh

status:
	./scripts/status.sh
