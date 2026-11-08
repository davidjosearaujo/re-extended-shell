# Environment variables (sourced by bash and zsh).
# Only fills in what isn't set yet; put your own values in local/env.sh.
# Topic-specific variables live in config/<topic>.sh (config/android.sh, ...).

# Settings read by the commands in bin/, whatever the topic (defaults shown,
# override in local/env.sh):
#   RE_ZAP_PORT=9090                                  ZAP proxy port on this machine
#   RE_ZAP_CERT="$RE_EXT_HOME/certs/zap_root_ca.cer"  ZAP root CA, PEM or DER
