# conkys
**Czech:**

Po stažení archivu, rozbalit a nastavit spouštěcí práva souboru _install.sh_:  
`chmod +x ./install.sh`  
Instalace jen se *sudo* právy:  
`sudo ./install.sh`  
Vytvoří se nám dva soubory:  
`/etc/conkys/conkys.conf.sh`  
`/etc/conkys/conkys_data.conf`

Skript je spouštěn a ukončován pomocí pravidla `udev` a `systemd`. Při připojení disku se vytvoří v paměti RAM/SWAP adresář obsahující tři soubory `temp`, `activity` a `PID`. Při připojení disku dejme tomu `sdb` se vytvoří  
`/dev/shm/conkys/sdb/temp`  
`/dev/shm/conkys/sdb/activity`  
`/dev/shm/conkys/sdb/PID`
* `temp` obsahuje teplotu disku
* `activity` jestli je disk aktivní nebo ve `standby`
* `PID` PID obslužného skriptu

Při odpojení disku se daná větev `/dev/shm/conkys/sdb` automaticky smaže.

V souboru `conkys.conf.sh` se nachází tři 'globální' proměnné:
* `LOOP_DELAY` zde si nastavíte (v sekundách) jak často se má načítat teplota disku. Není nutné aby to bylo nějak často, stačí v pohodě i hodnota jednou za minutu -> *60*
* `SPAT_ZA` zde se nastaví za jak dlouho se při neaktivitě má disk přepnout do `standby` režimu. Toto nastavení lze ke každému disku zvlášť donastavit v souboru `conkys_data.conf`
* `LOG` zde se nastaví soubor kam se mají logovat události disků. Přednastaveno na `/var/log/conkys`. Každý řádek začíná datumem a časem, pak následují události:
  - připojení disku
  - odpojení disku
  - přepnutí stavu `standby`
  - registrace nového disku a jeho parametry
  - chybová hlášení  
Pokud je proměnná zakomentovaná, nic se logovat nebude

Soubor `conkys_data.conf` je privátní databáze registrovaných disků. Kdykoliv se fyzicky připojí disk k PC automaticky se tam zaregistruje s defaultními hodnotami. Ty je možné pomocí textového editoru kdykoliv upravit na míru každého disku. Změny se vždy projeví po opětovném připojení konkrétního disku. Formát této databáze:  
`ignorace | typ | sériové_číslo | HD_timeout | loop_delay | treshold | arguments`  
Jednotlivé sloupce:
* `ignorace` pokud je nastaveno na hodnotu *1* skript si ho nebude všímat. To je kvůli problematickým diskům, či systémovému disku. Ostatní hodnoty včetně prázdného pole znamenají, že se disk nebude ignorovat.
*  `typ` obsahuje TYPE disku dle programu `smartctl`, automaticky se sem uloží. Díky tomu se nemusí skript při každém čtení teploty zdržovat (zatěžovat systém) ptaním na type disku.
*  `sériové_číslo` obsahuje serial number disku jak ho vidí `smartctl`. Důležité needitovat!
*  `HD_timeout` hodnota v sekundách. Po jak dlouhé době neaktivity se má disk přepnout do *standy*
*  `loop_delay` hodnota v sekundách. Jak často se má aktualizovat teplota disku. Čím nižší číslo, tím větší zátěž systému. Přednastavil jsem 10 vteřin, ale úplně stačí třeba jednou za minutu.
* `treshold` magická hodnota. Obsahuje kolik přístupů/čtení z disku musí absolvovat program `smartctl` při načtení teploty. Jsou to kroky které by se měli považovat za neaktivitu disku. Samozřejmě je možno si to také doladit. Čím nižší číslo, tím lépe. Avšak, pokud se to přežene, disk by se teoreticky nikdy nepřepnul do `standby`. Vysoké číslo může mít za následek násilné přepnutí disku do `standby` při nějaké aktivitě a opětovném 'probuzení'. Což by mu zkracovalo životnost.
* `arguments` bude asi ve většině případech prázdné. Zde je možno si zadat argumenty dle zkušeností a manuálové stránky programu `smartctl`. S těmito argumenty bude po každém připojení disku disk nastaven/umravněn (nastavení proběhne jen jednou).

*Tipy a praktické příklady [na wiki:](https://github.com/RadekRojik/conkys/wiki "Conkys wiki")*
