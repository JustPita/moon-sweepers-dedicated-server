# Running the server on Pelican or Pterodactyl

The `pelican` image target and `pelican/egg-moon-sweepers.json` package the same
Wine/CPU-only server as the Docker Compose setup for a Pelican (or Pterodactyl)
panel. Everything described in [SERVER.md](SERVER.md) still applies: anonymous
Steam GameServer login, Steam P2P/relay joining, password and optional SteamID
allowlist, the supported game builds, and the player client module.

## Image

The egg uses `ghcr.io/hexonmd/moon-sweepers-dedicated-server:pelican`, published by
`.github/workflows/pelican-image.yml`. To build it yourself on the Wings node:

~~~sh
docker build -f Dockerfile.server --target pelican \
    -t ghcr.io/hexonmd/moon-sweepers-dedicated-server:pelican .
~~~

If Wings cannot pull the image, it uses a local image with the same name.

Differences from the Compose image:

- `/data` is a symlink to `/home/container`, the server volume mounted by Wings.
  The container runs with the UID/GID configured in Wings.
- Console commands typed in the panel are read from stdin: `save`, `stop` and
  `status`. The egg stops the server with `stop`, which saves the world, quits the
  game, and writes a backup in `backups/`.
- The panel marks the server as running when the native module reports
  `world-bound`. The anonymous server Steam ID appears in the console just before.
- The Steam GameServer API uses the primary allocation as its game port and the
  next port as its query port, inside the container only. Players never connect
  to these ports: no port forwarding is needed.

## Create a server

1. Import `pelican/egg-moon-sweepers.json` in the admin area (Eggs > Import).
2. Create a server with this egg. Any free allocation works. Plan about 6 GB of
   memory and 6 GB of disk (1.2 GB game copy, Wine prefix, saves and backups).
3. In **Startup**, replace the default `MOON_SERVER_PASSWORD`: the server refuses
   to start with `CHANGE_ME_PLEASE`.
4. Upload your own installation over SFTP into `game/`, so that
   `game/MoonSweepers.exe` exists (copy the contents of
   `steamapps/common/Moon Sweepers`). No game files are included in the image or
   downloaded by the egg.
5. Start the server. The first start downloads Valve's server redistributables
   anonymously and initializes Wine, which takes a few minutes.
6. Read the server Steam ID with `status` in the console (`server_steam_id`) and
   give it to the players with the password. Each player installs the client
   module as described in [README.md](README.md#connect-each-windows-player).

Without a token, the server logs on anonymously and gets a new Steam ID at every
start; the players then update it with
`install-client.ps1 -Action Shortcut -ServerId NEW_ID`.

## Keep the same Steam ID

1. Sign in at <https://steamcommunity.com/dev/managegameservers> with a Steam
   account that meets Valve's requirements, and create a Game Server Login
   Token for **App ID 5335510**.
2. Paste it in **Startup > Steam server token** (`MOON_STEAM_TOKEN`) and restart.
   The console shows `server-logging-on-with-token`, and the server keeps the
   same Steam ID from then on.

Use one token per server and keep it private. If Steam refuses it, the console
reports the EResult code; regenerate the token on the same page.

## Files in the server volume

| Path | Content |
|---|---|
| `game/` | Your uploaded game installation (checked at every start) |
| `wineprefix/` | Wine prefix, including the game saves under `drive_c/users/*/AppData/LocalLow/DragDropGames/MoonSweepers` |
| `backups/` | Archives written after each confirmed clean stop |
| `logs/` | `moon-host.log`, `unity-player.log`, state report and setup logs |
| `steamcmd/`, `steam-redist/` | Anonymous SteamCMD and the verified server redistributables |

To move an existing world to the server, stop it, then replace the save slot in
the Wine prefix with your own save files.

After a game update, the server refuses to start until the module supports the
new build. Players must run the same game build as the server.
