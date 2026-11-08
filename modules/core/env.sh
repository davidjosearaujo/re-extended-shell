# Core module: environment (sourced by bash and zsh).
# Loaded first, then local/env.sh, then every other module.

# Settings read by the commands of every module (defaults shown, override in
# local/env.sh):
#   RE_ZAP_PORT=9090                                  ZAP proxy port on this machine
#   RE_ZAP_CERT="$RE_EXT_HOME/certs/zap_root_ca.cer"  ZAP root CA, PEM or DER
