# Source this file. Signing secrets remain in the login Keychain.
signing_identity() {
  if [[ -n ${COWRITTEN_SIGNING_IDENTITY:-} ]]; then
    echo "$COWRITTEN_SIGNING_IDENTITY"
    return
  fi
  local found
  found=$(security find-identity -v -p codesigning 2>/dev/null | sed -nE 's/.*"(Developer ID Application: [^"]+)".*/\1/p' | head -1)
  echo "${found:--}"
}
signing_team() { sed -nE 's/.*\(([A-Z0-9]{10})\)$/\1/p' <<<"$1"; }
# The existing owner profile can notarise any app signed by this team.
notary_profile=${COWRITTEN_NOTARY_PROFILE:-renoir-notary}
