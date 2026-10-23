# New machine setup

What Nix and chezmoi *cannot* do for you, because it involves minting secrets.

Everything else replays automatically: `nixos-config` installs the tooling
(`flyctl`, `modal`, `sops age ssh-to-age`, `chezmoi`, `gitleaks`) and enables
gnome-keyring's `gcr-ssh-agent` plus the polkit agent; chezmoi lays down the
shell wrappers, `~/.ssh/config` and `~/.gitconfig`.

## The model

Interactive CLI tokens are **TPM-sealed** with `systemd-creds` rather than left
in plaintext dotfiles. A shell wrapper decrypts on demand and passes the value
via the environment, so the credential never touches disk unencrypted.

`*.cred` files are encrypted against **this machine's TPM**. They are not
portable — copying one to another laptop yields a file that cannot decrypt.
That is the point: stealing the disk does not move the secret. On a new machine
you re-mint and re-seal.

Every wrapper falls through to the bare binary when its `.cred` is missing, so a
fresh machine degrades to "not logged in" rather than breaking.

Check the TPM is usable before starting:

    systemd-creds has-tpm2

## 0. Prerequisites

    sudo nixos-rebuild switch --flake ~/nixos-config#yoga
    chezmoi apply
    exec zsh

## 1. SSH keys

Keys are deliberately **not** managed by chezmoi. Generate or restore, then
ensure a passphrase is set — `~/.ssh/config` has `AddKeysToAgent yes`, so you
are prompted once per session, not per operation.

    ssh-keygen -t ed25519 -C "$(git config user.email)"
    ssh-keygen -p -f ~/.ssh/id_ed25519        # if restoring an unprotected key

    ssh-add -l                                # must list the key, not error
    ssh -T git@github.com                     # should greet you by username

If `ssh-add -l` errors, `SSH_AUTH_SOCK` is pointing at a dead socket. wezterm
exports one per GUI process that it only creates when using its SSH domain; the
zshrc block redirects to `$XDG_RUNTIME_DIR/gcr/ssh` when the inherited one is
absent. A shell started before `chezmoi apply` will not have it — `exec zsh`.

`gcloud compute ssh` generates `~/.ssh/google_compute_engine` with **no
passphrase**. Add one; gcloud only regenerates the key when it is missing, not
when it is encrypted.

## 2. Fly.io

Mint a scoped, expiring org token rather than keeping the account-wide login
token that `fly auth login` writes to `~/.fly/config.yml`.

    fly auth login
    fly tokens create org -o andon-labs -x 2160h \
      | systemd-creds encrypt --with-key=tpm2 --name=fly-token - ~/.config/fly/token.cred
    chmod 600 ~/.config/fly/token.cred

    fly auth logout            # revokes the login token server-side, clears config.yml
    fly wireguard token-mode enable   # no WireGuard private keys in config.yml
    fly auth whoami            # verify (polkit prompts once per TTL window)

`-x 2160h` is 90 days. **It will not auto-renew and fails silently** — put the
expiry in your calendar. Re-mint with the same command.

`fly auth logout` revokes the token it reads *from the config file*, never the
one in `FLY_ACCESS_TOKEN`, so run it after sealing, not before.

## 3. Modal

    modal token new
    install -d -m 700 ~/.config/modal
    { awk -F'"' '/^[[:space:]]*token_id/{print $2}'     ~/.modal.toml
      awk -F'"' '/^[[:space:]]*token_secret/{print $2}' ~/.modal.toml; } \
    | systemd-creds encrypt --with-key=tpm2 --name=modal-token - ~/.config/modal/token.cred
    chmod 600 ~/.config/modal/token.cred

    exec zsh
    modal secret list          # verify BEFORE deleting the plaintext
    shred -u ~/.modal.toml

`MODAL_TOKEN_ID` / `MODAL_TOKEN_SECRET` take precedence over `~/.modal.toml`.
For `import modal` in Python, run `modal-env` first — it exports both into the
current shell for `$MODAL_TOKEN_TTL` seconds. The wrapper only covers the CLI.

If modal complains about profile selection afterwards, recreate `~/.modal.toml`
with the stanza and no secrets:

    [andon-labs]
    active = true

Retire the old machine's token in the Modal dashboard (Settings → API Tokens).
`modal token new` issues a token; it does **not** revoke the previous one.

## 4. sops age identity

The age key is only needed to **edit** secrets. Activation uses the host's SSH
key (`sops.age.sshKeyPaths` in `configuration.nix`), so `nixos-rebuild` never
needs this and sealing it behind a password prompt is safe.

Restoring an existing identity:

    systemd-creds encrypt --with-key=tpm2 --name=sops-age keys.txt ~/.config/sops/age/keys.cred
    chmod 600 ~/.config/sops/age/keys.cred
    shred -u keys.txt

Generating a new one — note the ordering, a new key cannot read existing
secrets until an **already-authorised** machine re-encrypts to it:

    age-keygen -o keys.txt            # note the public key it prints
    # add it under `keys:` and `age:` in nixos-config/.sops.yaml, then from a
    # machine that can already decrypt:
    sops updatekeys secrets/secrets.yaml

Verify without printing the key, then remove the plaintext:

    systemd-creds decrypt --name=sops-age ~/.config/sops/age/keys.cred - | grep -c AGE-SECRET-KEY
    # expect: 1

`sops` finds `.sops.yaml` by searching upward from the **current directory**,
not from the file argument — run it from inside the repo:

    cd ~/nixos-config && sops secrets/secrets.yaml

## 5. GitHub CLI

`~/.config/gh/config.yml` is managed (preferences, incl. `git_protocol: ssh`).
`hosts.yml` holds the OAuth token and is deliberately **not** managed:

    gh auth login

The credential helper in `~/.gitconfig` is `!gh auth git-credential` with no
absolute path, so it resolves via `PATH` on any machine. It only applies to
HTTPS remotes; SSH remotes use the key and never consult it.

## 6. Verify no plaintext credentials remain

    ls -l ~/.config/{fly,modal}/*.cred ~/.config/sops/age/keys.cred   # all 0600
    test ! -e ~/.modal.toml && echo "modal: sealed"
    test ! -e ~/.config/sops/age/keys.txt && echo "sops: sealed"

    find ~/.config -maxdepth 4 -type f \
      \( -name "*.txt" -o -name "*.yml" -o -name "*.toml" -o -name "auth*.json" \) \
      | xargs -r grep -lE 'AGE-SECRET-KEY|BEGIN .*PRIVATE KEY|fm2_|ghp_|sk-[A-Za-z0-9]{20}'

The last command should print nothing.

## Gotchas

**Wrappers and shell completion.** Cobra- and click-generated completions shell
back out to the binary (`flyctl __complete ...`) on every tab-press. Without a
bypass that fires a TPM decrypt — and a polkit prompt — each time. `fly()` has a
`case` guard for this. Add the same to any future wrapper around a CLI that
ships completions (`gh`, `docker`, `kubectl` all do).

**Polkit retains per-process, not per-session.** `auth_admin_keep` keys off the
*process*, so each `systemd-creds` invocation re-prompts. The wrappers cache the
decrypted value in a non-exported shell variable for `$FLY_TOKEN_TTL` /
`$MODAL_TOKEN_TTL` seconds (default 900). `SOPS_AGE_KEY_CMD` has no cache —
sops invocations prompt each time, which is acceptable for occasional editing.

**Non-exported cache variables die with the shell.** `exec zsh` discards them;
the next invocation re-prompts once. This is intended — child processes cannot
read the token from `/proc/<pid>/environ`.
