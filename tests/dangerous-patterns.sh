#!/usr/bin/env bash
# Dangerous pattern check tests, in throwaway git repositories.
set -u
# shellcheck source=tests/helpers.sh
source "$(dirname "${BASH_SOURCE[0]}")/helpers.sh"
# shellcheck source=tests/repository.sh
source "$(dirname "${BASH_SOURCE[0]}")/repository.sh"
SCRIPT="$ROOT/motifs-dangereux/check.sh"

run_check() { output=$(cd "$REPO" && BASE="$BASE" "$@" bash "$SCRIPT" 2>&1); code=$?; }
write_code() { mkdir -p "$REPO/$(dirname "$1")"; printf '%s\n' "${@:2}" > "$REPO/$1"; }
# Adds one line to a new file and runs the check.
check_line() { new_repository; commit_base; write_code "$1" "$2"; commit_change; run_check env; }

echo "Motifs dangereux"

check_line src/client.ts "const agent = new https.Agent({ rejectUnauthorized: false });"
expect "TLS désactivé (Node) : bloqué" 1 "::error file=src/client.ts,line=1,title=Motif dangereux : Vérification TLS désactivée" "$code" "$output"
check_line app/fetch.py "requests.get(url, verify=False)"
expect "TLS désactivé (Python) : bloqué" 1 "Vérification TLS désactivée" "$code" "$output"

check_line src/server.ts "res.setHeader('Access-Control-Allow-Origin', '*');"
expect "CORS ouvert à tous : avertissement, sans bloquer" 0 "::warning file=src/server.ts,line=1,title=Motif dangereux : CORS ouvert à tous" "$code" "$output"
check_line src/main.ts "app.enableCors({ origin: '*' });"
expect "CORS ouvert (NestJS) : avertissement" 0 "CORS ouvert à tous" "$code" "$output"

check_line src/view.js "element.innerHTML = message;"
expect "innerHTML = : avertissement" 0 "HTML injecté" "$code" "$output"
check_line src/view.js "element.innerHTML += item;"
expect "innerHTML += : avertissement" 0 "HTML injecté" "$code" "$output"
check_line src/Card.vue '<div v-html="description"></div>'
expect "v-html : avertissement" 0 "HTML injecté" "$code" "$output"
check_line src/Card.tsx "<div dangerouslySetInnerHTML={{ __html: text }} />"
expect "dangerouslySetInnerHTML : avertissement" 0 "HTML injecté" "$code" "$output"

check_line src/repo.ts 'db.query("SELECT * FROM users WHERE id = " + id);'
expect "SQL par concaténation : avertissement" 0 "SQL assemblé avec du texte" "$code" "$output"
# shellcheck disable=SC2016 # intended: a JavaScript template literal, kept as is
check_line src/repo.ts 'db.query(`DELETE FROM orders WHERE id = ${orderId}`);'
expect "SQL par interpolation : avertissement" 0 "SQL assemblé avec du texte" "$code" "$output"
check_line app/repo.py 'cursor.execute(f"SELECT name FROM users WHERE id = {user_id}")'
expect "SQL en f-string Python : avertissement" 0 "SQL assemblé avec du texte" "$code" "$output"

check_line src/load.js "try { load(); } catch (error) {}"
expect "catch vide : avertissement" 0 "Erreur avalée" "$code" "$output"
check_line app/load.py "except ValueError: pass"
expect "except: pass : avertissement" 0 "Erreur avalée" "$code" "$output"

# Accepted: look alike, but safe.
for safe in \
  "if (element.innerHTML == previous) return;" \
  "element.textContent = message;" \
  "db.query('SELECT * FROM users WHERE id = \$1', [id]);" \
  "const label = 'Select a file from the list' + suffix;" \
  "catch (error) { logger.error(error); }" \
  "const agent = new https.Agent({ rejectUnauthorized: true });" \
  "res.setHeader('Access-Control-Allow-Origin', 'https://exemple.fr');"; do
  check_line src/safe.ts "$safe"
  expect "accepté : $safe" 0 "" "$code" "$output"
  if printf '%s' "$output" | grep -q "Motif dangereux"; then fail "  …aucun signalement attendu" "$output"; fi
done

check_line src/view.js "element.innerHTML = sanitize(html); // constance: autorisé, contenu nettoyé par DOMPurify"
expect "exception écrite sur la ligne : rien signalé" 0 "" "$code" "$output"
if printf '%s' "$output" | grep -q "Motif dangereux"; then fail "  …l'exception est respectée" "$output"; else pass "  …l'exception est respectée"; fi

new_repository; write_code src/legacy.js "function show(text) {" "  element.innerHTML = text;" "}"; commit_base
write_code src/legacy.js "export function show(text) {" "    element.innerHTML = text;" "}"; commit_change; run_check env
expect "motif déjà présent avant (code réindenté) : toléré" 0 "" "$code" "$output"
if printf '%s' "$output" | grep -q "Motif dangereux"; then fail "  …rien signalé" "$output"; else pass "  …rien signalé"; fi

# The tolerance counts copies: a dangerous line already in the file does not let the PR add one more.
new_repository; write_code src/client.ts "const legacy = new https.Agent({ rejectUnauthorized: false }); // constance: autorisé" "const agent = new https.Agent({ rejectUnauthorized: false });"; commit_base
write_code src/client.ts "const legacy = new https.Agent({ rejectUnauthorized: false }); // constance: autorisé" "const agent = new https.Agent({ rejectUnauthorized: false });" "const other = 1;" "const agent = new https.Agent({ rejectUnauthorized: false });"; commit_change; run_check env
expect "une copie de plus d'une ligne dangereuse déjà présente : bloquée" 1 "::error file=src/client.ts,line=4,title=Motif dangereux : Vérification TLS désactivée" "$code" "$output"

new_repository; write_code src/load.js "function a() {" "  try { load(); } catch (error) {}" "}" "function b() {}"; commit_base
write_code src/load.js "function b() {}" "function a() {" "  try { load(); } catch (error) {}" "}"; commit_change; run_check env
expect "ligne dangereuse déplacée dans le fichier, sans copie de plus : tolérée" 0 "" "$code" "$output"
if printf '%s' "$output" | grep -q "Motif dangereux"; then fail "  …rien signalé" "$output"; else pass "  …rien signalé"; fi

new_repository; write_code src/load.js "try { load(); } catch (error) {}"; commit_base
write_code src/load.js "try { load(); } catch (error) {}" "try { save(); } catch (error) {}" "try { load(); } catch (error) {}"; commit_change; run_check env
expect "catch vide identique ajouté une seconde fois : signalé" 0 "::warning file=src/load.js,line=3,title=Motif dangereux : Erreur avalée" "$code" "$output"

new_repository; commit_base; write_code src/client.test.ts "new https.Agent({ rejectUnauthorized: false });"; commit_change; run_check env
expect "fichier de test : ignoré" 0 "" "$code" "$output"

new_repository; commit_base; write_code src/client.ts "new https.Agent({ rejectUnauthorized: false });"; commit_change
summary_file=$(mktemp); run_check env GITHUB_STEP_SUMMARY="$summary_file"
expect "résumé de la PR écrit" 1 "" "$code" "$output"
if grep -q '🔴 Vérification TLS désactivée' "$summary_file"; then pass "  …avec le motif bloquant"; else fail "  …avec le motif bloquant" "$(cat "$summary_file")"; fi

report
