# Run Odoo locally

Run your own copy of Odoo Enterprise on your laptop at http://localhost:8069. Use it in a Claude workflow to check a feature, follow a workflow step by step, or take screenshots for the documentation.

This guide uses Odoo **20.0**. For another version, replace `20.0` with that version everywhere.

For minor versions, include the saas prefix, e.g. `saas-20.1`, and use `master` for the latest testing version.

> [!NOTE]
> `setup.sh` doesn't install Odoo itself. Follow the one-time setup below once, then use [Start Odoo](#start-odoo) and [Stop Odoo](#stop-odoo) for daily workflows.

## Before you start

- Run `setup.sh` first. See the [main README](../README.md).
- Your GitHub account needs access to the private [odoo/enterprise](https://github.com/odoo/enterprise) repository. If you get `Repository not found` when you clone it, ask your team lead for access.
- Make sure you have about 5 GB of free disk space.

## Initial setup (run this the first time only)

### 1. Install the database server

In terminal, run:

```bash
sudo apt-get update
sudo apt-get install -y postgresql libpq-dev libldap2-dev libsasl2-dev
```

Give your user account permission to create databases:

```bash
sudo -u postgres createuser --superuser "$USER"
```

> [!TIP]
> If you see `role "<your-name>" already exists`, this step was already done. Continue to the next step.

### 2. Download the Odoo code

Odoo's code is split across two repositories: `odoo` (Community) and `enterprise`. Both must use the **same version**.

```bash
cd ~/Documents/odoo
git clone --branch 20.0 --single-branch --depth 1 git@github.com:odoo/odoo.git
git clone --branch 20.0 --single-branch --depth 1 git@github.com:odoo/enterprise.git
```

This can take several minutes.

### 3. Install the Python packages

Create a separate Python environment for Odoo, then install its packages into it. `uv` is already installed by `setup.sh`.

```bash
cd ~/Documents/odoo
uv venv .venv-odoo
uv pip install --python .venv-odoo -r odoo/requirements.txt
```

### 4. Create your database

This creates a database called `odoo20`, installs the Enterprise interface, and adds demo data (sample customers, products, and so on) to use in screenshots:

```bash
cd ~/Documents/odoo/odoo
../.venv-odoo/bin/python odoo-bin -d odoo20 --addons-path=addons,../enterprise \
  -i web_enterprise --with-demo
```

When the terminal shows `Modules loaded.`, the setup is complete. Odoo is now running. Open http://localhost:8069 and log in with:

- **Email:** `admin`
- **Password:** `admin`

To install apps such as Sales or Inventory, go to the **Apps** menu in Odoo.

## Start Odoo

Do this each time you want to use Odoo. Odoo's code changes every day, so each start first downloads the latest 20.0 code and then updates your database to match it.

1. Open a terminal and download the latest code for both repositories:

   ```bash
   git -C ~/Documents/odoo/odoo pull
   git -C ~/Documents/odoo/enterprise pull
   ```

2. Start Odoo:

   ```bash
   cd ~/Documents/odoo/odoo
   ../.venv-odoo/bin/python odoo-bin -d odoo20 --addons-path=addons,../enterprise -u all
   ```

   `-u all` updates your database to the code you just downloaded. Without it, Odoo can show errors such as `column ... does not exist` after an update.

3. Wait until the terminal shows `Modules loaded.` This takes from a few seconds to a few minutes. The more apps you installed, the longer it takes.
4. Open http://localhost:8069 and log in with `admin` / `admin`.

Keep the terminal open while you work. Odoo stops when you close the terminal.

> [!TIP]
> To do all of this with one word, add a shortcut to your `~/.bashrc`:
>
> ```bash
> cat >> ~/.bashrc <<'EOF'
> alias odoo20='git -C ~/Documents/odoo/odoo pull && git -C ~/Documents/odoo/enterprise pull && cd ~/Documents/odoo/odoo && ../.venv-odoo/bin/python odoo-bin -d odoo20 --addons-path=addons,../enterprise -u all'
> EOF
> source ~/.bashrc
> ```
>
> After that, type `odoo20` to download the latest code and start Odoo.

## Stop Odoo

In the terminal where Odoo is running, press **Ctrl+C**.

The terminal shows the command prompt again when Odoo has stopped. Your database and everything you changed in it are kept. The next time you [start Odoo](#start-odoo), you continue where you left off.

> [!NOTE]
> If you closed that terminal or can't find it, stop Odoo from any terminal with:
>
> ```bash
> pkill -f odoo-bin
> ```

## Load demo data

Demo data adds sample customers, products, orders, and so on. Use it to fill screens before you take screenshots.

> [!TIP]
> If you created your database with the command in [step 4 of the one-time setup](#4-create-your-database), you already have demo data. The `--with-demo` option loads it. You only need the steps below for a database created without that option.

1. [Start Odoo](#start-odoo).
2. Open http://localhost:8069/odoo/settings?debug=1. The `?debug=1` at the end turns on developer mode.
3. Scroll down to the **Developer Tools** section.
4. Click **Load demo data**.

Odoo adds demo data for every app that's installed, and for each app you install afterwards.

> [!NOTE]
> - If you don't see **Load demo data**, your database already has demo data.
> - Don't use **Activate the developer mode (with tests assets)** for this. It only loads files used for automated tests, not demo data.

## Start over with a clean database

To delete your database and create a new one, [stop Odoo](#stop-odoo), then run:

```bash
dropdb odoo20
```

Then repeat [step 4 of the one-time setup](#4-create-your-database).

> [!WARNING]
> `dropdb` permanently deletes everything in that database. You can't undo it.

## Troubleshooting

### `connection to server ... failed`

PostgreSQL isn't running. Start it, then start Odoo again:

```bash
sudo systemctl start postgresql
```

### `git pull` fails

- **`Your local changes ... would be overwritten`:** a file in the Odoo code was changed on your laptop. To discard that change and get the official code back, run `git -C <repo> reset --hard @{u}`. Replace `<repo>` with `~/Documents/odoo/odoo` or `~/Documents/odoo/enterprise`. This permanently discards your changes to that repository.
- **`There is no tracking information`** or **`Not possible to fast-forward`:** the repository isn't on the right branch. See [the page loads, but apps or menus look broken](#the-page-loads-but-apps-or-menus-look-broken).
- **`Could not resolve host`:** you're offline. Skip the `git pull` commands and start Odoo with the code you already have.

### `Address already in use`

Another copy of Odoo is already running. Find its terminal and press **Ctrl+C**, or run `pkill -f odoo-bin`.

To run two versions at the same time on purpose, give the second one a different port by adding `--http-port=8070` to its command. Then open it at http://localhost:8070.

### The page loads, but apps or menus look broken

The `odoo` and `enterprise` repositories are probably on different versions. Check both:

```bash
git -C ~/Documents/odoo/odoo branch --show-current
git -C ~/Documents/odoo/enterprise branch --show-current
```

Both must show the same version, for example `20.0`.

### Why port 8069?

8069 is Odoo's default web port. Odoo uses it unless you add `--http-port` to the command.
