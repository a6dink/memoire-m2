#!/usr/bin/env bash
# ============================================================================
#  collecte-mesures.sh
#
#  Collecte les données quantitatives nécessaires au chapitre 6 (Évaluation).
#  Produit des fichiers CSV dans mesures/, à exploiter ensuite pour les
#  tableaux et graphiques.
#
#  Prérequis : GitHub CLI (gh) authentifié sur l'instance d'entreprise.
#      gh auth login --hostname github.schneider-electric.com
#
#  Usage :
#      ./scripts/collecte-mesures.sh [nombre_d_executions]
# ============================================================================
set -euo pipefail

ICI="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SORTIE="${ICI}/mesures"
LIMITE="${1:-200}"

HOTE="${GH_HOST:-github.schneider-electric.com}"
DEPOT_CI="${DEPOT_CI:-bluebird/ci}"

mkdir -p "${SORTIE}"

if ! command -v gh >/dev/null 2>&1; then
  cat >&2 <<'EOF'
ERREUR : GitHub CLI (gh) est introuvable.

Installation :
  https://cli.github.com/

Puis authentification sur l'instance d'entreprise :
  gh auth login --hostname github.schneider-electric.com

À défaut, exporter manuellement l'historique des exécutions depuis
l'interface web et le déposer dans mesures/executions.csv avec les colonnes :
  id,workflow,statut,conclusion,date_debut,date_fin,duree_min
EOF
  exit 1
fi

export GH_HOST="${HOTE}"

echo "== Collecte des exécutions de ${DEPOT_CI} (limite : ${LIMITE}) =="

# --- Historique des exécutions ---------------------------------------------
gh run list \
  --repo "${DEPOT_CI}" \
  --limit "${LIMITE}" \
  --json databaseId,name,workflowName,status,conclusion,createdAt,updatedAt,event,headBranch \
  > "${SORTIE}/executions.json"

python3 - "${SORTIE}/executions.json" "${SORTIE}/executions.csv" <<'PY'
import csv, json, sys
from datetime import datetime

src, dst = sys.argv[1], sys.argv[2]
with open(src, encoding="utf-8") as f:
    runs = json.load(f)

def duree_min(debut, fin):
    fmt = "%Y-%m-%dT%H:%M:%SZ"
    try:
        d = datetime.strptime(debut, fmt)
        f_ = datetime.strptime(fin, fmt)
        return round((f_ - d).total_seconds() / 60, 1)
    except (ValueError, TypeError):
        return ""

with open(dst, "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["id", "workflow", "evenement", "branche", "statut",
                "conclusion", "debut", "fin", "duree_min"])
    for r in runs:
        w.writerow([
            r.get("databaseId", ""),
            r.get("workflowName", ""),
            r.get("event", ""),
            r.get("headBranch", ""),
            r.get("status", ""),
            r.get("conclusion", ""),
            r.get("createdAt", ""),
            r.get("updatedAt", ""),
            duree_min(r.get("createdAt"), r.get("updatedAt")),
        ])

print(f"  {len(runs)} exécutions écrites dans {dst}")
PY

# --- Statistiques agrégées --------------------------------------------------
echo
echo "== Synthèse par workflow =="
python3 - "${SORTIE}/executions.csv" "${SORTIE}/synthese.csv" <<'PY'
import csv, statistics, sys
from collections import defaultdict

src, dst = sys.argv[1], sys.argv[2]
par_wf = defaultdict(lambda: {"durees": [], "succes": 0, "echecs": 0, "total": 0})

with open(src, encoding="utf-8") as f:
    for row in csv.DictReader(f):
        wf = row["workflow"] or "(inconnu)"
        e = par_wf[wf]
        e["total"] += 1
        if row["conclusion"] == "success":
            e["succes"] += 1
        elif row["conclusion"] in ("failure", "timed_out"):
            e["echecs"] += 1
        if row["duree_min"]:
            e["durees"].append(float(row["duree_min"]))

lignes = []
for wf, e in sorted(par_wf.items()):
    d = e["durees"]
    lignes.append({
        "workflow": wf,
        "executions": e["total"],
        "succes": e["succes"],
        "echecs": e["echecs"],
        "taux_succes_pct": round(100 * e["succes"] / e["total"], 1) if e["total"] else 0,
        "duree_min_minutes": round(min(d), 1) if d else "",
        "duree_mediane_minutes": round(statistics.median(d), 1) if d else "",
        "duree_max_minutes": round(max(d), 1) if d else "",
    })

with open(dst, "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=list(lignes[0].keys()) if lignes else ["workflow"])
    w.writeheader()
    w.writerows(lignes)

largeur = max((len(l["workflow"]) for l in lignes), default=10)
for l in lignes:
    print(f"  {l['workflow']:<{largeur}}  n={l['executions']:<4} "
          f"succes={l['taux_succes_pct']}%  "
          f"mediane={l['duree_mediane_minutes']} min")
print(f"\n  Synthèse écrite dans {dst}")
PY

cat <<EOF

== Étapes restantes (non automatisables depuis ici) ==
  1. Couverture de code : récupérer les rapports gcovr des exécutions
     retenues et reporter les taux dans mesures/couverture.csv.
  2. Défauts d'analyse statique : exporter les vues P1 et P2 du serveur
     d'analyse aux dates de relevé -> mesures/defauts.csv.
  3. Vulnérabilités de composants : exporter les indicateurs produits par
     l'extracteur de métriques -> mesures/vulnerabilites.csv.
  4. Mesures antérieures à la mise en place : si indisponibles, le
     documenter comme limite méthodologique (chapitre 6).

Rappel : les fichiers de mesures/ sont exclus du suivi Git (.gitignore),
car ils peuvent contenir des informations internes.
EOF
