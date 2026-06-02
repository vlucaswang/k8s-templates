#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "${SCRIPT_DIR}/lib.sh"

need helm
need ruby

require_rendered_kind() {
  local rendered="$1"
  local chart="$2"
  local kind="$3"

  if ! grep -Eq "^kind: ${kind}$" "${rendered}"; then
    echo "platform chart ${chart} must render ${kind}" >&2
    exit 1
  fi
}

require_rendered_pattern() {
  local rendered="$1"
  local chart="$2"
  local pattern="$3"
  local description="$4"

  if ! grep -Eq "${pattern}" "${rendered}"; then
    echo "platform chart ${chart} must render ${description}" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

catalog_file="${ROOT_DIR}/platform/catalog.yaml"
if [[ ! -f "${catalog_file}" ]]; then
  echo "missing platform catalog manifest: ${catalog_file}" >&2
  exit 1
fi

ruby - "${catalog_file}" "${ROOT_DIR}/argocd/platform-catalog-applicationset.yaml" "${ROOT_DIR}" <<'RUBY'
require "yaml"

catalog_file, appset_file, root_dir = ARGV
catalog = YAML.load_file(catalog_file)
appset = YAML.load_file(appset_file)

charts = catalog.dig("spec", "charts")
unless charts.is_a?(Array) && !charts.empty?
  abort "platform catalog must define spec.charts"
end

names = {}
charts.each do |chart|
  name = chart["name"]
  path = chart["path"]
  local_values_file = chart["localValuesFile"]
  config_values_file = chart["configValuesFile"]
  contracts = chart["contracts"] || {}

  abort "catalog chart is missing name" unless name.is_a?(String) && !name.empty?
  abort "duplicate catalog chart #{name}" if names[name]
  names[name] = true

  abort "catalog chart #{name} is missing path" unless path.is_a?(String) && !path.empty?
  abort "catalog chart #{name} path does not exist: #{path}" unless File.file?(File.join(root_dir, path, "Chart.yaml"))
  abort "catalog chart #{name} is missing localValuesFile" unless local_values_file.is_a?(String) && !local_values_file.empty?
  abort "catalog chart #{name} is missing configValuesFile" unless config_values_file.is_a?(String) && !config_values_file.empty?

  %w[ciliumNetworkPolicy serviceMonitor certManagerCertificate certManagerIssuerAnnotations].each do |contract|
    abort "catalog chart #{name} must set contracts.#{contract}=true" unless contracts[contract] == true
  end
end

elements = appset.dig("spec", "generators", 0, "list", "elements")
unless elements.is_a?(Array)
  abort "platform catalog ApplicationSet must define spec.generators[0].list.elements"
end

expected = charts.map { |chart|
  {
    "name" => chart["name"],
    "namespace" => chart["namespace"],
    "path" => chart["path"],
    "valuesFile" => chart["localValuesFile"],
  }
}

unless elements == expected
  abort "platform catalog ApplicationSet elements do not match platform/catalog.yaml"
end
RUBY

shopt -s nullglob
ruby -ryaml -e 'YAML.load_file(ARGV[0]).dig("spec", "charts").each { |chart| puts "#{chart["name"]}\t#{chart["path"]}" }' "${catalog_file}" |
while IFS=$'\t' read -r chart_name chart_path; do
  chart_dir="${ROOT_DIR}/${chart_path}"
  rendered_default="${tmp_dir}/${chart_name}-default.yaml"
  rendered_tls="${tmp_dir}/${chart_name}-tls.yaml"

  helm template "${chart_name}" "${chart_dir}" \
    --namespace "${chart_name}" > "${rendered_default}"

  require_rendered_kind "${rendered_default}" "${chart_name}" "CiliumNetworkPolicy"
  require_rendered_kind "${rendered_default}" "${chart_name}" "ServiceMonitor"
  require_rendered_pattern \
    "${rendered_default}" \
    "${chart_name}" \
    "app.kubernetes.io/part-of: temporal-platform" \
    "the shared platform label"

  helm template "${chart_name}" "${chart_dir}" \
    --namespace "${chart_name}" \
    --set tls.certManager.enabled=true \
    --set "tls.certManager.dnsNames[0]=${chart_name}.example.test" > "${rendered_tls}"

  require_rendered_kind "${rendered_tls}" "${chart_name}" "Certificate"
  require_rendered_pattern \
    "${rendered_tls}" \
    "${chart_name}" \
    "cert-manager.io/issuer-kind:" \
    "cert-manager issuer kind annotation"
  require_rendered_pattern \
    "${rendered_tls}" \
    "${chart_name}" \
    "cert-manager.io/issuer-name:" \
    "cert-manager issuer name annotation"
done

echo "platform catalog contracts validated"
