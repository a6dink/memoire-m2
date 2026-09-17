#!/usr/bin/env bash
# ============================================================================
#  generer-figures.sh
#
#  Convertit les diagrammes PlantUML du dépôt CI en PDF vectoriels utilisables
#  dans le mémoire, et copie les captures d'écran existantes.
#
#  PlantUML n'étant pas installé localement, la conversion s'exécute dans un
#  conteneur.
# ============================================================================
set -euo pipefail

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIGURES="${ICI}/figures"
WS="$(cd "${ICI}/.." && pwd)"

PLANTUML_IMAGE="${PLANTUML_IMAGE:-plantuml/plantuml:latest}"

mkdir -p "${FIGURES}"

# --- Sources PlantUML -------------------------------------------------------
SOURCES=(
  "${WS}/ci/docs/images/workflow-diagram.puml"
  "${WS}/ci/docs/images/pm77xx-app-workflow.puml"
)

echo "== Conversion des diagrammes PlantUML =="
for src in "${SOURCES[@]}"; do
  if [[ ! -f "${src}" ]]; then
    echo "  ABSENT : ${src}" >&2
    continue
  fi
  nom="$(basename "${src}" .puml)"
  cp "${src}" "${FIGURES}/${nom}.puml"
  echo "  source copiée : ${nom}.puml"
done

if command -v plantuml >/dev/null 2>&1; then
  plantuml -tpdf "${FIGURES}"/*.puml
elif command -v docker >/dev/null 2>&1; then
  docker run --rm -u "$(id -u):$(id -g)" \
    -v "${FIGURES}":/work -w /work \
    "${PLANTUML_IMAGE}" -tpdf ./*.puml \
    || echo "  ÉCHEC de la conversion : utiliser les PNG existants en repli." >&2
else
  echo "  Ni plantuml ni docker disponibles : conversion ignorée." >&2
fi

# --- Captures d'écran existantes -------------------------------------------
echo "== Copie des captures d'écran =="
for png in \
  "${WS}/ci/docs/images/CovReport.png" \
  "${WS}/ci/docs/images/buildArtifacts.png" \
  "${WS}/ci/docs/images/UTReports.png" \
  "${WS}/ci/docs/images/workflow-diagram.png" \
  "${WS}/ci/docs/images/pm77xx-app-workflow.png"
do
  if [[ -f "${png}" ]]; then
    cp "${png}" "${FIGURES}/"
    echo "  copiée : $(basename "${png}")"
  else
    echo "  ABSENTE : ${png}" >&2
  fi
done

echo
echo "Figures disponibles dans ${FIGURES} :"
ls -1 "${FIGURES}" 2>/dev/null || true
