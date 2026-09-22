echo "Record where the omacos checkout is, so dev status can name it"

# `omacos dev status` learned to answer "where do I edit?" in either mode, from
# a path that `dev link` now records. Machines linked before that change have a
# path.conf and no record; carry it across so they do not have to re-link.
# No-op on every machine that has never linked, which is almost all of them.
conf="${XDG_CONFIG_HOME:-$HOME/.config}/omacos/path.conf"
state="${XDG_STATE_HOME:-$HOME/.local/state}/omacos"
record="$state/dev-checkout"

[[ -f $conf && ! -e $record ]] || exit 0

checkout=$(sed -n 's/^OMACOS_PATH=//p' "$conf" | head -1)
checkout=${checkout//\'/}
[[ -x $checkout/bin/omacos ]] || exit 0

mkdir -p "$state"
printf '%s\n' "$checkout" > "$record"
echo "  recorded $checkout"
