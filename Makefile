# ============================================================================
#  Makefile — Compilation du mémoire
#
#  Aucune installation de TeX Live n'est requise : la compilation s'exécute
#  dans un conteneur, ce qui garantit un résultat identique sur toute machine.
#
#  Cibles principales :
#    make            compile le PDF
#    make watch      recompile à chaque modification
#    make figures    régénère les figures depuis les sources PlantUML
#    make final      compile la version finale (sans notes de rédaction)
#    make wordcount  compte les mots du corps du mémoire
#    make clean      supprime les fichiers intermédiaires
# ============================================================================

MAIN      := main
TEXIMAGE  := texlive/texlive:latest
DOCKER    := docker
UID       := $(shell id -u)
GID       := $(shell id -g)

# Utilise latexmk local s'il existe, sinon le conteneur.
HAVE_LATEXMK := $(shell command -v latexmk 2>/dev/null)

ifdef HAVE_LATEXMK
  RUN :=
else
  RUN := $(DOCKER) run --rm -u $(UID):$(GID) \
         -v "$(CURDIR)":/doc -w /doc \
         -e HOME=/tmp $(TEXIMAGE)
endif

LATEXMK := $(RUN) latexmk

.PHONY: all pdf watch final figures wordcount todo check clean distclean pull help

all: pdf

## Compile le PDF (version de travail, avec notes de rédaction)
pdf:
	$(LATEXMK) -pdf -interaction=nonstopmode -file-line-error $(MAIN).tex

## Recompile automatiquement à chaque enregistrement
watch:
	$(LATEXMK) -pdf -pvc -interaction=nonstopmode $(MAIN).tex

## Version finale : bascule draftmode à false avant compilation
final:
	@sed -i 's/\\setboolean{draftmode}{true}/\\setboolean{draftmode}{false}/' preamble.tex
	$(LATEXMK) -pdf -interaction=nonstopmode $(MAIN).tex || true
	@sed -i 's/\\setboolean{draftmode}{false}/\\setboolean{draftmode}{true}/' preamble.tex
	@echo "PDF final : $(MAIN).pdf"

## Régénère les figures PlantUML en PDF vectoriel
figures:
	@./scripts/generer-figures.sh

## Compte les mots du corps du mémoire
wordcount:
	@$(RUN) sh -c 'texcount -inc -sum -q $(MAIN).tex' 2>/dev/null || \
	  { echo "Estimation brute (hors commandes LaTeX) :"; \
	    cat chapters/*.tex | sed 's/%.*//' | wc -w; }

## Liste le travail de rédaction restant
todo:
	@grep -rn --include='*.tex' -E '\\(aecrire|chiffre|verifier|todo)\{|TODO' \
	  chapters frontmatter annexes 2>/dev/null | sed 's/:[[:space:]]*/: /' || \
	  echo "Aucune note de rédaction restante."
	@echo "---"
	@printf 'Notes restantes : '
	@grep -rc --include='*.tex' -E '\\(aecrire|chiffre)\{' chapters 2>/dev/null \
	  | awk -F: '{s+=$$2} END {print s+0}'

## Vérifications avant rendu
check:
	@echo "== Références non définies / citations manquantes =="
	@grep -E 'Warning.*(undefined|Citation)' $(MAIN).log || echo "  aucune"
	@echo "== Notes de rédaction restantes =="
	@$(MAKE) --no-print-directory todo | tail -2
	@echo "== Termes potentiellement confidentiels =="
	@grep -rn --include='*.tex' -iE 'se\.com|schneider-electric\.com|coverity-embu' \
	  chapters frontmatter annexes 2>/dev/null || echo "  aucun"

## Télécharge l'image de compilation
pull:
	$(DOCKER) pull $(TEXIMAGE)

clean:
	$(LATEXMK) -c $(MAIN).tex 2>/dev/null || true
	rm -f *.aux *.bbl *.bcf *.blg *.fdb_latexmk *.fls *.glg *.glo *.gls \
	      *.ist *.acn *.acr *.alg *.lof *.lot *.out *.run.xml *.toc *.tdo

distclean: clean
	rm -f $(MAIN).pdf

help:
	@grep -B1 -E '^[a-z-]+:' Makefile | grep -E '^##|^[a-z-]+:' | \
	  sed 's/^## /  /; s/:.*//'
