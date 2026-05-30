SHELL := /usr/bin/env bash

.DEFAULT_GOAL := help

include versions.env
export

.PHONY: help bootstrap wait endpoints smoke validate delete status

help:
	@printf "Targets:\n"
	@printf "  make bootstrap  Create kind, install Cilium and Argo CD, apply ApplicationSets\n"
	@printf "  make wait       Wait for core workloads\n"
	@printf "  make endpoints  Print localhost access commands and mappings\n"
	@printf "  make smoke      Run Temporal smoke checks\n"
	@printf "  make validate   Validate local templates and scripts\n"
	@printf "  make delete     Delete the kind cluster\n"

bootstrap:
	./scripts/bootstrap.sh

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
