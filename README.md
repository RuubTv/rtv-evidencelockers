--------------------------------------------------------
                  rtv-evidencelockers
--------------------------------------------------------

rtv-evidencelockers is a FiveM evidence locker system for police and investigative jobs using qbx_core, ox_inventory, ox_lib, ox_target/sleepless_interact, and oxmysql.
It allows officers to create, search, view, clear, and delete evidence lockers for arrested individuals, with rank-based permissions for withdrawing items.

🚀 Features
- 📁 Create evidence lockers using a person’s name.
- 🔍 Search and open an existing evidence locker.
- 📜 View all created lockers and choose which one to open.
- 👁️ Interaction support with:
      - ox_target
      - sleepless_interact (optional)

You can also add/edit the interaction in your own target script.
- 🗑️ Clear lockers without deleting the stash entry.
- ❌ Delete lockers completely (DB + stash cleanup).
- 🎯 Job-based access so only configured jobs can use each location.
- 🧱 Rank-based security:

Lower ranks can open, view, and deposit.
Only higher ranks (configurable) can withdraw items.
Separate ranks for withdraw / clear / delete.
- 🔥 Optimized zone handling for better performance.
- 🌍 Multi-language support (add your own locales easily).

📦 Dependencies
Required:
- qbx_core
- ox_inventory
- ox_lib
- oxmysql
Optional:
- ox_target
- sleepless_interact
https://github.com/Sleepless-Development/sleepless_interact

📂 Installation
Download or clone this repository into your resources folder.
Ensure all dependencies above are installed and started.
Run the included SQL file:
- sql.sql
Add the resource to your server.cfg:

'ensure rtv-evidencelockers'
