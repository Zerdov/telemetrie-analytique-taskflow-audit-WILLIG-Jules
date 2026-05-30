#!/usr/bin/env bash
# generate-traffic.sh — Génère du trafic varié sur l'API TaskFlow
# Usage : ./scripts/generate-traffic.sh
# Ctrl+C pour arrêter

API_BASE="http://localhost:3000"
ok=0; err=0; slow=0; missing=0
start=$(date +%s)

TITRES=(
  "Préparer la démo" "Relire le slide 35" "Vérifier les TP"
  "Acheter du café" "Tester Grafana" "Refresh Metabase"
  "Lire pino docs" "Debug le span manuel"
)

echo "Trafic en cours sur $API_BASE ... Ctrl+C pour arrêter"
echo ""

while true; do
  # GET list tasks (très fréquent)
  if curl -sf "$API_BASE/api/tasks" -o /dev/null; then
    ((ok++))
  else
    ((err++))
  fi

  # GET health
  if curl -sf "$API_BASE/health" -o /dev/null; then
    ((ok++))
  else
    ((err++))
  fi

  # POST create task (1 fois sur 3)
  if (( RANDOM % 3 == 0 )); then
    titre="${TITRES[$((RANDOM % ${#TITRES[@]}))]}"
    body="{\"title\":\"$titre $((RANDOM % 9999))\"}"
    if curl -sf -X POST "$API_BASE/api/tasks" \
        -H "Content-Type: application/json" -d "$body" -o /dev/null; then
      ((ok++))
    else
      ((err++))
    fi
  fi

  # GET /api/slow (1 fois sur 4) - en arrière-plan
  if (( RANDOM % 4 == 0 )); then
    curl -sf "$API_BASE/api/slow" -o /dev/null --max-time 5 &
    ((slow++))
  fi

  # GET route inexistante (1 fois sur 5) -> 404
  if (( RANDOM % 5 == 0 )); then
    curl -sf "$API_BASE/api/route-qui-nexiste-pas" -o /dev/null || ((missing++))
  fi

  # POST invalide (1 fois sur 10) -> 400
  if (( RANDOM % 10 == 0 )); then
    curl -sf -X POST "$API_BASE/api/tasks" \
      -H "Content-Type: application/json" -d '{"title":""}' -o /dev/null || true
  fi

  # Affichage compteur (toutes les 10 itérations)
  total=$(( ok + err + slow + missing ))
  if (( (ok + err) % 10 == 0 && total > 0 )); then
    now=$(date +%s)
    elapsed=$(( now - start ))
    mins=$(( elapsed / 60 ))
    secs=$(( elapsed % 60 ))
    rps=$(awk "BEGIN { printf \"%.1f\", $total / ($elapsed > 0 ? $elapsed : 1) }")
    printf "\r✓ %d   slow %d   404 %d   err %d   |  %s req/s   elapsed %02d:%02d     " \
      "$ok" "$slow" "$missing" "$err" "$rps" "$mins" "$secs"
  fi

  sleep 0.3
done