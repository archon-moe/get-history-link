# get-history-link

A small PowerShell script that finds your Genshin Impact wish history link on your PC and copies it to your clipboard, so you can import your wishes on [archon.moe](https://archon.moe).

## How to use

1. Open Genshin Impact, open the Wish menu and select History.
2. Open PowerShell, paste this command and press Enter:

```powershell
iex "&{$((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/archon-moe/get-history-link/main/get-history-link.ps1'))}"
```

3. Paste the copied link into the import page.

If you play on several accounts, the script lists their UIDs and asks which one to copy.

## What it does

- Finds the game folder in the game's own log (`%userprofile%\AppData\LocalLow\miHoYo\Genshin Impact\output_log.txt`).
- Reads the game's web cache, where the wish history page was loaded, and picks out the wish history links.
- Asks HoYoverse's wish history API which links still work and which UID each one belongs to.
- Copies the working link to your clipboard and shows only the UID.

It doesn't send anything anywhere else, doesn't change your game files and doesn't need your password. To read the cache while the game is running, it makes a temporary copy and deletes it right away. The whole script is in [`get-history-link.ps1`](get-history-link.ps1), so you can read it before you run it.

## Keep the link private

For about 24 hours the link lets anyone open your wish history. Don't share it in screenshots, streams or chats.

## Troubleshooting

- **"Cannot find the game"** - open the wish history in game first. If it still fails, run PowerShell as administrator.
- **"All links have expired"** - open the wish history in game again and rerun the command.

Works on Windows with the global game servers (Europe, America, Asia, TW/HK/MO).
