Config = {}

Config.Interact = "ox_target" -- "ox_target" of "sleepless" als je die gebruikt

-- Elke entry hier is één evidence-locatie
-- Tip: maak per job een aparte entry, ook als coords hetzelfde zijn
Config.EvidenceLockers = {
  ["MRPD_Police"] = {
    coords      = vector3(443.53, -974.54, 30.68),
    jobs        = { "police" },   -- alleen politie, kan gedeeld worden met meerdere jobs als rangen overeenkomen
    withdrawRank= 2,              -- min. grade om UIT locker te halen
    clearRank   = 3,              -- min. grade om locker te legen
    deleteRank  = 4,              -- min. grade om locker te verwijderen
    stashWeight = 500000,
    stashSlots  = 50,
  },

  ["Sandy_Police"] = {
    coords      = vector3(443.53, -974.54, 30.68),
    jobs        = { "ambulance" },
    withdrawRank= 2,
    clearRank   = 3,
    deleteRank  = 4,
    stashWeight = 400000,
    stashSlots  = 30,
  },

  -- Template
  ["FIB_Evidence"] = {
    coords      = vector3(250.0, -750.0, 34.0),
    jobs        = { "fib" },
    withdrawRank= 2,
    clearRank   = 3,
    deleteRank  = 4,
    stashWeight = 500000,
    stashSlots  = 40,
  }
}
